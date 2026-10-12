select
    l.lager_id,
    l.lager_navn,
    cast(l.fylke_kode as varchar) as fylke_kode,
    f.fylke_navn,
    l.antall_kjoretoy
from {{ ref('lager') }} l
join {{ ref('fylke') }} f on f.fylke_kode = l.fylke_kode
