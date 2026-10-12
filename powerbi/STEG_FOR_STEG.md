# Power BI – byggelogg

Denne filen trengs ikke for å bruke prosjektet; det står i `START_HER.md`.
Den er en logg over hvordan den semantiske modellen og rapporten ble bygd,
hvor jeg gikk bort fra planen og hva som ikke virket på første forsøk.

---

## 1. Filene

| Mappe | Innhold |
|---|---|
| `Nordvare_Kapasitetstap.pbip` | Det som åpnes i Desktop. Peker på rapporten |
| `Nordvare_Kapasitetstap.SemanticModel/definition/` | Modellen som TMDL: én fil per tabell, `relationships.tmdl`, `expressions.tmdl` (parametere og `fnLesCsv`) og `cultures/nb-NO.tmdl` |
| `Nordvare_Kapasitetstap.Report/definition/` | Rapporten som PBIR: én mappe per side og én `visual.json` per visual, 125 i alt |
| `Nordvare_Kapasitetstap.Report/StaticResources/` | Temaet `Nordlys`, seks bakgrunnsbilder og kartbildet |

`.pbi/localSettings.json` og `.pbi/cache.abf` (dataene) er utelatt fra git.
Navnet ble `Nordvare_Kapasitetstap`, ikke `Nordvare_Kapasitet` som i planen.

---

## 2. Parametere

| Navn | Type | Verdi | Hva den gjør |
|---|---|---|---|
| `MartMappe` | Text | `C:\prosjekt\gods-kapasitet\data\mart\` | Rot for alle kilder |
| `RangeStart` | Date/Time | `01.01.2023 00:00:00` | Første måned som lastes i `fact_etappe` |
| `RangeEnd` | Date/Time | `01.01.2027 00:00:00` | Første måned som *ikke* lastes |

`RangeStart` og `RangeEnd` må hete nøyaktig det og være Date/Time, ellers
dukker ikke *Incremental refresh* opp på tabellen.

---

## 3. Spørringer

### CSV-tabellene

`fnLesCsv(Filnavn)` leser én CSV fra `MartMappe` (UTF-8, komma som
skilletegn) og bruker første rad som overskrifter. Hver tabell velger
kolonnene den trenger og setter typene med kulturen `"en-US"`, fordi CSV-ene
har punktum som desimaltegn. Modellen har i tillegg `sourceQueryCulture: en-US`.

### `fact_etappe` velger filer, ikke rader

```
let
    Kolonner = {"dato", "partisjon", "kjoretoy_id", "kjoretoygruppe_kode", "lager_id",
                "etappetype", "fra_fylke_kode", "varegruppe_kode", "km", "tonnkm",
                "kapasitet_tonnkm", "laststatus", "registrering", "dager_etter_maanedsslutt"},
    Kilde = Folder.Files(MartMappe & "fact_etappe"),
    IVinduet = Table.SelectRows(Kilde, each Text.EndsWith([Name], ".parquet") and (
        let Maaned = Date.FromText(Text.Middle([Name], 12, 7) & "-01")
        in Maaned >= Date.From(RangeStart) and Maaned < Date.From(RangeEnd))),
    Lest = List.Transform(IVinduet[Content], each Table.SelectColumns(Parquet.Document(_), Kolonner)),
    Samlet = if List.IsEmpty(Lest) then #table(Kolonner, {}) else Table.Combine(Lest),
    Typer = Table.TransformColumnTypes(Samlet, {{"dato", type date}, {"km", Currency.Type},
                {"tonnkm", Currency.Type}, {"kapasitet_tonnkm", Currency.Type},
                {"dager_etter_maanedsslutt", Int64.Type}})
in
    Typer
