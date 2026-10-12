{# SSB 08478. Årstall 1996-. #}
select
    TransportYt              as transporttype_kode,
    TransportYt_tekst        as transporttype,
    cast(Tid as integer)     as aar,
    statistikkvariabel,
    statistikkvariabel_tekst,
    try_cast(verdi as double) as verdi
from read_csv('{{ var("raw_mappe") }}/ssb/transportytelser_aar.csv', header = true, all_varchar = true)
