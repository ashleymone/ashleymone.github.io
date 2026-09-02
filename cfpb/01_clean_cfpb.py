"""
CFPB Consumer Complaint Database — cleaning and load
Project 2: Fintech vs. incumbent bank complaint analysis

Input : raw CFPB export (CSV) filtered to the five target companies
Output: cfpb_clean.csv and cfpb.db (SQLite, table `complaints`)

Run:  python 01_clean_cfpb.py complaints_raw.csv
"""

import sys
import sqlite3
import pandas as pd

RAW = sys.argv[1] if len(sys.argv) > 1 else "complaints_raw.csv"
CLEAN_CSV = "cfpb_clean.csv"
DB = "cfpb.db"

KEEP = [
    "Date received",
    "Product",
    "Sub-product",
    "Issue",
    "Sub-issue",
    "Company",
    "State",
    "Submitted via",
    "Company response to consumer",
    "Timely response?",
    "Consumer disputed?",
    "Complaint ID",
]

RENAME = {
    "Date received": "date_received",
    "Product": "product",
    "Sub-product": "sub_product",
    "Issue": "issue",
    "Sub-issue": "sub_issue",
    "Company": "company_raw",
    "State": "state",
    "Submitted via": "submitted_via",
    "Company response to consumer": "company_response",
    "Timely response?": "timely_response",
    "Consumer disputed?": "consumer_disputed",
    "Complaint ID": "complaint_id",
}

# CFPB files the same firm under several legal names. Longest match wins,
# so order matters here.
COMPANY_MAP = [
    ("chime", "Chime"),
    ("block, inc", "Block"),
    ("square", "Block"),
    ("block", "Block"),
    ("paypal", "PayPal"),
    ("coinbase", "Coinbase"),
    ("wells fargo", "Wells Fargo"),
]

# Everything except Wells Fargo is a fintech. This column is what the whole
# dashboard splits on.
SEGMENT = {
    "Chime": "Fintech",
    "Block": "Fintech",
    "PayPal": "Fintech",
    "Coinbase": "Fintech",
    "Wells Fargo": "Incumbent bank",
}


def normalise_company(raw):
    if pd.isna(raw):
        return None
    text = str(raw).lower()
    for needle, clean in COMPANY_MAP:
        if needle in text:
            return clean
    return None


def main():
    df = pd.read_csv(RAW, low_memory=False)
    print(f"Raw rows loaded:      {len(df):,}")
    print(f"Raw columns:          {len(df.columns)}")

    present = [c for c in KEEP if c in df.columns]
    missing = [c for c in KEEP if c not in df.columns]
    if missing:
        print(f"Columns not in export (skipped): {missing}")
    df = df[present].rename(columns=RENAME)

    df["company"] = df["company_raw"].apply(normalise_company)

    unmatched = df[df["company"].isna()]["company_raw"].value_counts()
    if len(unmatched):
        print("\nUnmatched company names — check before dropping:")
        print(unmatched.head(20))
    df = df[df["company"].notna()].copy()

    df["segment"] = df["company"].map(SEGMENT)

    df["date_received"] = pd.to_datetime(df["date_received"], errors="coerce")
    df = df[df["date_received"].notna()].copy()
    df["year_month"] = df["date_received"].dt.to_period("M").astype(str)
    df["date_received"] = df["date_received"].dt.strftime("%Y-%m-%d")

    before = len(df)
    df = df.drop_duplicates(subset="complaint_id")
    if before != len(df):
        print(f"\nDuplicate complaint IDs removed: {before - len(df):,}")

    for col in ["issue", "sub_issue", "product", "state"]:
        if col in df.columns:
            df[col] = df[col].fillna("Not specified").str.strip()

    df = df.drop(columns=["company_raw"])

    print(f"\nClean rows:           {len(df):,}")
    print(f"Date range:           {df['date_received'].min()} to {df['date_received'].max()}")
    print("\nComplaints by company:")
    print(df["company"].value_counts().to_string())

    df.to_csv(CLEAN_CSV, index=False)

    conn = sqlite3.connect(DB)
    df.to_sql("complaints", conn, if_exists="replace", index=False)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_company ON complaints(company)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_month ON complaints(year_month)")
    conn.commit()
    conn.close()

    print(f"\nWrote {CLEAN_CSV} and {DB} (table: complaints)")


if __name__ == "__main__":
    main()
