{#
  Leser alle månedsfiler. filename=true gir partisjonsnavnet, som brukes til
  å holde faktatabellen inkrementell. Duplikater (feil C i generatoren)
  fjernes her: samme etappe_id kan bare finnes én gang.
#}
with raa as (
    select
        etappe_id,
        tur_id,
        kjoretoy_id,
        dato,
        sekvens,
        fra_fylke_kode,
        til_fylke_kode,
        varegruppe_kode,
        km,
        tonn,
        registrert_dato,
        regexp_extract(filename, 'turer_(\d{4}-\d{2})\.parquet', 1) as partisjon
    from read_parquet('{{ var("raw_mappe") }}/turer/turer_*.parquet', filename = true)
)
select *
from raa
qualify row_number() over (partition by etappe_id order by registrert_dato) = 1
