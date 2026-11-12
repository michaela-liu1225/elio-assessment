select * from {{ ref('mart_customer_retention') }}
where (not is_mature_cohort and repeated_within_window is not null)
    or (is_mature_cohort and repeated_within_window is null)
    or second_purchase_date <= first_purchase_date
    or (repeated_within_window and
        second_purchase_date > {{ add_days(var('repeat_window_days'), 'first_purchase_date') }})
