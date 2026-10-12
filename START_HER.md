# Start her

## Krav

- Python 3.11+ med `pip install -r requirements.txt`
- Power BI Desktop fra 2026. Prosjektet er lagret som PBIP med TMDL og PBIR.
  I eldre versjoner må preview-innstillingene for PBIP, TMDL og PBIR være slått
  på under **File → Options and settings → Options → Preview features**.
- Prosjektet forventes å ligge i `C:\prosjekt\gods-kapasitet\`

## Kjøre pipelinen

Tre bat-filer, kjøres fra prosjektmappen i rekkefølge.

| Fil | Gjør | Tid |
|---|---|---|
| `1_HENT.bat` | Henter fem SSB-tabeller til `data/raw/ssb/` | ~20 s |
| `2_BYGG.bat` | Genererer Nordvare (42 måneder), `dbt seed`, `dbt run --full-refresh`, `dbt test`, eksport til `data/mart/` | ~2 min |
| `3_NY_MAANED.bat [YYYY-MM]` | Simulerer at en ny måned har kommet (standard `2026-07`), kjører dbt *inkrementelt*, eksporterer bare endrede partisjoner | ~30 s |

Forventet sluttlinje fra `dbt test` i `2_BYGG.bat`:

```
Done. PASS=62 WARN=1 ERROR=0 SKIP=0 NO-OP=0 REUSED=0 TOTAL=63
```

Den ene advarselen er `assert_ingen_overlast` (1 053 rader) og er ønsket.
Alt annet enn `WARN=1 ERROR=0` betyr at noe er galt. Med dbt 1.10 eller nyere
kommer det i tillegg en oppsummering av utgåtte skrivemåter (deprecations).
Den påvirker ikke resultatet.

`3_NY_MAANED.bat` skal skrive ut noe slikt:

```
Skrevet/endret: 2026-06, 2026-07
Uendret (hoppet over): 41
...
2 of 3 OK created sql incremental model marts.fact_etappe ... [OK in 1.6s]
...
fact_etappe: 43 partisjoner, skrevet 2, uendret 41
```

To partisjoner skrives: den nye måneden og måneden før (etterregistreringer).
Kjør `2_BYGG.bat` igjen for å gå tilbake til utgangspunktet.

`data/raw/ssb/` ligger i repoet slik at kontrolltallene kan reproduseres uten
nett. `1_HENT.bat` overskriver dem med ferske tall; da kan tall i README avvike
fra det du ser, og `assert_tomkjoring_mot_ssb` kan i teorien slå ut dersom
SSB reviderer tomkjøringen med mer enn 3,5 pp.

## Åpne i Power BI

Rapporten leser `data/mart/`, som ligger i repoet. `2_BYGG.bat` lager den på
nytt.

1. Åpne `powerbi\Nordvare_Kapasitetstap.pbip`
2. Ligger prosjektet et annet sted enn `C:\prosjekt\gods-kapasitet\`:
   **Home → Transform data → Edit parameters** og sett `MartMappe` til full
   sti med `\` på slutten, for eksempel `D:\kode\gods-kapasitet\data\mart\`
3. **Home → Refresh**

`RangeStart` (01.01.2023) og `RangeEnd` (01.01.2027) er satt slik at Desktop
laster alle månedene. *Auto date/time* er slått av i filen; modellen har egen
`dim_dato`.

Etter `3_NY_MAANED.bat`: **Home → Refresh**. Siden Etapper viser da 43
partisjoner og data til og med 31.07.2026, og 2026-06 og 2026-07 er farget som
månedene som lastes på nytt. Kjør `2_BYGG.bat` og **Refresh** igjen for å gå
tilbake.

## Mappestruktur etter bygging

```
data/
  raw/ssb/                  SSB CSV + manifest.json
  raw/turer/                turer_YYYY-MM.parquet + manifest.json
  raw/kjoretoy.csv
  gods_kapasitet.duckdb     dbt-database (ikke i git)
  mart/                     CSV per dim/fakta + fact_etappe/fact_etappe_YYYY-MM.parquet + manifest.json
powerbi/
  Nordvare_Kapasitetstap.pbip
  Nordvare_Kapasitetstap.SemanticModel/
  Nordvare_Kapasitetstap.Report/
```
