-- Kalibreringstest: Nordvares tomkjøringsandel i km per kvartal skal ligge
-- innenfor 3,5 prosentpoeng av SSB 03650, nasjonal leie- og egentransport.
-- Feiler testen, er generatoren ute av kurs - ikke SSB.
with nv as (
    select
        year(dato) * 10 + quarter(dato) as kvartal_id,
        100.0 * sum(case when er_tom then km else 0 end) / sum(km) as tomkjoring_pst
    from {{ ref('fact_etappe') }}
    group by 1
),
ssb as (
    select kvartal_id, tomkjoring_pst
    from {{ ref('fact_ssb_transportytelser') }}
    where transporttype_kode = '01'
)
select nv.kvartal_id, nv.tomkjoring_pst as nordvare, ssb.tomkjoring_pst as ssb
from nv
join ssb using (kvartal_id)
where abs(nv.tomkjoring_pst - ssb.tomkjoring_pst) > 3.5
