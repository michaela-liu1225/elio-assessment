-- Retrospective landmark cohort: first delivered shopping occasion + 30 days.
-- Final snapshot statuses are used for outcomes; this is not a causal backtest.
with landmarks as (
    select *, cast({{ add_days(30, 'cast(first_delivered_at as date)') }} as date) as landmark_date
    from {{ ref('mart_customer_retention') }}
    where first_occasion_late = 0 and first_missing_delivery_count = 0
        and first_purchase_date >= cast('{{ var("cohort_start") }}' as date)
), eligible as (
    select l.*
    from landmarks l
    where {{ add_days(30, 'l.landmark_date') }} <= {{ analysis_cutoff() }}
        and not exists (
            select 1 from {{ ref('fct_orders') }} o
            where o.customer_sk = l.customer_sk and o.purchase_date <= l.landmark_date
                and (o.purchase_date > l.first_purchase_date or not o.is_delivered)
        )
)
select e.customer_sk, e.landmark_date, e.first_category, e.first_occasion_gmv,
    count(o.order_id) > 0 as repeated_next_30d,
    coalesce(sum(o.merchandise_gmv), 0) as next_30d_gmv,
    count(o.order_id) as next_30d_orders
from eligible e
left join {{ ref('fct_orders') }} o
    on e.customer_sk = o.customer_sk and o.is_delivered
    and o.purchase_date > e.landmark_date
    and o.purchase_date <= {{ add_days(30, 'e.landmark_date') }}
group by e.customer_sk, e.landmark_date, e.first_category, e.first_occasion_gmv
