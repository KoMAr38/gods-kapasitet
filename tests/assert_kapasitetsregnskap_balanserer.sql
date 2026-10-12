-- kapasitet = tonnkm + tapt for alle etapper uten overlast.
-- Overlast holdes utenfor fordi tapt der er satt til 0 med hensikt.
select etappe_id
from {{ ref('fact_etappe') }}
where not er_overlast
  and abs(kapasitet_tonnkm - (tonnkm + tapt_tonnkm)) > 0.01
