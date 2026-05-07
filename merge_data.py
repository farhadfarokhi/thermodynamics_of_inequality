"""
merge_data.py

Merges the four raw source files into oecd_merged.csv

Expected inputs (all in data/):
    raw_gdp.csv    -- output of wb_reshape.py
    raw_gini.csv   -- OECD Income Distribution Database export
    raw_tax.csv    -- OECD Revenue Statistics export
    raw_educ.csv   -- OECD EAG graduate share (ISCED 7+8) export

Output:
    data/oecd_merged.csv

Usage:
    python merge_data.py

Requirements: pandas (pip install pandas)
"""

import pandas as pd
from pathlib import Path

DATA = Path("data")
OUT  = DATA / "oecd_merged.csv"

# ── Helpers ────────────────────────────────────────────────────────────────

def normalise_iso3(s: pd.Series) -> pd.Series:
    """Upper-case, strip whitespace, drop quotes."""
    return s.astype(str).str.strip().str.strip('"').str.upper()

def find_col(df: pd.DataFrame, *keywords) -> str:
    """Return the first column whose lower-case name contains ALL keywords."""
    for col in df.columns:
        cl = col.lower()
        if all(k in cl for k in keywords):
            return col
    print(f"  !! Could not find column matching {keywords}.")
    print(f"     Available columns: {list(df.columns)}")
    raise KeyError(f"No column matching {keywords} in {list(df.columns)}")

def auto_skiprows(path: Path, *markers) -> int:
    """Return number of rows to skip so the first row containing any marker is row 0.
    Tries each marker in turn; raises with a helpful message if none match."""
    with open(path, encoding="utf-8-sig") as f:
        lines = f.readlines()
    for i, line in enumerate(lines):
        if any(m.lower() in line.lower() for m in markers):
            return i
    # Nothing matched — print the first 10 lines to help diagnose
    print(f"\n  First 10 lines of {path}:")
    for j, l in enumerate(lines[:10]):
        print(f"    [{j}] {l.rstrip()}")
    raise ValueError(
        f"Could not find any of {markers} in {path}.\n"
        f"Check the file above and update the marker list in merge_data.py."
    )

# ══════════════════════════════════════════════════════════════════════════
# 1. GDP  (already long-format from wb_reshape.py)
# ══════════════════════════════════════════════════════════════════════════
print("── Loading GDP ──────────────────────────────────────────────────────")
gdp = pd.read_csv(DATA / "raw_gdp.csv", dtype=str)
gdp.columns = gdp.columns.str.strip()

gdp["CountryCode"] = normalise_iso3(gdp["CountryCode"])
gdp["Year"]        = gdp["Year"].astype(int)
gdp["GDP_PPP"]     = pd.to_numeric(gdp["GDP_PPP"], errors="coerce")
gdp = gdp[["CountryCode", "CountryName", "Year", "GDP_PPP"]].dropna()

print(f"  {len(gdp):,} rows | {gdp['CountryCode'].nunique()} countries "
      f"| {gdp['Year'].min()}–{gdp['Year'].max()}")

# ══════════════════════════════════════════════════════════════════════════
# 2. GINI  (OECD IDD export — long format)
#    Expected columns (may be named differently): 
#                       REF_AREA, TIME_PERIOD, OBS_VALUE
#    Gini values are on a 0–1 scale in the IDD; we enforce that below.
# ══════════════════════════════════════════════════════════════════════════
print("── Loading Gini ─────────────────────────────────────────────────────")
skip = auto_skiprows(DATA / "raw_gini.csv", "REF_AREA", "LOCATION", "COU", "Country")
gini_raw = pd.read_csv(DATA / "raw_gini.csv", skiprows=skip, dtype=str)
gini_raw.columns = gini_raw.columns.str.strip()
print(f"  Columns: {list(gini_raw.columns)}")

try:
    code_col = find_col(gini_raw, "ref_area")
except KeyError:
    try:
        code_col = find_col(gini_raw, "location")
    except KeyError:
        code_col = find_col(gini_raw, "cou")

try:
    year_col = find_col(gini_raw, "time")
except KeyError:
    year_col = find_col(gini_raw, "year")

try:
    val_col = find_col(gini_raw, "obs_value")
