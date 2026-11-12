-- Snowflake SQL. Default namespace: ELIO_ASSESSMENT.DEV_MARTS.
-- run_analysis.py substitutes only validated database/schema identifiers.
-- name: top_products
-- A5.1: top 10 products by delivered merchandise GMV, excluding freight.
select p.product_id, p.category_label, count(*) as items,
       count(distinct i.order_id) as orders, sum(i.item_gmv) as merchandise_gmv
from ELIO_ASSESSMENT.DEV_MARTS.FCT_ORDER_ITEMS i
join ELIO_ASSESSMENT.DEV_MARTS.DIM_PRODUCT p on i.product_sk = p.product_sk
where i.order_status = 'delivered' and i.purchase_date between '2017-01-01' and '2018-08-31'
group by p.product_id, p.category_label
order by merchandise_gmv desc, p.product_id
limit 10;

-- name: monthly_retention
-- A5.2: fixed 60-day cohort trend; omit partially mature calendar months.
select cast(date_trunc('month', first_purchase_date) as date) as cohort_month,
       count(*) as customers,
       sum(case when repeated_within_window then 1 else 0 end) as repeat_customers,
       cast(sum(case when repeated_within_window then 1 else 0 end) as float) / nullif(count(*), 0) as repeat_rate
from ELIO_ASSESSMENT.DEV_MARTS.MART_CUSTOMER_RETENTION
where is_mature_cohort and last_day(first_purchase_date) <= dateadd(day, -60, analysis_cutoff)
group by cohort_month
order by cohort_month;

-- name: category_retention
-- A5.4: descriptive category breakdown. >=500 customers is a display rule,
-- not a significance test or evidence that category causes retention.
select first_category, count(*) as customers,
       sum(case when repeated_within_window then 1 else 0 end) as repeat_customers,
       cast(sum(case when repeated_within_window then 1 else 0 end) as float) / nullif(count(*), 0) as repeat_rate
from ELIO_ASSESSMENT.DEV_MARTS.MART_CUSTOMER_RETENTION
where is_mature_cohort
group by first_category
having count(*) >= 500
order by repeat_rate desc, first_category;

-- name: retention_overall
select count(*) as customers,
       sum(case when repeated_within_window then 1 else 0 end) as repeat_customers,
       cast(sum(case when repeated_within_window then 1 else 0 end) as float) / nullif(count(*), 0) as repeat_rate
from ELIO_ASSESSMENT.DEV_MARTS.MART_CUSTOMER_RETENTION
where is_mature_cohort;

-- name: activation_baseline
-- A5.5: how many customers naturally repurchase after becoming eligible?
select count(*) as eligible_customers,
       sum(case when repeated_next_30d then 1 else 0 end) as repeat_customers,
       cast(sum(case when repeated_next_30d then 1 else 0 end) as float) / nullif(count(*), 0) as repeat_rate,
       sum(next_30d_orders) as subsequent_orders,
       sum(next_30d_gmv) as subsequent_gmv,
       sum(next_30d_gmv) / nullif(sum(next_30d_orders), 0) as subsequent_order_aov
from ELIO_ASSESSMENT.DEV_MARTS.MART_ACTIVATION_HISTORY;

-- name: activation_audience
select count(*) as candidate_customers, avg(first_occasion_gmv) as first_occasion_aov,
       min(first_delivery_date) as earliest_first_delivery,
       max(first_delivery_date) as latest_first_delivery
from ELIO_ASSESSMENT.DEV_MARTS.MART_ACTIVATION_CANDIDATES;

-- name: delivery_and_retention
select first_occasion_late, count(*) as customers,
       sum(case when repeated_within_window then 1 else 0 end) as repeat_customers,
       cast(sum(case when repeated_within_window then 1 else 0 end) as float) / nullif(count(*), 0) as repeat_rate
from ELIO_ASSESSMENT.DEV_MARTS.MART_CUSTOMER_RETENTION
where is_mature_cohort and first_missing_delivery_count = 0
group by first_occasion_late
order by first_occasion_late;

-- name: order_quality
select order_status, count(*) as orders,
       sum(case when item_count = 0 then 1 else 0 end) as missing_items,
       sum(case when payment_record_count = 0 then 1 else 0 end) as missing_payments,
       sum(case when is_delivered and delivered_at is null then 1 else 0 end) as missing_delivery_timestamps,
       sum(case when payment_reconciliation_status = 'difference' then 1 else 0 end) as payment_discrepancies,
       sum(case when is_late and is_delivered then 1 else 0 end) as late_deliveries,
       sum(merchandise_gmv) as merchandise_gmv
from ELIO_ASSESSMENT.DEV_MARTS.FCT_ORDERS
group by order_status
order by order_status;

-- name: monthly_source_coverage
select cast(date_trunc('month', purchase_date) as date) as purchase_month,
       count(*) as orders,
       sum(case when is_delivered then 1 else 0 end) as delivered_orders
from ELIO_ASSESSMENT.DEV_MARTS.FCT_ORDERS
group by purchase_month
order by purchase_month;
