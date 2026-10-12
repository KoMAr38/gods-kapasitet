# gods-kapasitet – hvor går kapasiteten tapt i en distribusjonsflåte?

Portefølje, prosjekt 7. Godstransport med lastebil: tomkjøring, utnyttelsesgrad,
transportarbeid og sesong for den fiktive distributøren **Nordvare AS**, målt
mot SSBs lastebilundersøkelse. Pipelinen er bygd for inkrementell oppdatering
med månedspartisjoner, fordi det er det eneste stedet i porteføljen der et
transaksjonsdatasett med datoer gjør det meningsfullt.

Stack: Python (uttrekk og syntetiske data) → dbt + DuckDB → parquet-partisjoner
→ Power BI (`.pbip` med TMDL og PBIR).

---

## Rapporten

`powerbi/Nordvare_Kapasitetstap.pbip`. Seks sider i 1920 × 1080 med mørkt
tema, egne bakgrunnsbilder og sidemeny til venstre. Årsvelgeren er felles for
Oversikt, Hvor tapes det og Godsstrømmer.

| Side | Viser |
|---|---|
| Oversikt | Fem nøkkeltall med endring mot de samme månedene året før (tomkjøringen mot SSB), kapasitet brukt og tapt per måned, tapet på utgående og retur, tomkjøring per måned mot SSB og tapet per kjøretøygruppe |
| Hvor tapes det | Tapt kapasitet etter landsdel, fylke, kjøretøygruppe, lager eller varegruppe (feltparameter), vektutnyttelse per varegruppe, tomkjøring med og uten emballasjereturer og lagrene mot året før |
| Godsstrømmer | Kart med tomkjøring på returen per fylke, SSBs største strømmer mellom fylker og tomkjøring på returen per landsdel |
| Sesong | Sesongindeks for transportarbeid, tomkjøring per kvartal mot SSB, måned for måned i et varmekart og SSBs serie fra 1996 |
| Etapper | Den inkrementelle tabellen: partisjonene, hvilke måneder som lastes på nytt og hvor sent etterregistreringene kommer |
| Metode | Begreper, forbehold, kilder og kontrolltall som regnes i modellen |

Byggeloggen for modellen og rapporten, med det som ikke virket på første
forsøk: `powerbi/STEG_FOR_STEG.md`.

---

## Funn

Tallene gjelder 2025 der ikke annet står.

**1. Tomkjøring er det alle måler, men det er den minste halvparten av tapet.**
I 2025 kjørte Nordvares 300 biler 40,4 mill. km med en teoretisk kapasitet på
895,4 mill. tonnkm. De fraktet 389,7 mill. tonnkm, en utnyttelsesgrad på 43,5 %.
Av de 505,8 mill. tonnkm som gikk tapt, kom 44,8 % fra tomme etapper
(tomkjøring 26,4 % av km) og 55,2 % fra *lastede* etapper som ikke var fulle.
En KPI som bare følger tomkjøringsandel, ser derfor ikke det største tapet.

**2. Returer med emballasje er tomkjøring i forkledning.** Distribusjonsbiler
har 30,3 % tomkjøring. Det ser bedre ut enn det er: 39,4 % av returkilometerne
deres er «lastet» med returemballasje, og den lasten bruker i snitt 15,9 % av
nyttelasten. Varegruppen RETUR alene står for 69,3 mill. tonnkm tapt kapasitet.
Regnes emballasjereturene som tomme, går distribusjonsbilenes tomandel fra
30,3 til 50,0 % av kilometerne (semitrailer: fra 24,5 til 32,1).

**3. Vektbasert utnyttelsesgrad kan ikke skille «ledig plass» fra «full bil med
lett gods».** Kjøl (55,2 %), frys (50,3 %) og non-food (45,0 %) er
volumbegrenset: bilen er full før nyttelasten er nådd. Drikkevarer ligger på
85,8 %. Modellen viser hvor tapet ligger, men datagrunnlaget mangler
volumdimensjonen (paller, lastemeter) som skal til for å si hvor mye av det
som er reelt. Det er en datamangel, ikke en modellfeil, og den er den samme
i SSBs statistikk: «volumgods» er definert i «Om statistikken», men ikke målt.

**4. Nord-Norge er strukturelt tomt hjem.** 72,1 % av returkilometerne ut fra
Nord-Norge er tomme, mot 46,5 % fra Østlandet. Det er kalibrert mot at
SSB 09830 viser at 72,2 % av all godsmengde i 2025 er kjøring *innenfor* eget
fylke og at de fem største strømmene mellom fylker alle går mellom Oslo,
Akershus, Buskerud, Østfold og Innlandet.

