select
    kjoretoygruppe_kode,
    kjoretoygruppe_navn,
    nyttelast_tonn,
    totalvekt_tonn,
    typisk_bruk,
    case kjoretoygruppe_kode when 'DIST' then 1 when 'SEMI' then 2 else 3 end as sortering
from {{ ref('kjoretoygruppe') }}
