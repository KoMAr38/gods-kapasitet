select
    k.kjoretoy_id,
    k.kjoretoygruppe_kode,
    g.kjoretoygruppe_navn,
    k.nyttelast_tonn,
    g.totalvekt_tonn,
    k.lager_id,
    l.lager_navn,
    k.hjemfylke_kode,
    k.i_drift_fra
from {{ ref('stg_kjoretoy') }} k
join {{ ref('kjoretoygruppe') }} g using (kjoretoygruppe_kode)
join {{ ref('lager') }} l using (lager_id)
