"""Tests for the converter kill switch (guard/app.py), with the AWS clients replaced by fakes."""

import datetime
import json
import os
import sys
from pathlib import Path

import pytest

os.environ.setdefault("AWS_DEFAULT_REGION", "ap-southeast-2")
os.environ["CONVERTER_FUNCTION_NAME"] = "converter"
os.environ["SPIKE_ALARM_NAME"] = "spike"
os.environ["MAX_GB_SECONDS"] = "320000"
os.environ["MAX_REQUESTS"] = "800000"
os.environ["MAX_CONVERTER_INVOCATIONS"] = "20000"
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import app  # noqa: E402


class FakeLambda:
    def __init__(self, reserved=None, functions=()):
        self.reserved = reserved
        self.functions = list(functions)
        self.calls = []

    def get_function_concurrency(self, FunctionName):
        return {} if self.reserved is None else {"ReservedConcurrentExecutions": self.reserved}

    def put_function_concurrency(self, FunctionName, ReservedConcurrentExecutions):
        self.calls.append(("put", FunctionName, ReservedConcurrentExecutions))
        self.reserved = ReservedConcurrentExecutions

    def delete_function_concurrency(self, FunctionName):
        self.calls.append(("delete", FunctionName))
        self.reserved = None

    def get_paginator(self, _name):
        functions = self.functions

        class Paginator:
            def paginate(self):
                return [{"Functions": functions}]

        return Paginator()


class FakeCloudWatch:
    def __init__(self, sums=None, alarm_state="OK", history=()):
        self.sums = sums or {}
        self.alarm_state = alarm_state
        self.history = list(history)

    def get_metric_statistics(self, MetricName, Dimensions, **_kwargs):
        name = Dimensions[0]["Value"]
        value = self.sums.get((name, MetricName), 0)
        return {"Datapoints": [{"Sum": value}] if value else []}

    def describe_alarms(self, AlarmNames):
        return {"MetricAlarms": [{"AlarmName": AlarmNames[0], "StateValue": self.alarm_state}]}

    def describe_alarm_history(self, StartDate, EndDate, **_kwargs):
        return {
            "AlarmHistoryItems": [
                {"HistoryData": json.dumps({"newState": {"stateValue": state}})}
                for at, state in self.history
                if StartDate <= at <= EndDate
            ]
        }


class FakeSNS:
    def __init__(self):
        self.messages = []

    def publish(self, **kwargs):
        self.messages.append(kwargs)


@pytest.fixture
def aws(monkeypatch):
    def install(lambda_client, cloudwatch=None):
        sns = FakeSNS()
        monkeypatch.setattr(app, "_lambda", lambda_client)
        monkeypatch.setattr(app, "_cloudwatch", cloudwatch or FakeCloudWatch())
        monkeypatch.setattr(app, "_sns", sns)
        monkeypatch.setattr(app, "ALERT_TOPIC_ARN", "arn:aws:sns:ap-southeast-2:1:topic")
        return sns

    return install


def _sns_event(message):
    body = message if isinstance(message, str) else json.dumps(message)
    return {"Records": [{"Sns": {"Message": body}}]}


# --- limits ---------------------------------------------------------------------------


def test_no_limit_reached_under_every_limit():
    assert app.limits_reached(app.Usage(gb_seconds=1000, requests=5000, converter_invocations=300)) == []


@pytest.mark.parametrize(
    "usage, expected",
    [
        (app.Usage(320000, 0, 0), "compute"),
        (app.Usage(0, 800000, 0), "requests"),
        (app.Usage(0, 0, 20000), "converter calls"),
    ],
)
def test_each_limit_is_reported_once_reached(usage, expected):
    reached = app.limits_reached(usage)

    assert len(reached) == 1
    assert reached[0].startswith(expected)


# --- alarm messages -------------------------------------------------------------------


def test_spike_alarm_entering_alarm_is_recognised():
    assert app.spike_alarm_fired(_sns_event({"AlarmName": "spike", "NewStateValue": "ALARM"}))


