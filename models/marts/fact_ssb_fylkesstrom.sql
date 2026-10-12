{# SSB 09830 omkodet til 2024-fylker. Én rad per år x fra x til. #}
with m as (
    select
        aar,
        fra_fylke_kode,
        til_fylke_kode,
        max(case when statistikkvariabel = 'Mengde'          then verdi end) as tonn_1000,
        max(case when statistikkvariabel = 'Transportarbeid' then verdi end) as transportarbeid_mill_tonnkm
    from {{ ref('int_fylkesmatrise_2024') }}
    group by 1, 2, 3
)
select
    m.aar,
    make_date(m.aar, 1, 1)                  as aar_start,
    m.fra_fylke_kode,
    m.til_fylke_kode,
    fra.fylke_navn || ' → ' || til.fylke_navn as strom,
    m.fra_fylke_kode = m.til_fylke_kode     as er_internt,
    m.tonn_1000,
    m.transportarbeid_mill_tonnkm
from m
join {{ ref('fylke') }} fra on fra.fylke_kode = m.fra_fylke_kode
join {{ ref('fylke') }} til on til.fylke_kode = m.til_fylke_kode
