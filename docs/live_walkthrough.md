# Live session preparation

## Ten-minute client presentation

**0-2 minutes:** "I evaluated a second-purchase opportunity by first making customer identity and transaction totals reliable. The evidence supports a capped learning experiment, not a broad coupon programme."

**2-4 minutes:** Explain first observed purchase, stable customer identity and the fixed observation window. Show the mature-cohort chart: 832/81,344 customers, or 1.02%, returned on a later shopping date within 60 days. The interval does not repair incomplete marketplace identity coverage.

**4-6 minutes:** Explain the reminder, eligibility, current-order suppression, consent/contact requirements and random holdout. The 5,718 historical candidates are not 5,718 known contactable customers.

**6-8 minutes:** Distinguish GMV from contribution. At assumed 50% reach and +0.50 percentage points, full-rollout incremental GMV is about R$1,707; 10% contribution leaves only R$114 after messages and before setup costs. A 0.50-point change from 0.334% is about 150% relative uplift, not a small guaranteed improvement.

**8-10 minutes:** Ask finance/CRM owners to confirm actual margin, reach and consent. Cap the budget, accumulate enough sample and report an inconclusive trial honestly. Show the actual Snowflake build evidence and query IDs: 17 models and 94 dbt tests passed, with nine query outputs matching local execution.

## Technical walkthrough

1. `ingest/dataset.py` and `load_raw.py`: explicit contract, RAW strings, UTF-8/BOM, provenance, error handling, hash audit and transactions.
2. `docs/data_model.md`: persistent customer versus order address context; composite item/payment keys; category normalisation and star denormalisation.
3. `fct_orders.sql`: aggregate items and payments independently. Two items and three payments must not produce six monetised records.
4. `mart_customer_retention.sql`: distinct shopping dates, fixed cutoff, complete windows, NULL outcomes for immature customers.
5. `models/unit_tests.yml`: day-60 boundary, malformed/fractional numbers, in-flight suppression and future events.
6. Git history and README: explain each implementation step, exact versions and actual validation evidence.

## Questions to practise

**Why not customer_id?** It is order-specific. The publisher's `customer_unique_id` is the appropriate observed buyer identity, with residual coverage limits.

**Why RAW strings?** To preserve source values for diagnosis. Analytical fields are explicitly typed later.

**Why not only TRY_CAST?** A failed conversion must be flagged so malformed data is not disguised as a legitimate NULL. Fractional item sequences are rejected rather than rounded.

**Why retain canceled orders?** They support operational reporting and campaign suppression. Each behavioural metric applies its own explicit status filter.

**Why do payment totals differ?** The data does not establish the cause. Retain and quantify the difference; do not invent refunds or balancing adjustments.

**Is this causal?** No. Historical/category comparisons are descriptive; a concurrent randomised experiment is required for incremental campaign claims.

**Why full refresh?** The extract is small and has no reliable change-event contract. Incrementing on purchase date misses later status changes; manufacturing SCD2 history would be misleading.

**Are reruns always safe?** Under the serial-file contract, hashes and audit/count checks prevent duplicate files. Concurrency, corrections, updates and deletions require further production controls.

**What if significance improves but profit falls?** Do not scale. Use incremental contribution after all costs and operational guardrails, not clicks or p-values alone.

## Practise a live extension

Add customer-state retention using the first order's address context. Declare how mixed first-day addresses are handled, preserve customer grain and the same observation window, and include denominators.

Or change the repeat window to 90 days: change the dbt variable, update the analytics full-month maturity filter, adjust the boundary fixture, rebuild and regenerate the narrative. Explain why fewer recent cohorts qualify.

Before the interview, run the project personally and make a small model change without assistance. AI assistance is permitted by the brief; understanding and live extension must be the candidate's own.