```

- `Text.Middle([Name], 12, 7)` henter `2026-06` fra `fact_etappe_2026-06.parquet`.
  Filnavnet er partisjonsnøkkelen.
- **Filteret står på filnavnet, ikke på `dato`.** Mappekilden og parquet
  støtter ikke query folding. Et filter på `dato` etter `Table.Combine` ville
  lest alle 42 filer og kastet resten. Filteret på navnet fjerner filene
  *før* de leses. Hver fil er én måned, og partisjonene i tjenesten starter
  alltid på en månedsgrense, så ingen rader må filtreres etterpå.
- **Bare 14 kolonner leses.** Parquet er kolonnebasert, og Power Query hopper
  over kolonner som ikke velges. Ifølge Chris Webb (2021, se kilder) er det den
  eneste optimaliseringen Power Query har for parquet; filtre presses ikke ned
  i filen.
- Et vindu uten filer gir en tom tabell med de samme kolonnene i stedet for en
  feil. Det kan skje i tjenesten når en partisjon dekker måneder uten data.
- Km og tonnkm er *fast desimaltall* (`Currency.Type`): fire desimaler holder,
  og kolonnene komprimeres bedre enn flyttall.

**Det som ikke virket først:** første versjon regnet laststatus, registrering
og dager etter månedsslutt i Power Query, rad for rad over 687 666 rader.
Oppdateringen av `fact_etappe` i Desktop tok da flere minutter. Kolonnene lages
nå i dbt (`models/marts/fact_etappe.sql`), og spørringen gjør bare filvalg,
kolonnevalg og typer.

---

## 4. Incremental refresh på `fact_etappe`

Politikken står i `fact_etappe.tmdl` og tilsvarer disse valgene i dialogen
**Incremental refresh** (høyreklikk tabellen i Desktop):

1. **Incrementally refresh this table**: på
2. **Archive data starting**: `3 Years` before refresh date
3. **Incrementally refresh data starting**: `2 Months` before refresh date
4. *Only refresh complete months*: av. Inneværende måned skal med.
5. *Detect data changes*: av. Krever en datetime-kolonne for «sist endret»
   som kan foldes, og den finnes ikke.

Resultatet i `fact_etappe.tmdl`:

```
refreshPolicy
    policyType: basic
    rollingWindowGranularity: year
    rollingWindowPeriods: 3
    incrementalGranularity: month
    incrementalPeriods: 2
    sourceExpression = ...
