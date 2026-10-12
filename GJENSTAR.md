# Gjenstår

Kjente svakheter og uferdige deler. Løste punkter strykes, ikke slettes.

## Uferdig

- ~~**Power BI-rapporten er ikke bygd.** `powerbi/STEG_FOR_STEG.md` er en plan,
  ikke en logg.~~ Bygd: `powerbi/Nordvare_Kapasitetstap.pbip`, seks sider.
  `STEG_FOR_STEG.md` er nå byggeloggen.
- **SSB 06988 og 13321 er ikke med i Power BI-modellen.** De hentes, testes og
  eksporteres (`fact_ssb_vareslag`, `fact_ssb_avstand`), men ingen side bruker
  dem ennå. Naturlig plass: Hvor tapes det (vareslag) og en ny side om
  transportlengde (avstandsklasser).

## Kjente svakheter i modellen

1. **Incremental refresh-politikken kan ikke verifiseres uten Power BI-tjenesten.**
   Desktop lagrer politikken i TMDL (`refreshPolicy`), men lager ikke
   partisjoner. Det som *kan* vises lokalt: at spørringen leser bare filene
   innenfor `RangeStart`/`RangeEnd` og at politikken er definert. Det som ikke
   kan vises: partisjonsliste og faktisk delvis oppfriskning. Krever Pro/PPU
   eller Fabric-kapasitet og XMLA-endepunkt.

2. **Ingen volumdimensjon.** Utnyttelsesgrad er tonn mot nyttelast. Kjøl,
   frys og non-food er volumbegrenset, og modellen kan ikke skille «ledig
   plass» fra «full bil med lett gods». Riktig fiks er en kolonne for paller
   eller lastemeter per etappe; det finnes ikke i SSB og er ikke generert.

3. **Returlast-sannsynlighet per fylke er antatt, ikke estimert.**
   `seeds/ssb_kalibrering_retur.csv` er begrunnet, men tallene er valgt slik at
   tomkjøringen samlet treffer SSB. SSB publiserer ikke tomkjøring per fylke,
   så fylkesfordelingen av tap er en hypotese.

4. **Andeler for oppløste fylker (2024) bygger på ett år og ett mål.**
   Se README, forbehold 6.

5. **Reload-vindu er fast (1 måned).** I drift bør vinduet styres av faktisk
   etterregistreringslag: hvis 95-persentilen er 25 dager, holder én måned;
   hvis den er 40, må det være to. Målet finnes nå i modellen
   (`Lengste etterregistrering`, 25 dager), men vinduet settes ikke fra det.

6. **Ingen SCD på kjøretøy.** Nyttelast og lager er faste per bil. En bil som
   flyttes mellom lagre midt i perioden ville fått feil hjemfylke bakover.

7. **Sesongindeksen trekker ikke fra vekst.** Den deler hver måned på
   snittmåneden samme år. Flåten fases inn fra 149 biler i januar 2023 til 300
   i oktober 2024, så i 2023 og 2024 blir slutten av året for høy og starten
   for lav. 2025 er det første rene året. Riktigere: dele på et sentrert glidende snitt
   over 12 måneder, eller på transportarbeid per bil i drift.

8. **«Mot året før» måler mest innfasingen av biler** for 2024 og 2025.
   Et mål per bil i drift (km eller tapt kapasitet per kjøretøy) ville skilt
   vekst fra endring i driften.
