"""
Eksporterer mart-laget til data/mart/ for Power BI.

  Dimensjoner og små fakta   -> CSV, skrives alltid på nytt
  fact_etappe                -> én parquet-fil per måned i data/mart/fact_etappe/,
                                skrives bare når innholdet i måneden er endret

Manifestet data/mart/manifest.json holder sha256 per partisjon. Det er dette
Power BI-modellen bygger på: RangeStart/RangeEnd velger hvilke filer som
leses, og en uendret fil trenger aldri å leses på nytt.
"""
import hashlib
import json
from pathlib import Path

import duckdb

ROT = Path(__file__).resolve().parents[1]
DB = ROT / "data" / "gods_kapasitet.duckdb"
MART = ROT / "data" / "mart"
PART = MART / "fact_etappe"

CSV_TABELLER = [
    "dim_dato", "dim_fylke", "dim_varegruppe", "dim_kjoretoy",
    "dim_kjoretoygruppe", "dim_lager",
    "fact_kapasitet_maaned", "fact_ssb_transportytelser", "fact_ssb_transportytelser_aar",
    "fact_ssb_fylkesstrom", "fact_ssb_avstand", "fact_ssb_vareslag",
]


def main():
    MART.mkdir(parents=True, exist_ok=True)
    PART.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB), read_only=True)

    for t in CSV_TABELLER:
        sti = MART / f"{t}.csv"
        con.execute(f"copy (select * from marts.{t}) to '{sti.as_posix()}' (header, delimiter ',')")
        n = con.execute(f"select count(*) from marts.{t}").fetchone()[0]
        print(f"{t}.csv: {n} rader")

    manifest_sti = MART / "manifest.json"
    manifest = json.loads(manifest_sti.read_text()) if manifest_sti.exists() else {}
    maaneder = [r[0] for r in con.execute(
        "select distinct strftime(maaned_start, '%Y-%m') from marts.fact_etappe order by 1").fetchall()]
    endret, uendret = [], []
    for m in maaneder:
        tmp = PART / f"_tmp_{m}.parquet"
        con.execute(f"""
            copy (select * from marts.fact_etappe
                  where strftime(maaned_start, '%Y-%m') = '{m}'
                  order by dato, etappe_id)
            to '{tmp.as_posix()}' (format parquet, compression zstd)
        """)
        sha = hashlib.sha256(tmp.read_bytes()).hexdigest()
        mal = PART / f"fact_etappe_{m}.parquet"
        if manifest.get(m, {}).get("sha256") == sha and mal.exists():
            tmp.unlink()
            uendret.append(m)
        else:
            tmp.replace(mal)
            n = con.execute(
                f"select count(*) from marts.fact_etappe where strftime(maaned_start, '%Y-%m') = '{m}'").fetchone()[0]
            manifest[m] = {"fil": mal.name, "rader": n, "sha256": sha}
            endret.append(m)
    manifest_sti.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"fact_etappe: {len(maaneder)} partisjoner, skrevet {len(endret)}, uendret {len(uendret)}")
    if endret:
        print("  skrevet: " + ", ".join(endret))


if __name__ == "__main__":
    main()
