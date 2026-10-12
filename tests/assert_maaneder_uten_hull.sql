-- Faktatabellen skal ha alle måneder fra første til siste uten hull.
-- Et hull betyr at en partisjonsfil mangler eller at inkrementell last
-- har hoppet over noe.
with m as (
    select distinct maaned_start from {{ ref('fact_etappe') }}
),
forventet as (
    select unnest(generate_series(
        (select min(maaned_start) from m),
        (select max(maaned_start) from m),
        interval 1 month))::date as maaned_start
)
select f.maaned_start
from forventet f
left join m using (maaned_start)
where m.maaned_start is null
