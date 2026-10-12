{{
  config(
    materialized = 'incremental',
    incremental_strategy = 'delete+insert',
    unique_key = 'maaned_start'
  )
}}
{#
  Inkrementell faktatabell partisjonert på måned.

  Første kjøring: alle måneder.
  Senere kjøringer: bare måneder fra og med (siste måned i tabellen - reload_maaneder).
  delete+insert på maaned_start sletter disse månedene og setter dem inn på nytt,
  så etterregistreringer i en åpen måned kommer med uten full oppfriskning.

  Hvorfor ikke bare "append nye rader"? Fordi en etappe kan være registrert
  etter at måneden ble lastet første gang (feil D i generatoren). Append ville
  enten mistet den eller krevd dedup på hele tabellen - som er en full
  oppfriskning i forkledning.
#}
select
    etappe_id,
    tur_id,
    kjoretoy_id,
    kjoretoygruppe_kode,
    lager_id,
    dato,
    maaned_start,
    maaned_id,
    partisjon,
    sekvens,
    etappetype,
    fra_fylke_kode,
    til_fylke_kode,
    coalesce(varegruppe_kode, 'TOM') as varegruppe_kode,
    km,
    tonn,
    nyttelast_tonn,
    tonnkm,
    kapasitet_tonnkm,
    tapt_tom_tonnkm,
    tapt_delvis_tonnkm,
    tapt_tom_tonnkm + tapt_delvis_tonnkm as tapt_tonnkm,
    er_tom,
    er_overlast,
    er_etterregistrert,
    registrert_dato,
    -- Etiketter for Power BI. Før ble de regnet rad for rad i Power Query, og da
    -- tok oppdateringen av fact_etappe i Power BI Desktop mange minutter.
    case when er_tom then 'Tom' when er_overlast then 'Overlast' else 'Lastet' end as laststatus,
    case when er_etterregistrert then 'Etterregistrert' else 'I tide' end as registrering,
    greatest(0, date_diff('day', last_day(dato), registrert_dato)) as dager_etter_maanedsslutt
from {{ ref('int_etappe') }}
{% if is_incremental() %}
where maaned_start >= (
    select max(maaned_start) - interval {{ var('reload_maaneder') }} month
    from {{ this }}
)
{% endif %}
