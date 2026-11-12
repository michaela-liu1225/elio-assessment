with category_names as (
    select distinct coalesce(category_name, '__unknown__') as category_name
    from {{ ref('stg_products') }}
)
select
    n.category_name,
    t.category_name_english,
    case when n.category_name = '__unknown__' then 'Unknown'
         else coalesce(t.category_name_english, n.category_name) end as category_label,
    t.category_name is not null as has_translation
from category_names n
left join {{ ref('stg_category_translation') }} t using (category_name)
