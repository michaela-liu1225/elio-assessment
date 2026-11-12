-- One customer/calendar day is one purchase occasion. Same-day split orders
-- must not inflate retention. Status is the final source snapshot, not CDC.
select
    customer_sk, purchase_date,
    min(purchased_at) as first_purchased_at,
    max(delivered_at) as last_delivered_at,
    count(*) as order_count,
    sum(merchandise_gmv) as merchandise_gmv,
    case when max(case when is_late then 1 else 0 end) = 1 then 1
         when count(is_late) < count(*) then null
         else 0 end as any_late,
    sum(case when delivered_at is null then 1 else 0 end) as missing_delivery_count
from {{ ref('fct_orders') }}
where is_delivered and purchase_date <= {{ analysis_cutoff() }}
group by customer_sk, purchase_date
