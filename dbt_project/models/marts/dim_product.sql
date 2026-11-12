-- Deliberate star-schema denormalisation: product plus category labels.
select
    md5('product|' || p.product_id) as product_sk,
    p.product_id,
    c.category_name,
    c.category_label,
    c.has_translation,
    p.weight_g,
    p.length_cm,
    p.height_cm,
    p.width_cm
from {{ ref('stg_products') }} p
join {{ ref('int_categories') }} c
    on coalesce(p.category_name, '__unknown__') = c.category_name