```

To måneder speiler `reload_maaneder: 1` i dbt: siste måned og den før. Det
holder fordi etterregistreringene kommer innen 25 dager; målet
`Lengste etterregistrering` på siden Etapper viser det.

Desktop har én partisjon og laster alt innenfor `RangeStart`/`RangeEnd`.
Partisjonene (år for arkivet, måned for de to siste) lages først ved første
oppdatering etter publisering til tjenesten. Det er ikke testet, se
`GJENSTAR.md` punkt 1.

---

## 5. Modell

### Tabeller

| Tabell | Rader | Rolle |
|---|---|---|
| `dim_dato` | 11 323 | Én rad per dag 1996–2026, merket som datotabell |
| `dim_fylke` | 16 | 15 fylker (2024) og «Ukjent», landsdel og kartkoordinater |
| `dim_varegruppe` | 7 | Seks varegrupper og «Tomkjøring», vekt- eller volumbegrenset |
| `dim_kjoretoygruppe` | 3 | Distribusjonsbil, semitrailer, modulvogntog |
| `dim_lager` | 6 | Lagrene fra Vestby til Tromsø |
| `fact_kapasitet_maaned` | 56 255 | Aggregatet. Alt unntatt siden Etapper og kontrolltallene |
| `fact_etappe` | 687 666 | Detalj, inkrementell. Etapper og kontrolltall |
| `fact_ssb_transportytelser` | 372 | SSB 03650, kvartal |
| `fact_ssb_transportytelser_aar` | 120 | SSB 08478, år fra 1996 |
| `fact_ssb_fylkesstrom` | 4 146 | SSB 09830, fra × til fylke per år |
| `_Mål` | – | 44 mål i visningsmapper |
| `Tidsvindu` | – | Beregningsgruppe |
| `Vis etter` | – | Feltparameter |

**Avvik fra planen:**

- **Ingen `dim_maaned`.** `fact_kapasitet_maaned` kobles rett på
  `dim_dato[Dato]` med månedsstarten, som alltid er en dag som finnes i
  datotabellen. SSB-tabellene kobles likt på kvartals- og årsstart. Ett
  årsvalg filtrerer dermed Nordvare og SSB likt, uten toveisrelasjoner.
- **Ingen `dim_kjoretoy` i modellen.** Kjøretøygruppe og lager er egne små
  dimensjoner. Bilnivået trengs bare til å telle biler i drift, og det gjøres
  på `fact_etappe[kjoretoy_id]`.
- **SSB 06988 og 13321 er ikke lastet.** De ligger i martene, men ingen side
  bruker dem ennå.

### Relasjoner

Alle er én-til-mange med filter én vei.

| Fra (mange) | Til (én) | Aktiv |
|---|---|---|
| `fact_kapasitet_maaned[maaned_start]` | `dim_dato[Dato]` | ja |
| `fact_kapasitet_maaned[fra_fylke_kode]` | `dim_fylke[fylke_kode]` | ja |
| `fact_kapasitet_maaned[til_fylke_kode]` | `dim_fylke[fylke_kode]` | nei |
| `fact_kapasitet_maaned[kjoretoygruppe_kode]` | `dim_kjoretoygruppe` | ja |
| `fact_kapasitet_maaned[lager_id]` | `dim_lager` | ja |
| `fact_kapasitet_maaned[varegruppe_kode]` | `dim_varegruppe` | ja |
| `fact_etappe[dato]` | `dim_dato[Dato]` | ja |
| `fact_etappe[fra_fylke_kode]` | `dim_fylke[fylke_kode]` | ja |
| `fact_etappe[kjoretoygruppe_kode]` | `dim_kjoretoygruppe` | ja |
| `fact_etappe[lager_id]` | `dim_lager` | ja |
| `fact_etappe[varegruppe_kode]` | `dim_varegruppe` | ja |
| `fact_ssb_transportytelser[kvartal_start]` | `dim_dato[Dato]` | ja |
| `fact_ssb_transportytelser_aar[aar_start]` | `dim_dato[Dato]` | ja |
| `fact_ssb_fylkesstrom[aar_start]` | `dim_dato[Dato]` | ja |
| `fact_ssb_fylkesstrom[fra_fylke_kode]` | `dim_fylke[fylke_kode]` | ja |
| `fact_ssb_fylkesstrom[til_fylke_kode]` | `dim_fylke[fylke_kode]` | nei |

Én `dim_fylke` brukes for både fra og til. Til-siden brukes med
`USERELATIONSHIP` i målene som trenger den (`Kjøretøykm inn`,
`SSB godsmengde inn`).

### Mål

Alle 44 mål ligger i `_Mål` med en beskrivelse som vises i Desktop. Andeler er
alltid forhold mellom summer:

```
Tomkjøring % = DIVIDE ( SUM ( fact_kapasitet_maaned[km_tom] ), SUM ( fact_kapasitet_maaned[km] ) )
```

SSBs tomkjøring regnes på samme måte fra SSBs egne km, ikke som et snitt av
prosentene SSB publiserer. Utvalget utvides til hele kvartaler, fordi SSB
publiserer per kvartal:

```
SSB tomkjøring % =
VAR _Kvartaler = VALUES ( dim_dato[Kvartal id] )
VAR _Km =
    CALCULATE ( SUM ( fact_ssb_transportytelser[kjoretoykm_mill] ),
        REMOVEFILTERS ( dim_dato ), _Kvartaler,
        fact_ssb_transportytelser[transporttype_kode] = "01" )
