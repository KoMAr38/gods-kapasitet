{{ config(severity = 'warn') }}
-- Tonn over nyttelast er fysisk mulig (overlast) eller en feilregistrering.
-- Generatoren legger inn 0,3 % slike rader med hensikt. Testen skal gi WARN,
-- ikke stoppe bygget: radene beholdes og flagges (er_overlast) så rapporten
-- kan vise dem. Dette er den ene forventede advarselen i dbt test.
select etappe_id, kjoretoy_id, dato, tonn, nyttelast_tonn
from {{ ref('fact_etappe') }}
where er_overlast
