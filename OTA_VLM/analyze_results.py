#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations

import json
from pathlib import Path
import sys

try:
    import pandas as pd
    import matplotlib.pyplot as plt
except ImportError as exc:
    print("Missing dependency. Install with: pip install pandas matplotlib")
    raise SystemExit(1) from exc


BASE_DIR = (Path(__file__).resolve().parent / "failed case").resolve()
OUT_DIR = (Path(__file__).resolve().parent / "analysis_output").resolve()


def load_jsonl_files(base_dir: Path) -> list[dict]:
    rows: list[dict] = []
    for path in sorted(base_dir.glob("*/result.jsonl")):
        with path.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                rows.append(json.loads(line))
    return rows


def save_bar(series, title: str, xlabel: str, ylabel: str, out_path: Path):
    ax = series.plot(kind="bar", figsize=(10, 5))
    ax.set_title(title)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    plt.tight_layout()
    plt.savefig(out_path)
    plt.close()


def main() -> int:
    if not BASE_DIR.is_dir():
        print(f"BASE_DIR not found: {BASE_DIR}")
        return 1

    rows = load_jsonl_files(BASE_DIR)
    if not rows:
        print("No result.jsonl files found.")
        return 1

    OUT_DIR.mkdir(exist_ok=True)

    df = pd.json_normalize(rows)

    for col in [
        "error.code",
        "vlm.root_cause",
        "context.region.city",
        "context.time.time_bucket",
        "context.network.rssi_dbm",
        "context.network.latency_ms",
    ]:
        if col not in df.columns:
            df[col] = ""

    df["is_failure"] = (
        df["error.code"].fillna("").astype(str).str.upper().ne("")
        & df["error.code"].fillna("").astype(str).str.upper().ne("NONE")
    )

    summary = {
        "total_records": int(len(df)),
        "failure_records": int(df["is_failure"].sum()),
        "failure_rate": float(df["is_failure"].mean()) if len(df) else 0.0,
    }

    (OUT_DIR / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")

    root_counts = (
        df["vlm.root_cause"].fillna("UNKNOWN").replace("", "UNKNOWN").value_counts()
    )
    root_counts.to_csv(OUT_DIR / "root_cause_counts.csv", header=["count"])
    save_bar(
        root_counts,
        "Root Cause Counts",
        "root_cause",
        "count",
        OUT_DIR / "root_cause_counts.png",
    )

    city_stats = (
        df.groupby("context.region.city")["is_failure"]
        .agg(["sum", "count"])
        .rename(columns={"sum": "failures", "count": "total"})
    )
    city_stats["failure_rate"] = city_stats["failures"] / city_stats["total"]
    city_stats.sort_values("failure_rate", ascending=False).to_csv(
        OUT_DIR / "city_failure_rates.csv"
    )
    save_bar(
        city_stats["failure_rate"].sort_values(ascending=False),
        "Failure Rate by City",
        "city",
        "failure_rate",
        OUT_DIR / "city_failure_rates.png",
    )

    time_stats = (
        df[df["is_failure"]]
        .groupby("context.time.time_bucket")
        .size()
        .sort_index()
    )
    time_stats.to_csv(OUT_DIR / "time_bucket_failures.csv", header=["count"])
    save_bar(
        time_stats,
        "Failures by Time Bucket",
        "time_bucket",
        "count",
        OUT_DIR / "time_bucket_failures.png",
    )

    fail_df = df[df["is_failure"]].copy()
    fail_df["context.network.rssi_dbm"] = pd.to_numeric(
        fail_df["context.network.rssi_dbm"], errors="coerce"
    )
    fail_df["context.network.latency_ms"] = pd.to_numeric(
        fail_df["context.network.latency_ms"], errors="coerce"
    )

    rssi_bins = [-100, -85, -75, -65, -55, -45, -35]
    rssi_bucket = pd.cut(
        fail_df["context.network.rssi_dbm"], bins=rssi_bins, include_lowest=True
    )
    rssi_counts = rssi_bucket.value_counts().sort_index()
    rssi_counts.to_csv(OUT_DIR / "rssi_failure_buckets.csv", header=["count"])
    save_bar(
        rssi_counts,
        "Failures by RSSI Bucket",
        "rssi_dbm",
        "count",
        OUT_DIR / "rssi_failure_buckets.png",
    )

    latency_bins = [0, 50, 100, 200, 300, 500, 1000]
    latency_bucket = pd.cut(
        fail_df["context.network.latency_ms"], bins=latency_bins, include_lowest=True
    )
    latency_counts = latency_bucket.value_counts().sort_index()
    latency_counts.to_csv(OUT_DIR / "latency_failure_buckets.csv", header=["count"])
    save_bar(
        latency_counts,
        "Failures by Latency Bucket",
        "latency_ms",
        "count",
        OUT_DIR / "latency_failure_buckets.png",
    )

    df.to_csv(OUT_DIR / "all_records_flat.csv", index=False)
    print(f"Wrote analysis outputs to: {OUT_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
