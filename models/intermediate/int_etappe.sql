{#
  Beriker hver etappe med kjøretøy og regner ut kapasitetsregnskapet.

  kapasitet_tonnkm = nyttelast x km          hva bilen kunne ha fraktet
  tonnkm           = tonn x km                hva den faktisk fraktet
  tapt_tom         = kapasitet der tonn = 0   tomkjøring
  tapt_delvis      = kapasitet - tonnkm der tonn > 0, aldri under null
  tapt_tonnkm      = tapt_tom + tapt_delvis

  Overlast (tonn > nyttelast) gir negativ tapt_delvis; den settes til 0 og
  flagges, slik at feilen synes i test og rapport i stedet for å pynte på totalen.
#}
select
    e.etappe_id,
    e.tur_id,
    e.kjoretoy_id,
    k.kjoretoygruppe_kode,
    k.lager_id,
    k.nyttelast_tonn,
    e.dato,
    date_trunc('month', e.dato)::date          as maaned_start,
    {{ maaned_id('e.dato') }}                   as maaned_id,
    e.partisjon,
    e.sekvens,
    case e.sekvens when 1 then 'Utgående' else 'Retur' end as etappetype,
    e.fra_fylke_kode,
    e.til_fylke_kode,
    e.varegruppe_kode,
    e.km,
    e.tonn,
    e.registrert_dato,
    (e.tonn = 0)                                as er_tom,
    (e.tonn > k.nyttelast_tonn)                 as er_overlast,
    (e.registrert_dato > last_day(e.dato))      as er_etterregistrert,
    e.tonn * e.km                               as tonnkm,
    k.nyttelast_tonn * e.km                     as kapasitet_tonnkm,
    case when e.tonn = 0 then k.nyttelast_tonn * e.km else 0 end                as tapt_tom_tonnkm,
    case when e.tonn > 0 then greatest(k.nyttelast_tonn - e.tonn, 0) * e.km else 0 end as tapt_delvis_tonnkm
from {{ ref('stg_etapper') }} e
join {{ ref('stg_kjoretoy') }} k using (kjoretoy_id)
