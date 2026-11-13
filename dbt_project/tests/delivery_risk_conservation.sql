-- Review multiplicity must not duplicate orders or their merchandise amounts.
with original as (
    select count(*) as order_count, sum(merchandise_gmv) as gmv from {{ ref('fct_orders') }}
), enriched as (
    select count(*) as order_count, sum(merchandise_gmv) as gmv from {{ ref('mart_delivery_risk') }}
)
select original.order_count as original_orders, enriched.order_count as enriched_orders
from original cross join enriched
where original.order_count <> enriched.order_count or original.gmv <> enriched.gmv
