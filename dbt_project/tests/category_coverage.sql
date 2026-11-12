select p.product_id from {{ ref('stg_products') }} p
left join {{ ref('int_categories') }} c
    on coalesce(p.category_name, '__unknown__') = c.category_name
where c.category_name is null
