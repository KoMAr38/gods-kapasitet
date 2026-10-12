-- Månedsaggregatet skal summere til nøyaktig det samme som detaljtabellen.
with a as (select sum(km) km, sum(tonnkm) tonnkm, sum(tapt_tonnkm) tapt from {{ ref('fact_kapasitet_maaned') }}),
d as (select sum(km) km, sum(tonnkm) tonnkm, sum(tapt_tonnkm) tapt from {{ ref('fact_etappe') }})
select a.km, d.km
from a, d
where abs(a.km - d.km) > 0.01 or abs(a.tonnkm - d.tonnkm) > 0.01 or abs(a.tapt - d.tapt) > 0.01
