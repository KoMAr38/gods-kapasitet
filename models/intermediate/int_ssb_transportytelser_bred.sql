{# Pivoterer SSB 03650 til én rad per transporttype x kvartal. #}
select
    transporttype_kode,
    transporttype,
    periode,
    aar,
    kvartal,
    max(case when statistikkvariabel = 'KjoreKm'         then verdi end) as kjoretoykm_mill,
    max(case when statistikkvariabel = 'LjoreKmLast'     then verdi end) as kjoretoykm_med_last_mill,
    max(case when statistikkvariabel = 'TranspMengd'     then verdi end) as transportmengde_mill_tonn,
    max(case when statistikkvariabel = 'Transportarbeid' then verdi end) as transportarbeid_mill_tonnkm,
    max(case when statistikkvariabel = 'TomKjor'         then verdi end) as tomkjoring_pst,
    max(case when statistikkvariabel = 'GjTransLengd'    then verdi end) as gj_transportlengde_km
from {{ ref('stg_ssb_transportytelser_kvartal') }}
group by 1, 2, 3, 4, 5