except KeyError:
    val_col = find_col(gini_raw, "value")

gini = gini_raw[[code_col, year_col, val_col]].copy()
gini.columns = ["CountryCode", "Year", "Gini"]
gini["CountryCode"] = normalise_iso3(gini["CountryCode"])
gini["Year"]        = pd.to_numeric(gini["Year"], errors="coerce").astype("Int64")
gini["Gini"]        = pd.to_numeric(gini["Gini"], errors="coerce")
gini = gini.dropna()

# The IDD reports Gini on 0–1; if values look like percentages rescale.
if gini["Gini"].median() > 1:
    print("  Gini values appear to be 0–100; dividing by 100.")
    gini["Gini"] /= 100

# Keep only the disposable-income Gini if multiple measures are present.
# The IDD download filtered to INC_DISP_GINI should already be clean, but
# if extra rows slipped through, take the per country-year median.
gini = (gini.groupby(["CountryCode", "Year"], as_index=False)["Gini"]
            .median())

print(f"  {len(gini):,} rows | {gini['CountryCode'].nunique()} countries "
      f"| {int(gini['Year'].min())}–{int(gini['Year'].max())}")

# ══════════════════════════════════════════════════════════════════════════
# 3. TAX RATE  (OECD Revenue Statistics export — long format)
#    Expected columns: REF_AREA, TIME_PERIOD, OBS_VALUE (rate as % of GDP)
# ══════════════════════════════════════════════════════════════════════════
print("── Loading Tax rate ─────────────────────────────────────────────────")
skip = auto_skiprows(DATA / "raw_tax.csv", "REF_AREA", "LOCATION", "COU", "Country", "GOV")
tax_raw = pd.read_csv(DATA / "raw_tax.csv", skiprows=skip, dtype=str)
tax_raw.columns = tax_raw.columns.str.strip()
print(f"  Columns: {list(tax_raw.columns)}")

try:
    code_col = find_col(tax_raw, "ref_area")
except KeyError:
    try:
        code_col = find_col(tax_raw, "location")
    except KeyError:
        code_col = find_col(tax_raw, "cou")

try:
    year_col = find_col(tax_raw, "time")
except KeyError:
    year_col = find_col(tax_raw, "year")

try:
    val_col = find_col(tax_raw, "obs_value")
except KeyError:
    val_col = find_col(tax_raw, "value")

tax = tax_raw[[code_col, year_col, val_col]].copy()
tax.columns = ["CountryCode", "Year", "TaxRate"]
tax["CountryCode"] = normalise_iso3(tax["CountryCode"])
tax["Year"]        = pd.to_numeric(tax["Year"], errors="coerce").astype("Int64")
tax["TaxRate"]     = pd.to_numeric(tax["TaxRate"], errors="coerce")
tax = tax.dropna()

# If multiple tax categories slipped through, take the per country-year sum.
# (If you filtered to a single category before export this is a no-op.)
tax = (tax.groupby(["CountryCode", "Year"], as_index=False)["TaxRate"]
          .sum())

print(f"  {len(tax):,} rows | {tax['CountryCode'].nunique()} countries "
      f"| {int(tax['Year'].min())}–{int(tax['Year'].max())}")

# ══════════════════════════════════════════════════════════════════════════
# 4. EDUCATION  (OECD EAG export — long format)
#    Expected columns: COUNTRY (or REF_AREA), Year, Value
#    Values are percentages of 25-64 population with ISCED 7 or 8.
#    If ISCED 7 and 8 are separate rows they are summed here.
# ══════════════════════════════════════════════════════════════════════════
print("── Loading Education ────────────────────────────────────────────────")
# Try both common header markers
for marker in ("REF_AREA", "COUNTRY", "Country"):
    try:
        skip = auto_skiprows(DATA / "raw_educ.csv", marker)
        break
    except ValueError:
        continue

educ_raw = pd.read_csv(DATA / "raw_educ.csv", skiprows=skip, dtype=str)
educ_raw.columns = educ_raw.columns.str.strip()
print(f"  Columns: {list(educ_raw.columns)}")

# Find country code column
try:
    code_col = find_col(educ_raw, "ref_area")
