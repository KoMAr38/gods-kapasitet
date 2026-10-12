{#
  Koder om SSB 09830 til fylkesstrukturen fra 2024 for hele serien 2003-2025.

  Sammenslåinger (2018, 2020) er mange-til-én og trenger ingen vekt.
  Oppløsningene i 2024 (Viken, Vestfold og Telemark, Troms og Finnmark) er
  én-til-mange: årene 2020-2023 fordeles med andeler fra 2019-tall i samme
  tabell (seeds/fylke_bro.csv, andel_grunnlag = tonn_2019_09830).
  Vekten legges på både fra- og til-siden, så en Viken->Viken-rad i 2022
  blir 9 rader med produktet av to andeler.

  Totalrader (kode '0') tas ikke med.
#}
with m as (
    select *
    from {{ ref('stg_ssb_fylkesmatrise') }}
    where fra_kode_historisk <> '0' and til_kode_historisk <> '0'
      and verdi is not null
),
bro as (
    select historisk_kode, gyldig_fra, gyldig_til, fylke_kode, andel
    from {{ ref('fylke_bro') }}
)
select
    m.aar,
    bf.fylke_kode                               as fra_fylke_kode,
    bt.fylke_kode                               as til_fylke_kode,
    m.statistikkvariabel,
    sum(m.verdi * bf.andel * bt.andel)          as verdi
from m
join bro bf
  on bf.historisk_kode = m.fra_kode_historisk
 and m.aar between bf.gyldig_fra and bf.gyldig_til
join bro bt
  on bt.historisk_kode = m.til_kode_historisk
 and m.aar between bt.gyldig_fra and bt.gyldig_til
group by 1, 2, 3, 4
