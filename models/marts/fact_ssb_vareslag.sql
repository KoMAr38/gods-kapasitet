{# SSB 06988, bred. Fem grove varegrupper x kvartal. #}
select
    vareslag_kode,
    vareslag,
    periode,
    aar,
    kvartal,
    aar * 10 + kvartal as kvartal_id,
    max(case when statistikkvariabel = 'TranspMengd'     then verdi end) as transportmengde_mill_tonn,
    max(case when statistikkvariabel = 'Transportarbeid' then verdi end) as transportarbeid_mill_tonnkm
from {{ ref('stg_ssb_vareslag_kvartal') }}
group by 1, 2, 3, 4, 5
