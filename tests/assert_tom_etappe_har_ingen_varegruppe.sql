-- En etappe uten tonn skal ha varegruppe TOM, og en etappe med tonn skal ikke ha det.
select etappe_id
from {{ ref('fact_etappe') }}
where (tonn = 0 and varegruppe_kode <> 'TOM')
   or (tonn > 0 and varegruppe_kode = 'TOM')
