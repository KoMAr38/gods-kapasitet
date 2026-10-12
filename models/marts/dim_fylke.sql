{# kart_x/kart_y: lengdegrad og Mercator-y i grader. Spredningsdiagrammet på kartsiden bruker dem mot et kartbilde i samme projeksjon. #}
select
    cast(fylke_kode as varchar) as fylke_kode,
    fylke_navn,
    landsdel,
    case landsdel
        when 'Østlandet' then 1 when 'Sørlandet' then 2 when 'Vestlandet' then 3
        when 'Trøndelag' then 4 when 'Nord-Norge' then 5 else 9 end as landsdel_sortering,
    breddegrad,
    lengdegrad,
    ankerby,
    lengdegrad as kart_x,
    degrees(ln(tan(pi() / 4 + radians(breddegrad) / 2))) as kart_y
from {{ ref('fylke') }}
