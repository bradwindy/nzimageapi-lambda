"""Free-tier kill switch for the converter Lambda.

The converter's Function URL is public, so nothing else stops a flood of (validly signed) requests
from running it past Lambda's always-free allowance. This function turns the converter off by
setting its reserved concurrency to 0: every call is then throttled before it runs, so nothing is
billed. Turning it back on deletes the reservation.

Two triggers (template.yaml, ConverterGuardFunction):
  - The spike alarm, via SNS. An ALARM notification for SPIKE_ALARM_NAME switches the converter
    off straight away. Other messages on the topic (the API alarm, this function's own notices)
    are ignored.
  - An hourly schedule. It sums month-to-date usage from CloudWatch and switches the converter off
    when any limit is reached, or back on when every limit is clear and the spike alarm is OK.
    That is also how the converter comes back after a spike, or at the start of a new month.

During a sustained flood the converter cycles: off on the alarm, back on at the next hourly run
once the alarm clears, off again. The month-to-date limits bound the total, and once one is hit the
converter stays off until the month rolls over.
"""

import datetime
import json
import os
from dataclasses import dataclass

import boto3

FUNCTION_NAME = os.environ.get("CONVERTER_FUNCTION_NAME", "")
SPIKE_ALARM_NAME = os.environ.get("SPIKE_ALARM_NAME", "")
ALERT_TOPIC_ARN = os.environ.get("ALERT_TOPIC_ARN", "")
MAX_GB_SECONDS = float(os.environ.get("MAX_GB_SECONDS", "320000"))
MAX_REQUESTS = float(os.environ.get("MAX_REQUESTS", "800000"))
MAX_CONVERTER_INVOCATIONS = float(os.environ.get("MAX_CONVERTER_INVOCATIONS", "20000"))

_lambda = boto3.client("lambda")
_cloudwatch = boto3.client("cloudwatch")
_sns = boto3.client("sns")


@dataclass
class Usage:
    gb_seconds: float
    requests: float
    converter_invocations: float


def limits_reached(usage):
    """Names of the month-to-date limits `usage` has reached (empty when all are clear)."""
    reached = []
    if usage.gb_seconds >= MAX_GB_SECONDS:
        reached.append(f"compute {usage.gb_seconds:,.0f}/{MAX_GB_SECONDS:,.0f} GB-s")
    if usage.requests >= MAX_REQUESTS:
        reached.append(f"requests {usage.requests:,.0f}/{MAX_REQUESTS:,.0f}")
    if usage.converter_invocations >= MAX_CONVERTER_INVOCATIONS:
        reached.append(
            f"converter calls {usage.converter_invocations:,.0f}/{MAX_CONVERTER_INVOCATIONS:,.0f}"
        )
    return reached


def spike_alarm_fired(event):
    """True when `event` is an SNS delivery of SPIKE_ALARM_NAME entering ALARM."""
    for record in event.get("Records", []):
        try:
            message = json.loads(record["Sns"]["Message"])
        except (KeyError, TypeError, ValueError):
            continue
        if message.get("AlarmName") == SPIKE_ALARM_NAME and message.get("NewStateValue") == "ALARM":
            return True
    return False


def _month_start(now):
    return now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)


def _metric_sum(metric, function_name, start, end):
    response = _cloudwatch.get_metric_statistics(
        Namespace="AWS/Lambda",
        MetricName=metric,
        Dimensions=[{"Name": "FunctionName", "Value": function_name}],
        StartTime=start,
        EndTime=end,
        Period=86400,
        Statistics=["Sum"],
    )
    return sum(point["Sum"] for point in response["Datapoints"])


def month_to_date_usage(now):
    """Lambda usage across every function in the account since the start of the month.

    GB-seconds use each function's current memory size and the Duration metric, which excludes
    init time; the margin between MAX_GB_SECONDS and the 400,000 allowance covers both.
    """
    start = _month_start(now)
    usage = Usage(0.0, 0.0, 0.0)
    for page in _lambda.get_paginator("list_functions").paginate():
        for function in page["Functions"]:
            name = function["FunctionName"]
            invocations = _metric_sum("Invocations", name, start, now)
            duration_ms = _metric_sum("Duration", name, start, now)
            usage.requests += invocations
            usage.gb_seconds += duration_ms / 1000 * function["MemorySize"] / 1024
            if name == FUNCTION_NAME:
                usage.converter_invocations = invocations
    return usage


def spike_alarm_ok():
    alarms = _cloudwatch.describe_alarms(AlarmNames=[SPIKE_ALARM_NAME])["MetricAlarms"]
    return not alarms or alarms[0]["StateValue"] != "ALARM"


def converter_enabled():
    response = _lambda.get_function_concurrency(FunctionName=FUNCTION_NAME)
    return response.get("ReservedConcurrentExecutions") != 0


def set_converter_enabled(enabled, reason):
    """Switch the converter on or off. Does nothing (and sends nothing) if already there."""
    if converter_enabled() == enabled:
        return False
    if enabled:
        _lambda.delete_function_concurrency(FunctionName=FUNCTION_NAME)
    else:
        _lambda.put_function_concurrency(FunctionName=FUNCTION_NAME, ReservedConcurrentExecutions=0)
    state = "back on" if enabled else "OFF"
    print(f"converter switched {state}: {reason}")
    if ALERT_TOPIC_ARN:
        _sns.publish(
            TopicArn=ALERT_TOPIC_ARN,
            Subject=f"NZ Image converter switched {state}",
            Message=f"The JP2/TIFF converter Lambda was switched {state}.\n\nReason: {reason}",
        )
    return True


def lambda_handler(event, _context):
    if "Records" in event:
        if spike_alarm_fired(event):
            set_converter_enabled(False, f"{SPIKE_ALARM_NAME} fired")
        return {"action": "alarm"}

    usage = month_to_date_usage(datetime.datetime.now(datetime.timezone.utc))
    reached = limits_reached(usage)
    print(f"month-to-date usage: {usage}")
    if reached:
        set_converter_enabled(False, "month-to-date free-tier limit reached: " + ", ".join(reached))
    elif spike_alarm_ok():
        set_converter_enabled(True, "usage under every limit and the spike alarm is OK")
    return {"usage": usage.__dict__, "limits_reached": reached}
