{# SSB 13321, bred. Avstandsklasse x NST-vareslag x år. #}
select
    aar,
    avstandsklasse_kode,
    avstandsklasse,
    nst_kode,
    nst_navn,
    max(case when statistikkvariabel = 'KjorekmAlt'  then verdi end) as kjoretoykm_mill,
    max(case when statistikkvariabel = 'TransMengde' then verdi end) as transportmengde_mill_tonn,
    max(case when statistikkvariabel = 'Transarb'    then verdi end) as transportarbeid_mill_tonnkm
from {{ ref('stg_ssb_avstand') }}
group by 1, 2, 3, 4, 5
