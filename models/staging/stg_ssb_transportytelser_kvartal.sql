{# SSB 03650. Én rad per transporttype x variabel x kvartal, langt format. #}
select
    TransportYt              as transporttype_kode,
    TransportYt_tekst        as transporttype,
    Tid                      as periode,
    cast(substr(Tid, 1, 4) as integer) as aar,
    cast(substr(Tid, 6, 1) as integer) as kvartal,
    statistikkvariabel,
    statistikkvariabel_tekst,
    try_cast(verdi as double) as verdi
from read_csv('{{ var("raw_mappe") }}/ssb/transportytelser_kvartal.csv', header = true, all_varchar = true)
