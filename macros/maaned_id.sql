{# Heltallsnøkkel for måned, f.eks. 202603. Sorterbar uten datotype. #}
{% macro maaned_id(dato) -%}
    (year({{ dato }}) * 100 + month({{ dato }}))
{%- endmacro %}
