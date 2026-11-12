with items as (
    select order_id, count(*) as item_count,
           sum(price) as merchandise_gmv, sum(freight_value) as freight_amount
    from {{ ref('stg_order_items') }} group by order_id
), payments as (
    select order_id, count(*) as payment_record_count,
           sum(payment_value) as payment_amount
    from {{ ref('stg_payments') }} group by order_id
), joined as (
    select
        o.order_id, c.customer_sk, o.customer_id as order_customer_id,
        o.order_status, o.purchased_at, cast(o.purchased_at as date) as purchase_date,
        o.approved_at, o.carrier_received_at, o.delivered_at,
        cast(o.estimated_delivery_at as date) as estimated_delivery_date,
        oc.zip_code_prefix as delivery_zip_prefix,
        oc.city as delivery_city, oc.state as delivery_state,
        coalesce(i.item_count, 0) as item_count,
        i.merchandise_gmv, i.freight_amount,
        i.merchandise_gmv + i.freight_amount as order_value,
        coalesce(p.payment_record_count, 0) as payment_record_count,
        p.payment_amount,
        p.payment_amount - (i.merchandise_gmv + i.freight_amount) as payment_difference,
        o.order_status = 'delivered' as is_delivered,
        o._source, o._loaded_at
    from {{ ref('stg_orders') }} o
    join {{ ref('int_order_customers') }} oc on o.customer_id = oc.customer_id
    join {{ ref('dim_customer') }} c on oc.customer_unique_id = c.customer_unique_id
    left join items i on o.order_id = i.order_id
    left join payments p on o.order_id = p.order_id
)
select *,
    case when delivered_at is null or estimated_delivery_date is null then null
         when delivered_at < purchased_at then null
         else cast(delivered_at as date) > estimated_delivery_date end as is_late,
    case when delivered_at >= purchased_at
         then {{ dbt.datediff('purchased_at', 'delivered_at', 'day') }} end as delivery_days,
    case when payment_amount is null or order_value is null then 'missing_component'
         when abs(payment_difference) <= 0.01 then 'matched'
         else 'difference' end as payment_reconciliation_status
from joined
