{# SSB 06988. Fem grove varegrupper (NST/R-inndeling), kvartal. #}
select
    Vareslag                 as vareslag_kode,
    Vareslag_tekst           as vareslag,
    Tid                      as periode,
    cast(substr(Tid, 1, 4) as integer) as aar,
    cast(substr(Tid, 6, 1) as integer) as kvartal,
    statistikkvariabel,
    try_cast(verdi as double) as verdi
from read_csv('{{ var("raw_mappe") }}/ssb/vareslag_kvartal.csv', header = true, all_varchar = true)