**5. Sesong følger SSB, men bunnen er februar, ikke juli.** Nordvares km-topp er
desember (3,99 mill. km) og oktober; bunnen er februar (2,69). Tomkjøringen er
lavest i K4 (24,8–25,3 %) og høyest i K2/K3, i tråd med SSB 03650 der 2025
ga 26,7 / 29,6 / 29,6 / 25,9 % per kvartal.

---

## Datagrunnlag

| Kilde | Innhold | Bruk i modellen |
|---|---|---|
| SSB 03650 | Km, km med last, tonn, tonnkm, tomkjøring %, snittlengde. Nasjonal leie-/egen-/internasjonal transport, kvartal 2003K1– | Referanselinje for tomkjøring og sesong. Kalibreringsmål for generatoren |
| SSB 08478 | Samme som 03650, år 1996– | Den lange tomkjøringsserien på Sesong-siden |
| SSB 09830 | Tonn og tonnkm fra fylke × til fylke, år 2003– | Godsstrømmer per region, omkodet til 2024-fylker |
| SSB 06988 | Tonn og tonnkm etter fem grove vareslag, kvartal 2008K1– | Vareslag-referanse i dbt, ikke i Power BI ennå |
| SSB 13321 | Km, tonn, tonnkm etter avstandsklasse × NST 2007-vareslag, år 2008– | Avstandsprofil i dbt, ikke i Power BI ennå |
| Nordvare AS | 689 012 etapper 2023-01 til 2026-06, syntetiske, generert i `src/generer_turer.py` | Hovedfakta |

Alle SSB-data under NLOD. Uttrekk 2026-09-02; 03650 og 06988 sist oppdatert
av SSB 2026-07-24, de tre andre 2026-04-24. Sha256 per fil i
`data/raw/ssb/manifest.json`.

Nordvare AS finnes ikke. Flåten (300 biler, seks lagre fra Vestby til Tromsø),
turene og lastene er generert deterministisk med kjent frø. Bilene fases inn
gradvis: 149 kjører i januar 2023, alle 300 fra oktober 2024. Det som er
kalibrert mot SSB: tomkjøringsandel per kvartal (test krever ±3,5 pp mot
03650), fylkenes attraksjon (09830, transportmengde 2024) og sesongprofil.
Det som er antatt, med begrunnelse i `seeds/ssb_kalibrering_retur.csv` og
`seeds/varegruppe.csv`: sannsynlighet for returlast per fylke og typisk
utnyttelse per varegruppe.

Fire feil er lagt inn med hensikt og fanges i dbt:
- 1 053 etapper med tonn over nyttelast (overlast eller feilregistrering).
  Beholdes, flagges `er_overlast`. Gir den ene forventede advarselen.
- 5 122 utgående etapper med ukjent avlessingsfylke (kode 99), som i SSB.
- 1 346 duplikate etappe-rader. Fjernes i `stg_etapper`.
- 53 128 etapper registrert etter at måneden var over (etterregistrering).
  Det er grunnen til at inkrementell last alltid tar siste måned på nytt.

---

## Modellvalg

**Inkrementell faktatabell partisjonert på måned.** `fact_etappe` er
`materialized='incremental'` med `delete+insert` på `maaned_start`. Første
kjøring laster alle 42 månedene. Senere kjøringer laster bare måneder fra og
med siste måned i tabellen minus `reload_maaneder` (standard 1). Hvorfor ikke
bare append nye rader: etterregistreringer lander i en måned som allerede er
lastet. Append ville mistet dem, eller krevd dedup på hele tabellen, som er en
full oppfriskning i forkledning.

**Partisjoner som filer, ikke bare som dbt-konsept.** Både råfilene
(`data/raw/turer/turer_YYYY-MM.parquet`) og eksporten
(`data/mart/fact_etappe/fact_etappe_YYYY-MM.parquet`) er én fil per måned med
sha256 i manifest. En uendret måned skrives aldri på nytt. Det er den samme
ideen Power BI bruker i sin refresh policy, og det er det som gjør at
`RangeStart`/`RangeEnd` i Power Query kan velge *filer* i stedet for å
filtrere rader etter at alt er lest. CSV og parquet støtter ikke query
folding; filvalg på navn er erstatningen.

