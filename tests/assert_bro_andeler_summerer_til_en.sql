-- Hver historisk fylkeskode må fordele seg med andeler som summerer til 1
-- per gyldighetsperiode. Ellers forsvinner eller dobles tonn ved omkoding.
select historisk_kode, gyldig_fra, sum(andel) as sum_andel
from {{ ref('fylke_bro') }}
group by 1, 2
having abs(sum(andel) - 1.0) > 0.00005
