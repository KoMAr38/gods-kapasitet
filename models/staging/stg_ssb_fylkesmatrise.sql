{#
  SSB 09830. Kodene har prefiks F (fra) og T (til). Totalrader (F0/T0) beholdes
  med kode '0' og filtreres bort der de ikke hører hjemme.
#}
select
    substr(Region3, 2)       as fra_kode_historisk,
    Region3_tekst            as fra_tekst,
    substr(Region4, 2)       as til_kode_historisk,
    Region4_tekst            as til_tekst,
    cast(Tid as integer)     as aar,
    statistikkvariabel,
    try_cast(verdi as double) as verdi
from read_csv('{{ var("raw_mappe") }}/ssb/fylkesmatrise_aar.csv', header = true, all_varchar = true)
