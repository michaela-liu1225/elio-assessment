-- Illustrative historical audience at the explicit cutoff. Production must
-- re-evaluate live order/complaint/consent records immediately before sending.
select
    c.customer_sk, c.first_purchase_date, cast(c.first_delivered_at as date) as first_delivery_date,
    c.first_category, c.first_occasion_gmv, c.analysis_cutoff
from {{ ref('mart_customer_retention') }} c
where c.observed_purchase_occasions = 1
    and c.first_occasion_late = 0 and c.first_missing_delivery_count = 0
    and cast(c.first_delivered_at as date) between
        {{ add_days(-60, 'c.analysis_cutoff') }} and {{ add_days(-30, 'c.analysis_cutoff') }}
    and not exists (
        select 1 from {{ ref('fct_orders') }} o
        where o.customer_sk = c.customer_sk and o.purchase_date <= c.analysis_cutoff
            and (o.purchase_date > c.first_purchase_date or not o.is_delivered)
    )
