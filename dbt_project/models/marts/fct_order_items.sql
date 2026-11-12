select
    md5('item|' || i.order_id || '|' || cast(i.order_item_id as varchar)) as order_item_sk,
    i.order_id,
    i.order_item_id,
    c.customer_sk,
    p.product_sk,
    i.seller_id,
    cast(o.purchased_at as date) as purchase_date,
    o.purchased_at,
    o.order_status,
    i.price as item_gmv,
    i.freight_value as freight_amount,
    1 as item_count,
    i._source,
    i._loaded_at
from {{ ref('stg_order_items') }} i
join {{ ref('stg_orders') }} o on i.order_id = o.order_id
join {{ ref('int_order_customers') }} oc on o.customer_id = oc.customer_id
join {{ ref('dim_customer') }} c on oc.customer_unique_id = c.customer_unique_id
join {{ ref('dim_product') }} p on i.product_id = p.product_id