**Kapasitetsregnskap per etappe, ikke som mål i DAX.**
`kapasitet_tonnkm = nyttelast × km`, `tonnkm = tonn × km`,
`tapt = kapasitet − tonnkm`, delt i `tapt_tom` (tonn = 0) og `tapt_delvis`
(tonn > 0). Regnskapet balanserer per rad (test) og aggregeres i
`fact_kapasitet_maaned` (56 255 rader), som rapporten leser overalt unntatt
på siden Etapper og i kontrolltallene. Tomkjøringsandel og utnyttelsesgrad er *forhold* mellom
summer, `DIVIDE(SUM(km_tom), SUM(km))`, aldri et gjennomsnitt av prosenter.

**Overlast pyntes ikke bort.** Tonn over nyttelast gir negativt tap; det
settes til 0 og radene flagges i stedet for å bli klippet eller slettet.
Testen er `severity: warn` med vilje.

**Fylkesdimensjon med bro for 2018/2020/2024-reformene.** SSB 09830 bruker
tre kodegenerasjoner. Sammenslåinger er mange-til-én. Oppløsningene i 2024
(Viken, Vestfold og Telemark, Troms og Finnmark) er én-til-mange og fordeles
med andeler fra 2019-tall i samme tabell, lagt på både fra- og til-siden.
Test: andelene summerer til 1 per kode, og omkodingen skaper aldri tonn.
Samme mønster som `dim_kommune` i `kostra-eiendom`.

**SSB-referansen ligger i egne faktatabeller,** ikke blandet inn i
Nordvares. De har ulik kornstørrelse (kvartal/år mot dag) og ulik enhet
(millioner mot tonn); å slå dem sammen ville gitt en tabell der halvparten
av radene er tomme.

### I Power BI

**Én datotabell for alle faktatabellene.** `dim_dato` går fra 1996 til 2026.
Nordvare kobles på dato og månedsstart, SSB på kvartals- og årsstart. Velger
du 2025, filtreres Nordvare og SSB likt. Planen hadde en egen `dim_maaned`;
den trengtes ikke, fordi månedsstart alltid er en dato som finnes i `dim_dato`.

**SSBs tomkjøring regnes på nytt fra kilometerne.** `SSB tomkjøring %` er
`(km − km med last) / km` summert over hele kvartaler, ikke et snitt av SSBs
egne prosenter. Per måned viser den kvartalet måneden ligger i.

**Beregningsgruppen Tidsvindu** har tre elementer: valgt periode, året før og
endring. Den sammenligner bare måneder som har data, så første halvår 2026
måles mot første halvår 2025. Andeler gir prosentpoeng, alt annet relativ
endring, avrundet slik det vises.

**Inkrementell oppdatering på filnivå.** `fact_etappe` har en refresh policy
med tre års arkiv og to måneder som lastes på nytt. Spørringen leser bare de
14 kolonnene modellen bruker og bare filene i vinduet. Etikettene
(laststatus, registrering, dager etter månedsslutt) lages i dbt, ikke i Power
Query.

---

## Kontrolltall

Nordvare AS, 2025 (helt år):

| Tall | Verdi |
|---|---|
| Etapper / turer | 228 020 / 114 010 |
| Kjøretøykilometer | 40,38 mill. km |
| Tomkjøring (km uten last / km) | 26,4 % |
| Kapasitet | 895,4 mill. tonnkm |
| Transportarbeid | 389,7 mill. tonnkm |
| Utnyttelsesgrad | 43,5 % |
| Tapt kapasitet: tom / delvis | 226,8 / 279,0 mill. tonnkm |
| Tomkjøringens andel av tapet | 44,8 % |

Mot 2024: kjøretøykm +10,9 %, tapt kapasitet +10,7 %, utnyttelsesgrad
+0,5 pp og tomkjøringens andel av tapet −0,4 pp. Økningen i km kommer av at
flåten fases inn til oktober 2024. Tomkjøringen ligger 1,5 pp under SSBs for
de samme kvartalene (27,9 %). Oversikt-siden med 2025 valgt viser de samme
tallene.

Per kjøretøygruppe 2025: semitrailer tomkjøring 24,5 %, utnyttelse 44,8 %,
tapt 278,0 mill. tonnkm; modulvogntog 24,6 / 45,5 / 149,9; distribusjonsbil
30,3 / 33,6 / 77,8.

SSB 03650, nasjonal leie- og egentransport: tomkjøring 2025K1–K4 =
26,7 / 29,6 / 29,6 / 25,9 %; transportarbeid 2025K4 = 5 443,5 mill. tonnkm;
kjøretøykm 2025K4 = 520,4 mill. km. SSB 09830, 2025: 252 384 tusen tonn og
22 010 mill. tonnkm i SSBs totalrad. Summen av cellene, som rapporten viser,
er 251,8 mill. tonn (prikking, se forbehold 3).

