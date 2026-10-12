select
    varegruppe_kode,
    varegruppe_navn,
    nst_kode,
    nst_navn,
    volumbegrenset = 1 as er_volumbegrenset,
    case when volumbegrenset = 1 then 'Volum' else 'Vekt' end as begrensning,
    typisk_utnyttelse,
    row_number() over (order by typisk_utnyttelse desc) as sortering
from {{ ref('varegruppe') }}
union all
select 'TOM', 'Tomkjøring', null, null, false, 'Tom', 0.0, 99
