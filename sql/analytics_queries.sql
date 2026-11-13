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

-- name: dispatch_quarter
-- Same trigger quarter for both groups; delivered/mature conditional baseline.
-- Association is NOT a treatment effect. Unknown/canceled outcomes are reported separately.
select is_historical_alert,
       count(*) as orders,
       sum(case when is_late then 1 else 0 end) as late_orders,
       cast(sum(case when is_late then 1 else 0 end) as float) / count(*) as late_rate,
       count(first_review_score) as reviewed_orders,
       sum(case when first_review_score <= 2 then 1 else 0 end) as low_first_reviews,
       sum(case when latest_review_score <= 2 then 1 else 0 end) as low_latest_reviews,
       sum(case when handed_over_next_48h then 1 else 0 end) as handovers_next_48h,
       sum(merchandise_gmv) as merchandise_gmv,
       count(distinct seller_id) as sellers,
       median(datediff(day, trigger_date, estimated_delivery_date)) as median_promise_lead_days
from ELIO_ASSESSMENT.DEV_MARTS.MART_DELIVERY_RISK
where trigger_date between '2018-04-01' and '2018-06-30'
  and has_valid_dispatch_context and has_mature_delivery_window
  and observed_delivered_by_cutoff and is_late is not null
group by is_historical_alert
order by is_historical_alert;

-- name: dispatch_status
-- Include all statuses in workload costing. Historical cancellations cannot be timed.
select order_status, count(*) as proxy_alerts,
       sum(case when has_mature_delivery_window and observed_delivered_by_cutoff
                 and is_late is not null then 1 else 0 end) as assessable_delivered_orders,
       sum(case when handed_over_next_48h then 1 else 0 end) as handovers_next_48h
from ELIO_ASSESSMENT.DEV_MARTS.MART_DELIVERY_RISK
where is_historical_alert and trigger_date between '2018-04-01' and '2018-06-30'
group by order_status
order by order_status;

-- name: dispatch_monthly
-- Monthly baseline variation: never treat the pooled comparator as a causal counterfactual.
select cast(date_trunc('month', trigger_date) as date) as trigger_month,
       is_historical_alert, count(*) as orders,
       sum(case when is_late then 1 else 0 end) as late_orders,
       cast(sum(case when is_late then 1 else 0 end) as float) / count(*) as late_rate
from ELIO_ASSESSMENT.DEV_MARTS.MART_DELIVERY_RISK
where trigger_date between '2018-01-01' and '2018-06-30'
  and has_valid_dispatch_context and has_mature_delivery_window
  and observed_delivered_by_cutoff and is_late is not null
group by trigger_month, is_historical_alert
order by trigger_month, is_historical_alert;

-- name: delivery_experience
-- All mature delivered Q2 purchase cohorts, independent of the dispatch rule.
-- First survey response can precede delivery; report this explicitly.
select is_late, count(*) as orders, count(first_review_score) as reviewed_orders,
       sum(case when first_review_score <= 2 then 1 else 0 end) as low_first_reviews,
       sum(case when latest_review_score <= 2 then 1 else 0 end) as low_latest_reviews,
       sum(case when review_before_delivery then 1 else 0 end) as reviews_before_delivery
from ELIO_ASSESSMENT.DEV_MARTS.MART_DELIVERY_RISK
where purchase_date between '2018-04-01' and '2018-06-30'
  and observed_delivered_by_cutoff and has_mature_delivery_window and is_late is not null
group by is_late
order by is_late;

-- name: activation_quarter
-- Like-for-like quarterly flow; do not compare operations volume to a single CRM backlog.
select count(*) as eligible_customers,
       sum(case when repeated_next_30d then 1 else 0 end) as repeat_customers,
       cast(sum(case when repeated_next_30d then 1 else 0 end) as float) / count(*) as repeat_rate,
       sum(next_30d_orders) as subsequent_orders, sum(next_30d_gmv) as subsequent_gmv,
       sum(next_30d_gmv) / nullif(sum(next_30d_orders), 0) as subsequent_order_aov
from ELIO_ASSESSMENT.DEV_MARTS.MART_ACTIVATION_HISTORY
where landmark_date between '2018-04-01' and '2018-06-30';

-- name: category_opportunity
-- Transaction value is observable; exposure, conversion, CAC and category contribution are not.
with categories as (
    select p.category_label, count(distinct i.order_id) as orders,
           sum(i.item_gmv) as merchandise_gmv
    from ELIO_ASSESSMENT.DEV_MARTS.FCT_ORDER_ITEMS i
    join ELIO_ASSESSMENT.DEV_MARTS.DIM_PRODUCT p on i.product_sk = p.product_sk
    where i.order_status = 'delivered' and i.purchase_date between '2018-04-01' and '2018-06-30'
    group by p.category_label
)
select *, cast(merchandise_gmv as float) / sum(merchandise_gmv) over () as share_of_gmv
from categories
order by merchandise_gmv desc, category_label
limit 5;

-- name: dispatch_geography
-- Descriptive state stratification, with denominators; small strata are not ranked as targets.
select delivery_state, is_historical_alert, count(*) as orders,
       sum(case when is_late then 1 else 0 end) as late_orders
from ELIO_ASSESSMENT.DEV_MARTS.MART_DELIVERY_RISK
where trigger_date between '2018-04-01' and '2018-06-30'
  and has_valid_dispatch_context and has_mature_delivery_window
  and observed_delivered_by_cutoff and is_late is not null
group by delivery_state, is_historical_alert
order by delivery_state, is_historical_alert;
