{# SSB 13321. Avstandsklasse x vareslag (NST 2007), år. #}
select
    Avstandsklasser          as avstandsklasse_kode,
    Avstandsklasser_tekst    as avstandsklasse,
    Vareslag                 as nst_kode,
    Vareslag_tekst           as nst_navn,
    cast(Tid as integer)     as aar,
    statistikkvariabel,
    try_cast(verdi as double) as verdi
from read_csv('{{ var("raw_mappe") }}/ssb/avstand_vareslag_aar.csv', header = true, all_varchar = true)