@pytest.mark.parametrize(
    "message",
    [
        {"AlarmName": "spike", "NewStateValue": "OK"},
        {"AlarmName": "some-other-alarm", "NewStateValue": "ALARM"},
        "The JP2/TIFF converter Lambda was switched OFF.",  # the guard's own notice, not JSON
    ],
)
def test_other_topic_messages_are_ignored(message):
    assert not app.spike_alarm_fired(_sns_event(message))


# --- usage ----------------------------------------------------------------------------


def test_month_to_date_usage_weights_duration_by_each_functions_memory(aws):
    functions = [
        {"FunctionName": "converter", "MemorySize": 2048},
        {"FunctionName": "api", "MemorySize": 512},
    ]
    sums = {
        ("converter", "Invocations"): 7,
        ("converter", "Duration"): 10_000,  # 10 s at 2 GB = 20 GB-s
        ("api", "Invocations"): 100,
        ("api", "Duration"): 8_000,  # 8 s at 0.5 GB = 4 GB-s
    }
    aws(FakeLambda(functions=functions), FakeCloudWatch(sums=sums))

    usage = app.month_to_date_usage(datetime.datetime(2026, 10, 24, tzinfo=datetime.timezone.utc))

    assert usage == app.Usage(gb_seconds=24.0, requests=107, converter_invocations=7)


# --- handler --------------------------------------------------------------------------


def test_spike_alarm_switches_the_converter_off_and_says_so(aws):
    lam = FakeLambda()
    sns = aws(lam)

    app.lambda_handler(_sns_event({"AlarmName": "spike", "NewStateValue": "ALARM"}), None)

    assert lam.calls == [("put", "converter", 0)]
    assert "switched OFF" in sns.messages[0]["Subject"]


def test_spike_alarm_does_nothing_when_already_off(aws):
    lam = FakeLambda(reserved=0)
    sns = aws(lam)

    app.lambda_handler(_sns_event({"AlarmName": "spike", "NewStateValue": "ALARM"}), None)

    assert lam.calls == []
    assert sns.messages == []


def _hourly(aws, *, reserved, converter_calls, alarm_state="OK", alarm_fired_hours_ago=None):
    lam = FakeLambda(reserved=reserved, functions=[{"FunctionName": "converter", "MemorySize": 2048}])
    history = []
    if alarm_fired_hours_ago is not None:
        fired_at = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=alarm_fired_hours_ago)
        history = [(fired_at, "ALARM"), (fired_at + datetime.timedelta(minutes=6), "OK")]
    cloudwatch = FakeCloudWatch(
        sums={("converter", "Invocations"): converter_calls}, alarm_state=alarm_state, history=history
    )
    aws(lam, cloudwatch)
    app.lambda_handler({"source": "aws.events"}, None)
    return lam


def test_hourly_check_switches_off_when_a_limit_is_reached(aws):
    assert _hourly(aws, reserved=None, converter_calls=20000).calls == [("put", "converter", 0)]


def test_hourly_check_switches_back_on_under_the_limits_with_the_alarm_ok(aws):
    assert _hourly(aws, reserved=0, converter_calls=10).calls == [("delete", "converter")]


def test_hourly_check_leaves_it_off_while_the_spike_alarm_is_still_firing(aws):
    assert _hourly(aws, reserved=0, converter_calls=10, alarm_state="ALARM").calls == []


def test_hourly_check_switches_off_if_the_alarm_run_never_did(aws):
    # The SNS-triggered run failed, so the converter is still on while the alarm sits in ALARM.
    assert _hourly(aws, reserved=None, converter_calls=10, alarm_state="ALARM").calls == [
        ("put", "converter", 0)
    ]


def test_hourly_check_waits_out_the_cooldown_after_a_spike(aws):
    # The alarm cleared minutes after the switch-off (throttled calls aren't invocations), but it
    # fired 1 hour ago, inside the 6-hour cooldown, so a flood may still be running.
    assert _hourly(aws, reserved=0, converter_calls=10, alarm_fired_hours_ago=1).calls == []


def test_hourly_check_switches_back_on_once_the_cooldown_has_passed(aws):
    assert _hourly(aws, reserved=0, converter_calls=10, alarm_fired_hours_ago=7).calls == [
        ("delete", "converter")
    ]
