"""
Deterministisk generator for syntetiske etapper (kjørte strekninger) for den
fiktive distributøren Nordvare AS. Skriver én parquet-fil per måned til
data/raw/turer/turer_YYYY-MM.parquet og en flåteliste til data/raw/kjoretoy.csv.

Bruk
  python src/generer_turer.py                 # standard: t.o.m. 2026-06
  python src/generer_turer.py --til 2026-07   # simulerer at en ny måned har kommet

Modellen
  En tur = to etapper: utgående (alltid lastet) og retur (lastet eller tom).
  Sannsynligheten for returlast avhenger av avlessingsfylket (seeds/
  ssb_kalibrering_retur.csv) og av kvartalet, slik at tomkjøringsandelen i km
  treffer SSB 03650 (nasjonal leie- og egentransport, ca. 26-30 %).

Innebygde og dokumenterte skjevheter (brukes i rapporten, se README)
  1. Volumbegrensede varegrupper (kjøl, frys, non-food) fyller bilen før
     nyttelasten er nådd. Vektbasert utnyttelsesgrad ser derfor lav ut uten at
     det er ledig plass.
  2. Returer for distribusjonsbiler er ofte "lastet" med returemballasje
     (RETUR): teller ikke som tomkjøring, men bruker under 20 % av nyttelasten.
  3. Nord-Norge har svært lav sannsynlighet for returlast.
  4. Sesong: desember og juni topper, januar/februar og juli bunner.

Innebygde datafeil (skal fanges i dbt)
  A. 0,3 % av lastede etapper har tonn over nyttelast (overlast eller feilregistrering).
  B. 1,5 % av utgående etapper mangler avlessingsfylke (kode 99), som i SSB.
  C. 0,2 % av etappene er registrert to ganger med samme etappe_id.
  D. Etterregistrering: en andel etapper registreres 1-25 dager etter kjøredato.
     Etapper registrert etter --til-månedens siste dag er ennå ikke synlige.
     Det er grunnen til at siste måned må lastes på nytt ved neste kjøring.
"""
import argparse
import csv
import hashlib
import json
import math
from datetime import date, timedelta
from pathlib import Path

import numpy as np
import pyarrow as pa
import pyarrow.parquet as pq

ROT = Path(__file__).resolve().parents[1]
SEEDS = ROT / "seeds"
RAW = ROT / "data" / "raw"
TURER = RAW / "turer"

FRA_MAANED = (2023, 1)
FRO = 20260901

SESONG = {1: 0.90, 2: 0.89, 3: 0.98, 4: 1.02, 5: 1.05, 6: 1.10,
          7: 0.93, 8: 1.01, 9: 1.03, 10: 1.05, 11: 1.04, 12: 1.13}
TOM_KVARTAL = {1: 0.02, 2: 0.055, 3: 0.055, 4: -0.01}   # justering av sannsynlighet for tom retur
TURER_PER_DAG = {"DIST": 2.0, "SEMI": 1.05, "MODUL": 0.80}
AVSTANDSSKALA = {"DIST": 110.0, "SEMI": 380.0, "MODUL": 650.0}
UTGAAENDE_VAREGRUPPER = {
    "DIST": (["TORR", "KJOL", "FRYS", "DRIKKE", "NONFOOD"], [0.30, 0.28, 0.14, 0.18, 0.10]),
    "SEMI": (["TORR", "KJOL", "FRYS", "DRIKKE", "NONFOOD"], [0.32, 0.22, 0.14, 0.24, 0.08]),
    "MODUL": (["TORR", "KJOL", "FRYS", "DRIKKE", "NONFOOD"], [0.36, 0.18, 0.12, 0.28, 0.06]),
}
# Attraksjon per fylke: SSB 09830, transportmengde 2024 "fra fylke" i 1 000 tonn, avrundet
ATTRAKSJON = {"03": 28.5, "11": 23.5, "15": 10.1, "18": 8.4, "31": 13.7, "32": 27.8, "33": 13.6,
              "34": 28.2, "39": 10.5, "40": 8.4, "42": 16.8, "46": 25.5, "50": 29.1, "55": 5.7, "56": 5.1}


