select
    kjoretoy_id,
    kjoretoygruppe_kode,
    nyttelast_tonn,
    lager_id,
    cast(hjemfylke_kode as varchar) as hjemfylke_kode,
    i_drift_fra
from read_csv('{{ var("raw_mappe") }}/kjoretoy.csv', header = true,
              types = {'hjemfylke_kode': 'VARCHAR', 'kjoretoy_id': 'VARCHAR'})
