-- Omkodingen til 2024-fylker skal ikke skape tonn: summen av alle fra x til
-- kan aldri overstige SSBs egen totalrad F0/T0.
--
-- Den kan derimot ligge under, og gjør det for alle år (0,1-1,0 %). Årsaken
-- er prikking: celler med få observasjoner i utvalgsundersøkelsen er
-- undertrykt (tomme), typisk lange relasjoner som Østfold -> Finnmark.
-- Testen godtar et tap på inntil 1,2 %. Se README, forbehold 3.
with omkodet as (
    select aar, sum(tonn_1000) as tonn
    from {{ ref('fact_ssb_fylkesstrom') }}
    group by 1
),
ssb_total as (
    select aar, verdi as tonn
    from {{ ref('stg_ssb_fylkesmatrise') }}
    where fra_kode_historisk = '0' and til_kode_historisk = '0'
      and statistikkvariabel = 'Mengde'
)
select o.aar, o.tonn as omkodet, s.tonn as ssb_total,
       round(100.0 * (s.tonn - o.tonn) / s.tonn, 2) as tap_pst
from omkodet o
join ssb_total s using (aar)
where o.tonn > s.tonn + 0.5
   or (s.tonn - o.tonn) / s.tonn > 0.012
