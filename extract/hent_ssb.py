"""
Henter fem tabeller fra SSBs statistikkbank (API v0, json-stat2) og skriver
dem som flate CSV-filer til data/raw/ssb/. Kun standardbiblioteket.

Tabeller
  03650  Transportytelser etter type transport, kvartal   (tomkjøring, km, tonn, tonnkm)
  08478  Samme som 03650, år                               (1996-)
  09830  Transportmengde/-arbeid fra fylke x til fylke, år
  06988  Transportmengde/-arbeid etter vareslag (5 grupper), kvartal
  13321  Km/tonn/tonnkm etter avstandsklasse x vareslag (NST 2007), år

Hver fil får en rad per kombinasjon av dimensjonskoder, med kolonnene
  <dimensjonskoder...>, statistikkvariabel, verdi
Manifest med sha256 og uttrekkstidspunkt skrives til data/raw/ssb/manifest.json.
"""
import csv
import hashlib
import itertools
import json
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

API = "https://data.ssb.no/api/v0/no/table/{}"
RAW = Path(__file__).resolve().parents[1] / "data" / "raw" / "ssb"

TABELLER = {
    "03650": "transportytelser_kvartal",
    "08478": "transportytelser_aar",
    "09830": "fylkesmatrise_aar",
    "06988": "vareslag_kvartal",
    "13321": "avstand_vareslag_aar",
}


def hent(url, body=None, forsok=5):
    for i in range(forsok):
        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(body).encode() if body else None,
                headers={"Content-Type": "application/json", "User-Agent": "gods-kapasitet/1.0"},
                method="POST" if body else "GET",
            )
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.load(r)
        except (urllib.error.URLError, TimeoutError) as e:
            vent = 2 ** i
            print(f"  feil ({e}), prøver igjen om {vent}s", file=sys.stderr)
            time.sleep(vent)
    raise SystemExit(f"Ga opp: {url}")


def alle_verdier(meta):
    """Spørring som ber om alle verdier i alle dimensjoner."""
    return {
        "query": [
            {"code": v["code"], "selection": {"filter": "all", "values": ["*"]}}
            for v in meta["variables"]
        ],
        "response": {"format": "json-stat2"},
    }


def til_rader(js):
    dims = js["id"]
    kategorier = [list(js["dimension"][d]["category"]["index"].keys()) for d in dims]
    etiketter = [js["dimension"][d]["category"]["label"] for d in dims]
    verdier = js["value"]
    rader = []
    for i, kombo in enumerate(itertools.product(*kategorier)):
        v = verdier[i]
        rad = {}
        for d, kode, lab in zip(dims, kombo, etiketter):
            if d == "ContentsCode":
                rad["statistikkvariabel"] = kode
                rad["statistikkvariabel_tekst"] = lab[kode]
            else:
                rad[d] = kode
                rad[f"{d}_tekst"] = lab[kode]
        rad["verdi"] = "" if v is None else v
        rader.append(rad)
    return rader


def main():
    RAW.mkdir(parents=True, exist_ok=True)
    manifest = {"uttrekkstidspunkt": datetime.now(timezone.utc).isoformat(), "tabeller": {}}
    for tid, navn in TABELLER.items():
        print(f"{tid} -> {navn}.csv")
        meta = hent(API.format(tid))
        js = hent(API.format(tid), alle_verdier(meta))
        rader = til_rader(js)
        sti = RAW / f"{navn}.csv"
        with open(sti, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=list(rader[0].keys()))
            w.writeheader()
            w.writerows(rader)
        sha = hashlib.sha256(sti.read_bytes()).hexdigest()
        manifest["tabeller"][tid] = {
            "fil": sti.name,
            "tittel": js["label"],
            "rader": len(rader),
            "sist_oppdatert_ssb": js.get("updated"),
            "sha256": sha,
        }
        print(f"  {len(rader)} rader, sha256 {sha[:12]}")
    (RAW / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    print("Ferdig.")


if __name__ == "__main__":
    main()
