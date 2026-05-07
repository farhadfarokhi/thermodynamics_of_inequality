"""
wb_reshape.py

Reshapes the World Bank wide-format CSV (NY.GDP.PCAP.PP.CD) into the
long-format raw_gdp.csv expected by thermodynamics_empirical.m.

Usage:
    python wb_reshape.py                          # uses defaults below
    python wb_reshape.py input.csv output.csv     # explicit paths

Requirements: pandas (pip install pandas)
"""

import sys
import pandas as pd
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────
INPUT  = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("data/raw_worldbank_wide.csv")
OUTPUT = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("data/raw_gdp.csv")

# ── Read ───────────────────────────────────────────────────────────────────
# Scan for the header row — works regardless of how many preamble rows
# the World Bank includes (0, 2, 4, or any other number).
with open(INPUT, encoding="utf-8-sig") as f:
    lines = f.readlines()

header_idx = next(
    i for i, line in enumerate(lines)
    if "Country Name" in line or "Economy" in line
)
print(f"Header found at line {header_idx + 1} (0-indexed: {header_idx})")

df = pd.read_csv(INPUT, skiprows=header_idx, dtype=str)
print(f"Columns: {list(df.columns[:6])} ...")
print(f"Shape:   {df.shape}")

# ── Identify columns ───────────────────────────────────────────────────────
col_lower = {c: c.lower() for c in df.columns}

# Country code column
code_col = next(
    (c for c, cl in col_lower.items()
     if "country" in cl and "code" in cl), None
) or next(
    (c for c, cl in col_lower.items()
     if cl in ("code", "iso3", "economy code")), None
)

# Country name column
name_col = next(
    (c for c, cl in col_lower.items()
     if "country" in cl and "name" in cl), None
) or next(
    (c for c, cl in col_lower.items()
     if cl in ("economy", "name", "country")), None
)

if code_col is None or name_col is None:
    print("\nCould not auto-detect columns. All column names:")
    for c in df.columns:
        print(f"  {repr(c)}")
    raise SystemExit("Fix code_col / name_col manually and re-run.")

print(f"Country code column : {repr(code_col)}")
print(f"Country name column : {repr(name_col)}")

# Year columns: any column whose name is a 4-digit integer 1900-2100
year_cols = [c for c in df.columns if c.strip().lstrip("x").isdigit()
             and 1900 <= int(c.strip().lstrip("x")) <= 2100]
print(f"Year columns        : {year_cols[0]} … {year_cols[-1]} ({len(year_cols)} total)")

# ── Melt to long format ────────────────────────────────────────────────────
long = df[[code_col, name_col] + year_cols].melt(
    id_vars=[code_col, name_col],
    value_vars=year_cols,
    var_name="Year",
    value_name="GDP_PPP",
)

long = long.rename(columns={code_col: "CountryCode", name_col: "CountryName"})
long["Year"]    = long["Year"].str.lstrip("x").astype(int)
long["GDP_PPP"] = pd.to_numeric(long["GDP_PPP"], errors="coerce")

# Drop missing / zero values and aggregates (World Bank uses 3-letter ISO3;
# non-country aggregates like "WLD", "EUU" etc. are typically longer or differ)
long = long.dropna(subset=["GDP_PPP"])
long = long[long["GDP_PPP"] > 0]
long = long.sort_values(["CountryCode", "Year"]).reset_index(drop=True)

# ── Save ───────────────────────────────────────────────────────────────────
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
long.to_csv(OUTPUT, index=False)

print(f"\nSaved {len(long):,} rows → {OUTPUT}")
print(long.head(6).to_string(index=False))
