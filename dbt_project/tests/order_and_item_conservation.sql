-- A join must neither drop orders/items nor multiply additive amounts.
with actual as (
    select (select count(*) from {{ ref('fct_orders') }}) as orders,
           (select count(*) from {{ ref('fct_order_items') }}) as items,
           (select sum(item_gmv) from {{ ref('fct_order_items') }}) as item_gmv,
           (select sum(merchandise_gmv) from {{ ref('fct_orders') }}) as order_gmv,
           (select sum(payment_amount) from {{ ref('fct_orders') }}) as payments
), expected as (
    select (select count(*) from {{ ref('stg_orders') }}) as orders,
           (select count(*) from {{ ref('stg_order_items') }}) as items,
           (select sum(price) from {{ ref('stg_order_items') }}) as gmv,
           (select sum(payment_value) from {{ ref('stg_payments') }}) as payments
)
select a.* from actual a cross join expected e
where a.orders <> e.orders or a.items <> e.items
    or a.item_gmv <> e.gmv or a.order_gmv <> e.gmv or a.payments <> e.payments
    or a.orders = 0 or a.items = 0
