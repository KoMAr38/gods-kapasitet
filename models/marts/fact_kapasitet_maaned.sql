{#
  Aggregat for rapportens hovedspørsmål: hvor går kapasiteten tapt?
  Bygges alltid helt på nytt fra fact_etappe - den er liten.
#}
select
    maaned_start,
    maaned_id,
    fra_fylke_kode,
    til_fylke_kode,
    kjoretoygruppe_kode,
    lager_id,
    varegruppe_kode,
    etappetype,
    count(*)                    as antall_etapper,
    sum(km)                     as km,
    sum(case when er_tom then km else 0 end) as km_tom,
    sum(tonn)                   as tonn,
    sum(tonnkm)                 as tonnkm,
    sum(kapasitet_tonnkm)       as kapasitet_tonnkm,
    sum(tapt_tom_tonnkm)        as tapt_tom_tonnkm,
    sum(tapt_delvis_tonnkm)     as tapt_delvis_tonnkm,
    sum(tapt_tonnkm)            as tapt_tonnkm
from {{ ref('fact_etappe') }}
group by 1, 2, 3, 4, 5, 6, 7, 8