def les_seed(navn):
    with open(SEEDS / f"{navn}.csv", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def haversine(a, b):
    r = 6371.0
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dp, dl = math.radians(b[0] - a[0]), math.radians(b[1] - a[1])
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def avstandsmatrise(fylker):
    koder = [f["fylke_kode"] for f in fylker if f["fylke_kode"] != "99"]
    pos = {f["fylke_kode"]: (float(f["breddegrad"]), float(f["lengdegrad"])) for f in fylker if f["fylke_kode"] != "99"}
    m = {}
    for a in koder:
        for b in koder:
            if a == b:
                m[(a, b)] = 0.0
            else:
                m[(a, b)] = round(haversine(pos[a], pos[b]) * 1.38, 0)   # veifaktor for norsk geografi
    return koder, m


def bygg_flaate(rng, lagre, grupper):
    """300 kjøretøy fordelt på seks lagre. Gruppeandel avhenger av lagerets rolle."""
    andel = {"L1": (0.35, 0.40, 0.25), "L2": (0.50, 0.40, 0.10), "L3": (0.55, 0.35, 0.10),
             "L4": (0.55, 0.35, 0.10), "L5": (0.40, 0.40, 0.20), "L6": (0.45, 0.40, 0.15)}
    ny = {g["kjoretoygruppe_kode"]: float(g["nyttelast_tonn"]) for g in grupper}
    rader, n = [], 1
    for lag in lagre:
        k = int(lag["antall_kjoretoy"])
        gr = rng.choice(["DIST", "SEMI", "MODUL"], size=k, p=andel[lag["lager_id"]])
        for g in gr:
            # kjøretøy tatt i bruk i løpet av 2021-2024, jevnt
            i_drift = date(2021, 1, 1) + timedelta(days=int(rng.integers(0, 1400)))
            rader.append({
                "kjoretoy_id": f"NV{n:04d}",
                "kjoretoygruppe_kode": g,
                "nyttelast_tonn": ny[g],
                "lager_id": lag["lager_id"],
                "hjemfylke_kode": lag["fylke_kode"],
                "i_drift_fra": i_drift.isoformat(),
            })
            n += 1
    return rader


def maaneder(til):
    y, m = FRA_MAANED
    ut = []
    while (y, m) <= til:
        ut.append((y, m))
        m += 1
        if m == 13:
            y, m = y + 1, 1
    return ut


def generer_maaned(rng, y, m, flaate, koder, avst, retur_p, varegr):
    forste = date(y, m, 1)
    siste = (date(y + (m == 12), (m % 12) + 1, 1) - timedelta(days=1))
    dager = [forste + timedelta(d) for d in range((siste - forste).days + 1)]
    hverdager = [d for d in dager if d.weekday() < 5]
    kv = (m - 1) // 3 + 1

    ut = []
    tur_nr = 0
    for kj in flaate:
        if date.fromisoformat(kj["i_drift_fra"]) > siste:
            continue
        g = kj["kjoretoygruppe_kode"]
        hjem = kj["hjemfylke_kode"]
        ny = float(kj["nyttelast_tonn"])
        lam = TURER_PER_DAG[g] * SESONG[m]
        ant = rng.poisson(lam, size=len(hverdager))
        # mandag +10 %, fredag -10 %
        ant = np.where(np.array([d.weekday() for d in hverdager]) == 0, np.round(ant * 1.1), ant)
        tot = int(ant.sum())
        if tot == 0:
            continue
        dag_idx = np.repeat(np.arange(len(hverdager)), ant.astype(int))
        # destinasjon: attraksjon * avstandsdempning
        vekt = np.array([ATTRAKSJON[k] * math.exp(-avst[(hjem, k)] / AVSTANDSSKALA[g]) for k in koder])
        if g == "DIST":
            vekt = vekt * np.array([1.0 if avst[(hjem, k)] < 260 else 0.0 for k in koder])
        vekt = vekt / vekt.sum()
        dest = rng.choice(len(koder), size=tot, p=vekt)
        dest_kode = np.array(koder)[dest]
        km_grunn = np.array([avst[(hjem, k)] for k in dest_kode])
        # intern kjøring innen fylke: 25-140 km; ellers grunnavstand +- 12 %
        intern = km_grunn == 0
        km = np.where(intern, rng.uniform(25, 140, size=tot), km_grunn * rng.uniform(0.88, 1.12, size=tot))
        km = np.round(km, 0)

        # utgående last
        vg_koder, vg_p = UTGAAENDE_VAREGRUPPER[g]
        vg = rng.choice(vg_koder, size=tot, p=vg_p)
        typ = np.array([varegr[v] for v in vg])
        utn = np.clip(rng.normal(typ, 0.10), 0.08, 1.0)
        tonn_ut = np.round(ny * utn, 2)

        # retur
        p_last = np.array([retur_p[k] for k in dest_kode]) - TOM_KVARTAL[kv]
        if g == "DIST":
            p_last = np.where(intern, 0.42, p_last * 0.7)      # distribusjon: retur = emballasje
        lastet_retur = rng.random(tot) < p_last
        if g == "DIST":
            retur_vg = np.full(tot, "RETUR")
        else:
            retur_vg = rng.choice(["TORR", "DRIKKE", "NONFOOD", "RETUR"], size=tot, p=[0.30, 0.25, 0.15, 0.30])
        typ_r = np.array([varegr[v] for v in retur_vg])
        utn_r = np.clip(rng.normal(typ_r, 0.10), 0.05, 1.0)
        tonn_retur = np.where(lastet_retur, np.round(ny * utn_r, 2), 0.0)
        km_retur = np.round(km * rng.uniform(0.97, 1.03, size=tot), 0)

        # feil A: overlast 0,3 % av lastede etapper
        over = rng.random(tot) < 0.003
        tonn_ut = np.where(over, np.round(ny * rng.uniform(1.02, 1.15, size=tot), 2), tonn_ut)
        # feil B: ukjent avlessingsfylke 1,5 %
        ukjent = rng.random(tot) < 0.015
        til_ut = np.where(ukjent, "99", dest_kode)
        # feil D: etterregistrering
        lag = np.where(rng.random(tot) < 0.12, rng.integers(1, 26, size=tot), rng.integers(0, 3, size=tot))

        for i in range(tot):
            d = hverdager[dag_idx[i]]
            tur_nr += 1
            tur_id = f"{y}{m:02d}-{kj['kjoretoy_id']}-{tur_nr:05d}"
            reg = d + timedelta(days=int(lag[i]))
            ut.append((f"{tur_id}-1", tur_id, kj["kjoretoy_id"], d, 1, hjem, str(til_ut[i]), str(vg[i]),
                       float(km[i]), float(tonn_ut[i]), reg))
            ut.append((f"{tur_id}-2", tur_id, kj["kjoretoy_id"], d, 2, str(dest_kode[i]), hjem,
                       str(retur_vg[i]) if lastet_retur[i] else None,
                       float(km_retur[i]), float(tonn_retur[i]), reg))
    return ut


def til_tabell(rader):
    kol = list(zip(*rader))
    return pa.table({
        "etappe_id": pa.array(kol[0], pa.string()),
        "tur_id": pa.array(kol[1], pa.string()),
        "kjoretoy_id": pa.array(kol[2], pa.string()),
        "dato": pa.array(kol[3], pa.date32()),
        "sekvens": pa.array(kol[4], pa.int8()),
        "fra_fylke_kode": pa.array(kol[5], pa.string()),
        "til_fylke_kode": pa.array(kol[6], pa.string()),
        "varegruppe_kode": pa.array(kol[7], pa.string()),
        "km": pa.array(kol[8], pa.float64()),
        "tonn": pa.array(kol[9], pa.float64()),
        "registrert_dato": pa.array(kol[10], pa.date32()),
    })


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--til", default="2026-06", help="siste måned som skal være synlig, YYYY-MM")
    a = p.parse_args()
    til_y, til_m = map(int, a.til.split("-"))
    asof = date(til_y + (til_m == 12), (til_m % 12) + 1, 1) - timedelta(days=1)

    fylker = les_seed("fylke")
    lagre = les_seed("lager")
    grupper = les_seed("kjoretoygruppe")
    retur_p = {r["fylke_kode"]: float(r["sannsynlighet_returlast"]) for r in les_seed("ssb_kalibrering_retur")}
    varegr = {r["varegruppe_kode"]: float(r["typisk_utnyttelse"]) for r in les_seed("varegruppe")}
    koder, avst = avstandsmatrise(fylker)

    TURER.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(FRO)
    flaate = bygg_flaate(rng, lagre, grupper)
    with open(RAW / "kjoretoy.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(flaate[0].keys()))
        w.writeheader()
        w.writerows(flaate)

    manifest_sti = TURER / "manifest.json"
    manifest = json.loads(manifest_sti.read_text()) if manifest_sti.exists() else {}
    # Én uavhengig generator per måned -> en måned endres ikke av at neste legges til.
    endret, uendret, total = [], [], 0
    for (y, m) in maaneder((til_y, til_m)):
        rng_m = np.random.default_rng(FRO + y * 100 + m)
        rader = generer_maaned(rng_m, y, m, flaate, koder, avst, retur_p, varegr)
        # feil C: 0,2 % duplikater
        dup_idx = rng_m.random(len(rader)) < 0.002
        rader = rader + [r for r, d in zip(rader, dup_idx) if d]
        # feil D: bare det som er registrert per asof er synlig
        synlig = [r for r in rader if r[10] <= asof]
        tab = til_tabell(synlig)
        sti = TURER / f"turer_{y}-{m:02d}.parquet"
        buf = pa.BufferOutputStream()
        pq.write_table(tab, buf, compression="zstd")
        data = buf.getvalue().to_pybytes()
        sha = hashlib.sha256(data).hexdigest()
        nokkel = f"{y}-{m:02d}"
        if manifest.get(nokkel, {}).get("sha256") == sha and sti.exists():
            uendret.append(nokkel)
        else:
            sti.write_bytes(data)
            manifest[nokkel] = {"fil": sti.name, "rader": len(synlig), "skjult_etterregistrert": len(rader) - len(synlig), "sha256": sha}
            endret.append(nokkel)
        total += len(synlig)
    # måneder etter --til fjernes, så tilstanden alltid er entydig
    fjernet = []
    for nokkel in list(manifest):
        if nokkel > f"{til_y}-{til_m:02d}":
            (TURER / manifest[nokkel]["fil"]).unlink(missing_ok=True)
            del manifest[nokkel]
            fjernet.append(nokkel)
    manifest_sti.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    if fjernet:
        print(f"Fjernet (etter --til): {', '.join(fjernet)}")
    print(f"Per {asof}: {total} synlige etapper i {len(endret) + len(uendret)} månedsfiler.")
    print(f"Skrevet/endret: {', '.join(endret) if endret else 'ingen'}")
    print(f"Uendret (hoppet over): {len(uendret)}")


if __name__ == "__main__":
    main()