except KeyError:
    try:
        code_col = find_col(educ_raw, "location")
    except KeyError:
        try:
            code_col = find_col(educ_raw, "country")
        except KeyError:
            code_col = educ_raw.columns[0]
            print(f"  Warning: guessing country code column = {repr(code_col)}")

# Find year column — EAG exports often use "Year" literally
year_col = None
for candidate in ["time_period", "time", "year", "obstime"]:
    try:
        year_col = find_col(educ_raw, candidate)
        break
    except KeyError:
        continue
if year_col is None:
    # Last resort: pick the first column that looks like it contains 4-digit years
    for col in educ_raw.columns:
        sample = educ_raw[col].dropna().head(20)
        numeric = pd.to_numeric(sample, errors="coerce").dropna()
        if len(numeric) > 0 and numeric.between(1990, 2030).all():
            year_col = col
            print(f"  Warning: guessing year column = {repr(year_col)}")
            break
if year_col is None:
    raise ValueError("Cannot identify year column in raw_educ.csv. "
                     f"Columns are: {list(educ_raw.columns)}")

# Find value column
try:
    val_col = find_col(educ_raw, "obs_value")
except KeyError:
    try:
        val_col = find_col(educ_raw, "value")
    except KeyError:
        val_col = find_col(educ_raw, "obs")

print(f"  Using: code={repr(code_col)}  year={repr(year_col)}  value={repr(val_col)}")

educ = educ_raw[[code_col, year_col, val_col]].copy()
educ.columns = ["CountryCode", "Year", "GradShare"]
educ["CountryCode"] = normalise_iso3(educ["CountryCode"])
educ["Year"]        = pd.to_numeric(educ["Year"], errors="coerce")
educ["GradShare"]   = pd.to_numeric(educ["GradShare"], errors="coerce")
educ = educ.dropna(subset=["CountryCode", "Year", "GradShare"])
educ["Year"] = educ["Year"].astype(int)

if educ.empty:
    raise ValueError(
        "Education dataframe is empty after cleaning.\n"
        f"  code_col={repr(code_col)}, year_col={repr(year_col)}, val_col={repr(val_col)}\n"
        "  Check that these point to the right columns in raw_educ.csv."
    )

# Sum ISCED 7 + ISCED 8 if both levels are present as separate rows,
# then convert from percentage to fraction.
educ = (educ.groupby(["CountryCode", "Year"], as_index=False)["GradShare"]
            .sum())
if educ["GradShare"].median() > 1:
    print("  GradShare appears to be a percentage; dividing by 100.")
    educ["GradShare"] /= 100

print(f"  {len(educ):,} rows | {educ['CountryCode'].nunique()} countries "
      f"| {educ['Year'].min()}–{educ['Year'].max()}")

# ══════════════════════════════════════════════════════════════════════════
# 5. MERGE
# ══════════════════════════════════════════════════════════════════════════
print("── Merging ──────────────────────────────────────────────────────────")

merged = (gdp
          .merge(gini,  on=["CountryCode", "Year"], how="inner")
          .merge(tax,   on=["CountryCode", "Year"], how="inner")
          .merge(educ,  on=["CountryCode", "Year"], how="inner"))

merged = merged.sort_values(["CountryCode", "Year"]).reset_index(drop=True)

# ── Summary ────────────────────────────────────────────────────────────────
print(f"\n  Country-year observations : {len(merged):,}")
print(f"  Countries                 : {merged['CountryCode'].nunique()}")
print(f"  Year range                : {merged['Year'].min()}–{merged['Year'].max()}")
print(f"\n  Missing values per column:")
print(merged[["GDP_PPP","Gini","TaxRate","GradShare"]].isna().sum().to_string())

print(f"\n  Sample rows:")
print(merged.head(6).to_string(index=False))

# Countries present in GDP but dropped by the inner join
dropped = set(gdp["CountryCode"]) - set(merged["CountryCode"])
if dropped:
    print(f"\n  Countries in GDP but missing from merged output ({len(dropped)}):")
    print("  " + ", ".join(sorted(dropped)))

# ── Save ───────────────────────────────────────────────────────────────────
OUT.parent.mkdir(parents=True, exist_ok=True)
merged.to_csv(OUT, index=False)
print(f"\n  Saved → {OUT}")
