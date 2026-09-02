# Consumer complaints: fintechs vs. an incumbent bank

An analysis of the CFPB Consumer Complaint Database comparing four consumer
fintechs, Chime, Block, PayPal, and Coinbase, against Wells Fargo as an
incumbent benchmark.

**Question:** do consumers complain about fintechs at a different rate, about
different things, and with different outcomes than they do about a traditional
bank serving overlapping customers?

**Source:** Consumer Financial Protection Bureau, Consumer Complaint Database
(public). Filtered to the five companies above, complaints received
January 2024 to June 2026.

## Contents

| File | Purpose |
|---|---|
| `01_clean_cfpb.py` | Loads the raw export, normalises company names, parses dates, writes `cfpb_clean.csv` and `cfpb.db` |
| `02_analysis.sql` | Ten analysis queries against the SQLite table `complaints` |

## Reproducing

```bash
pip install pandas
python 01_clean_cfpb.py complaints_raw.csv
sqlite3 cfpb.db < 02_analysis.sql
```

## Method notes

**Company names.** The CFPB files a single firm under multiple legal entity
names; Block appears as both "Block, Inc." and "Square, Inc." Names are
normalised by substring match in `01_clean_cfpb.py`, and unmatched names are
printed for review rather than silently dropped. Substring matching can
misclassify edge cases, which is a known source of noise.

**Counts vs. shares.** Wells Fargo generates far more complaints than any
fintech in the sample, which reflects its size rather than its conduct. Every
comparative measure is therefore expressed as a share within company, not as a
raw count. Complaint volume is not normalised by customer count, because the
CFPB publishes no such denominator and customer figures across these five firms
are not defined consistently enough to construct one. This is one of the
analysis's main limitations.

**Response categories.** Query 7 classifies outcomes by matching the start of
the CFPB's response text. If the CFPB revises that wording, those filters would
need updating.

**Self-selection.** The database records complaints escalated to a federal
regulator, not all consumer dissatisfaction. Firms whose customers skew younger
and more online may be over-represented independent of service quality.

Author: Ashley
Last updated: September 2026
