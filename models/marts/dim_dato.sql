{#
  Egen datotabell 1996-01-01 til 2026-12-31. Auto date/time skrus av i Power BI.
  Starter i 1996 fordi SSB 08478 gjør det; alle faktatabeller knyttes hit på
  periodens første dag (dag, måned, kvartal eller år), så ett årsvalg filtrerer
  både Nordvare og SSB.
#}
with d as (
    select unnest(generate_series(date '1996-01-01', date '2026-12-31', interval 1 day))::date as dato
),
etapper as (
    select min(dato) as forste, max(dato) as siste from {{ ref('stg_etapper') }}
)
select
    dato,
    year(dato)                                   as aar,
    quarter(dato)                                as kvartal,
    'K' || quarter(dato)                         as kvartal_kort,
    year(dato) || 'K' || quarter(dato)           as kvartal_label,
    date_trunc('quarter', dato)::date            as kvartal_start,
    year(dato) * 10 + quarter(dato)              as kvartal_id,
    month(dato)                                  as maaned,
    {{ maaned_id('dato') }}                      as maaned_id,
    date_trunc('month', dato)::date              as maaned_start,
    strftime(dato, '%Y-%m')                      as maaned_label,
    case month(dato)
        when 1 then 'jan' when 2 then 'feb' when 3 then 'mar' when 4 then 'apr'
        when 5 then 'mai' when 6 then 'jun' when 7 then 'jul' when 8 then 'aug'
        when 9 then 'sep' when 10 then 'okt' when 11 then 'nov' else 'des' end as maaned_kort,
    case month(dato)
        when 1 then 'jan' when 2 then 'feb' when 3 then 'mar' when 4 then 'apr'
        when 5 then 'mai' when 6 then 'jun' when 7 then 'jul' when 8 then 'aug'
        when 9 then 'sep' when 10 then 'okt' when 11 then 'nov' else 'des' end
        || ' ' || strftime(dato, '%y')           as maaned_aar,
    isodow(dato)                                 as ukedag_nr,
    case isodow(dato)
        when 1 then 'man' when 2 then 'tir' when 3 then 'ons' when 4 then 'tor'
        when 5 then 'fre' when 6 then 'lør' else 'søn' end as ukedag,
    isodow(dato) >= 6                            as er_helg,
    weekofyear(dato)                             as uke,
    -- hele måneder: månedsaggregatet ligger på den 1., som må telle med selv om første etappe er 2. januar
    date_trunc('month', dato) between date_trunc('month', etapper.forste) and date_trunc('month', etapper.siste) as har_data
from d, etapper
