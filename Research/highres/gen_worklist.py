#!/usr/bin/env python3
"""Regenerate worklist.md from progress.json.

worklist.md is a human-readable mirror of the machine-readable progress.json
(the single source of truth). Run this whenever progress.json changes:

    python3 Research/highres/gen_worklist.py

It groups collections by platform cluster so reuse is visible, and marks an
entry [x] once it reaches a terminal status (committed / no-improvement / blocked).
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PROGRESS = os.path.join(HERE, "progress.json")
WORKLIST = os.path.join(HERE, "worklist.md")

TERMINAL = {"committed", "no-improvement", "blocked"}

# Display order of platform clusters in the worklist.
CLUSTER_ORDER = [
    "recollect", "flickr", "iiif", "ehiveIIIF", "pastPerfect",
    "weservProxy", "aklMuseumCloudimg", "thumbnailerProxy", "tapuhi",
    "stringSwap", "boutique",
]


def main():
    with open(PROGRESS) as f:
        doc = json.load(f)

    lines = []
    lines.append("# High-Res Sweep Worklist")
    lines.append("")
    lines.append("Human-readable mirror of `progress.json` (the source of truth).")
    lines.append("Regenerate with `python3 Research/highres/gen_worklist.py`.")
    lines.append("")

    removal = doc.get("removal", {})
    rdone = removal.get("status") == "done"
    box = "x" if rdone else " "
    lines.append("## Removal")
    lines.append(
        f"- [{box}] REMOVE {removal.get('collection')} — {removal.get('status')}"
    )
    lines.append("")

    cols = doc["collections"]
    done = sum(1 for c in cols if c["status"] in TERMINAL)
    lines.append(f"## Collections ({done}/{len(cols)} terminal)")
    lines.append("")

    by_cluster = {}
    for c in cols:
        by_cluster.setdefault(c["platform"], []).append(c)

    clusters = CLUSTER_ORDER + [
        p for p in by_cluster if p not in CLUSTER_ORDER
    ]
    seen = set()
    for cluster in clusters:
        if cluster in seen or cluster not in by_cluster:
            continue
        seen.add(cluster)
        lines.append(f"### {cluster}")
        for c in sorted(by_cluster[cluster], key=lambda x: x["order"]):
            box = "x" if c["status"] in TERMINAL else " "
            lines.append(
                f"- [{box}] ({c['order']:02d}) {c['name']} — "
                f"group {c['group']} — platform {c['platform']} — {c['status']}"
            )
        lines.append("")

    with open(WORKLIST, "w") as f:
        f.write("\n".join(lines))
    print(f"Wrote {WORKLIST} ({done}/{len(cols)} terminal)")


if __name__ == "__main__":
    main()