Totalt i faktatabellen: 687 666 etapper (689 012 rader i råfilene minus
1 346 duplikater), 42 månedspartisjoner, data til 30.06.2026. 53 128 etapper
(7,7 %) er etterregistrert, den seneste 25 dager etter månedsslutt. Avviket i
km mellom `fact_etappe` og aggregatet er 0. dbt: `PASS=62 WARN=1 ERROR=0`
(63 tester).

---

## Forbehold

1. **Nordvare AS er syntetisk.** Tallene i «Funn» beskriver generatoren,
   ikke en reell virksomhet. Det som kan sies om virkeligheten, står i
   SSB-tabellene; det Nordvare viser, er *hvordan* et kapasitetsregnskap må
   bygges for å finne tapet og hvor vektdata alene ikke rekker.

2. **Kapasitetsutnyttelse finnes ikke lenger hos SSB.** «Kapasitetsutnytting»
   ble publisert til rundt 2002, men er ikke i noen tabell i dag. Tomkjøring
   er det eneste utnyttelsesmålet som er reelt. Utnyttelsesgraden her er
   konstruert fra syntetisk nyttelast.

3. **SSB 09830 er prikket.** Summen av alle fra × til-celler er 0,1–1,0 %
   lavere enn SSBs egen totalrad hvert år, fordi celler med få observasjoner
   er undertrykt. Det rammer lange relasjoner (Østfold → Finnmark, Agder →
   Trøndelag), nettopp de med høyest tomkjøringsrisiko. Testen godtar tapet
   opp til 1,2 %, og modellen skjuler det ikke.

4. **Fylkestall fra en utvalgsundersøkelse har stor usikkerhet.** Fra 2024 til
   2025 gikk transportmengden fra Buskerud fra 13 577 til 19 487 tusen tonn og
   fra Troms fra 5 669 til 11 657. Det er ikke doblinger i virkeligheten.

5. **Kjøretøykilometer i første kvartal er identiske tre år på rad.** 03650
   viser 498,4 mill. km i 2024K1, 498,4 i 2025K1 og 498,5 i 2026K1, mens
   tomkjøringen varierer (27,8 / 26,7 / 27,3). Det tyder på at totale km er
   modellert eller fremskrevet, ikke målt per kvartal. Ikke avklart i «Om
   statistikken».

6. **Andeler for Viken-, VT- og TF-oppløsningen er tonn fra 2019**, ett år, ett
   mål. En mer robust vekt ville brukt snitt av flere år og skilt mengde fra
   tonnkm.

7. **Incremental refresh i Power BI Desktop lager ikke partisjoner.**
   Politikken er definert og lagret i TMDL, men partisjonene oppstår først
   ved publisering til tjenesten. Desktop laster alltid alt innenfor
   `RangeStart`/`RangeEnd`. Se `GJENSTAR.md`.

8. **Vekst i 2023 og 2024 er innfasing av biler, ikke mer trafikk.** Det slår
   ut i «mot året før» på Oversikt og i sesongindeksen for de to årene.
   Se `GJENSTAR.md`.

---

## Struktur

```
extract/hent_ssb.py          fem SSB-tabeller -> data/raw/ssb/*.csv + manifest
src/generer_turer.py         Nordvare: flåte + månedspartisjoner i data/raw/turer/
src/eksport.py               mart -> data/mart/ (CSV + parquet-partisjoner)
seeds/                       fylke, fylke_bro, varegruppe, kjoretoygruppe, lager, kalibrering
models/staging/              views over råfiler, dedup
models/intermediate/         kapasitetsregnskap, fylkesomkoding, pivot
models/marts/                dim_*, fact_etappe (inkrementell), fact_kapasitet_maaned, fact_ssb_*
tests/                       8 singulære tester
powerbi/
  Nordvare_Kapasitetstap.pbip            åpnes i Power BI Desktop
  Nordvare_Kapasitetstap.SemanticModel/  modellen som TMDL
  Nordvare_Kapasitetstap.Report/         rapporten som PBIR, med tema og bakgrunnsbilder
  STEG_FOR_STEG.md                       byggelogg for modell og rapport
1_HENT.bat / 2_BYGG.bat / 3_NY_MAANED.bat
```

Hvordan kjøre: `START_HER.md`.

---

## Kilder og lisenser

- SSB, tabell 03650, 08478, 09830, 06988 og 13321: NLOD.
- Fylkesgrensene i kartet: Kartverket, via robhop/fylker-og-kommuner, CC BY 4.0.
- Ikonene i bakgrunnsbildene: Material Icons fra Google, Apache 2.0.
- Skriften i bakgrunnsbildene: Inter, SIL Open Font License 1.1.
