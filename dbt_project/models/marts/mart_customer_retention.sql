with occasions as (
    select *, row_number() over (partition by customer_sk order by purchase_date) as occasion_number
    from {{ ref('int_purchase_occasions') }}
), first_category as (
    select i.customer_sk, i.purchase_date,
        case when count(distinct p.category_name) = 1 then min(p.category_label)
             else 'Mixed categories' end as first_category
    from {{ ref('fct_order_items') }} i
    join {{ ref('dim_product') }} p on i.product_sk = p.product_sk
    where i.order_status = 'delivered'
    group by i.customer_sk, i.purchase_date
), customer_summary as (
    select
        customer_sk,
        min(purchase_date) as first_purchase_date,
        min(case when occasion_number = 2 then purchase_date end) as second_purchase_date,
        max(case when occasion_number = 1 then last_delivered_at end) as first_delivered_at,
        max(case when occasion_number = 1 then any_late end) as first_occasion_late,
        max(case when occasion_number = 1 then missing_delivery_count end) as first_missing_delivery_count,
        max(case when occasion_number = 1 then merchandise_gmv end) as first_occasion_gmv,
        count(*) as observed_purchase_occasions,
        sum(order_count) as observed_delivered_orders
    from occasions group by customer_sk
)
select s.*, c.first_category,
    {{ analysis_cutoff() }} as analysis_cutoff,
    {{ add_days(var('repeat_window_days'), 's.first_purchase_date') }} <= {{ analysis_cutoff() }}
        and s.first_purchase_date >= cast('{{ var("cohort_start") }}' as date) as is_mature_cohort,
    case when {{ add_days(var('repeat_window_days'), 's.first_purchase_date') }} <= {{ analysis_cutoff() }}
        and s.first_purchase_date >= cast('{{ var("cohort_start") }}' as date)
        then s.second_purchase_date <= {{ add_days(var('repeat_window_days'), 's.first_purchase_date') }}
             and s.second_purchase_date is not null
        else null end as repeated_within_window
from customer_summary s
left join first_category c
    on s.customer_sk = c.customer_sk and s.first_purchase_date = c.purchase_date