VAR _KmMedLast = ...samme med kjoretoykm_med_last_mill...
RETURN DIVIDE ( _Km - _KmMedLast, _Km )
```

`Tomkjøring inkl. emballasje %` legger kilometerne med varegruppe RETUR til
de tomme. `Sesongindeks` deler transportarbeidet i måneden på snittmåneden
samme år og gir tomt for år som ikke er hele (2026).

### Beregningsgruppen `Tidsvindu`

Tre elementer: `Valgt periode`, `Året før` og `Endring mot året før`.

```
Året før =
VAR _Datoer = CALCULATETABLE ( VALUES ( dim_dato[Dato] ), dim_dato[Har data] = TRUE () )
RETURN CALCULATE ( SELECTEDMEASURE (), DATEADD ( _Datoer, -1, YEAR ) )
```

- **Bare dager med data forskyves.** Med 2026 valgt er det januar–juni, så
  året før blir januar–juni 2025, ikke hele 2025. `dim_dato` er merket som
  datotabell, så `DATEADD` erstatter årsfilteret i stedet for å snevre det inn.
- **Andeler gir prosentpoeng, alt annet relativ endring.** Andel kjennes på
  `%` i målnavnet med `SELECTEDMEASURENAME()`. Formatet velges av
  `formatStringDefinition` på samme måte.
- **Avrundet slik det vises.** Endringen avrundes til én desimal før
  formatet velger pil. Ellers ble −0,04 pp vist som «▼ 0,0 pp» i stedet for
  «= 0,0 pp».

Målene `Kjøretøykm endring`, `Tomkjøring endring` osv. er
`CALCULATE ( [mål], Tidsvindu[Tidsvindu] = "Endring mot året før" )` med egen
formatstreng (`▲ 10.9% mot året før` i en engelsk Desktop). Kortene på
Oversikt bruker dem.

### Feltparameteren `Vis etter`

Fem felt (landsdel, fylke, kjøretøygruppe, lager, varegruppe) laget med
`NAMEOF`. Knapperaden på Hvor tapes det er en slicer på parameteren, og
stolpediagrammet under bruker den på aksen.

### Kultur

`culture: nb-NO` er modellens språk. Desktop formaterer likevel tall etter
sine egne regionale innstillinger, så en engelsk Desktop viser punktum som
desimaltegn. Målet `Tidsrom` gir derfor kulturen eksplisitt:
`FORMAT ( _Fra, "mmm yyyy", "nb-NO" )`.

---

## 6. Rapporten

- **Seks sider i 1920 × 1080** med *Fit to page*. Rekkefølge: Oversikt, Hvor
  tapes det, Godsstrømmer, Sesong, Etapper, Metode.
- **Tema `Nordlys`** (egen JSON på grunnlaget Fluent 2): mørk bakgrunn med
  turkis, indigo, rosa, gull og blått. Fraktet gods er turkis, tapt delvis
  indigo og tapt tom rosa på alle sider. Gull og blått skiller vekt- og
  volumbegrenset gods. På kortene er endringen turkis når den går riktig vei,
  og rosa når den går feil vei.
- **Bakgrunnsbilder per side.** Paneler, sidemeny, ikoner og overskriftsfelt
  er tegnet inn i ett bilde per side (`bg-*.png`), og visualene ligger oppå
  med gjennomsiktig bakgrunn. Det gir et jevnt uttrykk uten mange
  formfigurer. Ulempen: flyttes et visual, må bakgrunnsbildet lages på nytt.
- **Sidemenyen** er seks knapper med sidenavigasjon lagt over ikonene i
  bakgrunnsbildet.
- **Årsvelgeren** er synkronisert mellom Oversikt, Hvor tapes det og
  Godsstrømmer.
- **Bildene i README** kommer fra **File → Export → Export to PDF** i Desktop
  (`docs/rapport.pdf`). Hver side er gjort om til PNG med `pdftoppm`, og den
  hvite margen er skåret bort. Skjermbilder ble ikke brukt, fordi de ble bleke
  på en HDR-skjerm. Bakgrunnsbildene er satt som sidebakgrunn og ikke som
  *wallpaper*, ellers hadde de manglet i PDF-en.

### Kartet på Godsstrømmer

Kartet er et punktdiagram, ikke et kartvisual. X er lengdegraden til
ankerbyen i hvert fylke, Y er Mercator-y for breddegraden (`kart_x` og
`kart_y` i `dim_fylke`). Bakgrunnen i plottområdet er `kart-norge.png`, tegnet
i samme projeksjon. Det som får boblene til å treffe byene:

1. Aksene har faste grenser som er de samme som kartbildet ble tegnet med
   (lengdegrad 2,6–33,1, breddegrad 57,55–71,6).
2. Bildet er tegnet for plottområdets størrelse (736 × 796 piksler) og
   skaleres med *Fit*. Med et annet sideforhold får bildet kanter, og boblene
   havner ved siden av byene.

Fordelen er at kartet virker uten karttjeneste og følger temaet. Bobler i
full størrelse dekket lagerringene og bynavnene i kartbildet; boblestørrelse
−22 (i Format-ruten under *Markers*) passet. Skalaen er ikke lineær: −10 var
for stort, −30 for lite.

---

## 7. Det som ikke virket på første forsøk

1. **Treg parquet-lesing i Power Query.** Se avsnitt 3: kolonner som ble
   regnet rad for rad, er flyttet til dbt.
2. **Beregningsgruppen feilet.** Kolonnen i en beregningsgruppe må ha
   `sourceColumn: Name` og sorteringskolonnen `sourceColumn: Ordinal`, uansett
   hva kolonnene heter i modellen.
3. **`SELECTEDMEASUREFORMATSTRING()` i selve verdien.** Inne i et
   beregningselement returnerer den formatet elementet allerede har gitt, ikke
   målets eget. Prosentpoeng og prosent ble byttet om. Løst med
   `SELECTEDMEASURENAME()`.
4. **«▼ 0,0 pp».** Se avrundingen under Tidsvindu.
5. **Kort som klippet tallet.** Polstringen på kortenes beholder
   (`visualContainerObjects.padding`) ble ignorert når den hadde
   `"selector": {"id": "default"}`, og temaets polstring klippet verdien. Uten
   selector virker den.
6. **Endringer i TMDL kom ikke med via *Apply external changes*.** Desktop
   oppdaget endrede filer og tilbød å laste dem inn. Rapportendringer kom med,
   men i denne byggingen gjorde ikke endringene i modellen det. Det som virket:
   lukke Desktop, åpne `.pbip` på nytt og kjøre **Refresh**.

---

## Kilder

- Microsoft Learn: [Configure incremental refresh and real-time data for Power BI semantic models](https://learn.microsoft.com/power-bi/connect-data/incremental-refresh-overview)
- Microsoft Learn: [Power BI Desktop project semantic model folder](https://learn.microsoft.com/power-bi/developer/projects/projects-dataset) (TMDL)
- Microsoft Learn: [Power BI Desktop project report folder](https://learn.microsoft.com/power-bi/developer/projects/projects-report) (PBIR)
- Microsoft Learn: [Calculation groups in Analysis Services tabular models](https://learn.microsoft.com/analysis-services/tabular-models/calculation-groups)
- Microsoft Learn: [Use field parameters in Power BI reports](https://learn.microsoft.com/power-bi/create-reports/power-bi-field-parameters)
- Microsoft Learn: [Export Power BI reports to PDF](https://learn.microsoft.com/power-bi/collaborate-share/end-user-pdf)
- Chris Webb: [Parquet File Performance In Power BI/Power Query](https://blog.crossjoin.co.uk/2021/03/21/parquet-file-performance-in-power-bi-power-query/) (2021)
