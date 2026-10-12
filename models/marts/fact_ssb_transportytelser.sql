{# SSB 03650, bred. Referanselinje for tomkjøring og sesong i rapporten. #}
select
    transporttype_kode,
    transporttype,
    periode,
    aar,
    kvartal,
    aar * 10 + kvartal as kvartal_id,
    make_date(aar, (kvartal - 1) * 3 + 1, 1) as kvartal_start,
    kjoretoykm_mill,
    kjoretoykm_med_last_mill,
    transportmengde_mill_tonn,
    transportarbeid_mill_tonnkm,
    tomkjoring_pst,
    gj_transportlengde_km
from {{ ref('int_ssb_transportytelser_bred') }}
