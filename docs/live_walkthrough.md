# Live session preparation

## Ten-minute client presentation

**0-2 minutes — decision:** “I compared dispatch recovery, repeat-purchase reminders and category growth. I would validate dispatch recovery first because the data identifies a concrete operational exception and a responsible team. I would not fund a bespoke implementation from these volumes.” Show the comparison, including why the decision can reverse.

**2-4 minutes — evidence:** Show the dispatch chart. Q2 trigger dates produced 679 proxy alerts across all statuses. Of 563 assessable deliveries, 174 were late (30.9%); the comparable known-handover group was 4.1%. These are risk differences, not intervention lift. The separate review comparison is 53.9% versus 9.0% low scores, with many responses before delivery.

**4-6 minutes — action:** Explain deadline +24 hours, single seller, approval, complete item context and remaining promise lead. Operations confirms pickup and escalates unresolved cases. Explain why the final-status snapshot cannot establish whether a historical order was already canceled, and why the live worklist must recheck current state and freshness.

**6-8 minutes — money:** Start with costs. There is no observed platform margin, support cost or refund ledger. At assumed R$30 avoidable cost, R$0.50 handling and R$500 setup, a five-point lateness reduction yields only R$5 quarterly net value; ten points yields R$850. Show the R$10-cost downside. The R$103,412 attached GMV is not “saved revenue.”

**8-10 minutes — test and decision:** Two weeks shadowing, ten weeks seller-randomised testing, week-13 handover readout and week-16 matured outcomes/cost review. Faster scans alone do not prove profitable delivery improvement. Explain the 430-order process-test planning target, clustering uncertainty and the larger 753-assessable-order late-delivery target. Stop or extend transparently if underpowered. Close with the finance/event inputs needed before spending.

## Technical walkthrough

1. `ingest/dataset.py` and `load_raw.py`: seven-file contract, untouched RAW strings, UTF-8/BOM and multiline CSV handling, provenance, abort policy, hash audit and transactions.
2. `docs/data_model.md`: stable customer versus order address context; independent item, payment and review child entities; category normalisation and star denormalisation.
3. `fct_orders.sql`: aggregate items and payments independently. Two items and three payments must not become six monetised records.
4. `stg_reviews.sql` and `int_order_reviews.sql`: review_id is not unique; preserve order/review pairs, exclude future responses and select one first score per order. Free text remains RAW-only.
5. `mart_delivery_risk.sql`: separate trigger context from outcomes; do not leak late-delivery/review scores into eligibility. Explain why timestamp reconstruction is not a point-in-time event store.
6. `models/unit_tests.yml`: trigger equality, exact 48-hour handover, missing and partial inputs, multiple sellers, snapshot cancellation, review fanout and the original retention boundaries.
7. `sql/analytics_queries.sql` and `scripts/evaluate_opportunities.py`: common-quarter flows, visible denominators, all-status workload costs, first/latest sensitivity, non-causal state standardisation and financial break-even.
8. Execution evidence: 20 models, 110 data tests, 7 unit tests and 16 SQL outputs; actual Snowflake query IDs, two derived scenario comparisons, seven-file idempotency, five Python tests.

## Questions to practise

**Why change the repurchase recommendation?** Low repeat does not identify the most valuable lever. The operations rule offers an observable trigger and a named owner, with conditional economics. Repurchase remains the fallback if CRM economics are better or operational feeds are unavailable. Do not say the chosen option is proven to have higher ROI.

**Why not optimise for the largest GMV category?** Sales are not conversion or incremental demand. Without exposure, margin, spend and stock, category rankings cannot justify acquisition budget.

**Why 24 hours?** It is a transparent grace-period hypothesis balancing actionability against noisy scans. It was not learned as an optimal threshold; shadowing should assess false alerts, lead time and workload before freezing the rule.

**Are 679 orders actionable?** No. They are reconstructed proxy alerts. Cancellation times, event arrival and revised promises are missing; the count includes 48 final canceled orders and other unresolved statuses. The model preserves this, and economics charge every proxy alert.

**Why include canceled orders in the mart?** Removing them silently would hide workload and source limitations. Current operations suppress cancellations before action. A randomised pilot still keeps later cancellations in the assigned denominator.

**Do bad ratings prove a monetary loss?** No. Ratings are a customer-experience signal, selected by response, and often precede delivery. Do not convert ratings or flagged GMV into avoided costs.

**What if the seller records a scan but the parcel does not move?** Validate carrier pickup evidence and downstream delivery, cancellations and support cost. The 48-hour process endpoint alone cannot authorise scaling.

**Why randomise sellers?** Seller behaviour may change for all their orders. Order-level randomisation risks spillover. Seller assignment requires cluster-aware inference, volume balancing and a realistic sample calculation; 1.25 is a planning assumption, not a measured design effect.

**Why full refresh?** The small extract has no reliable update-event contract. A purchase watermark misses later status changes; a snapshot cannot create historical truth from absent events.

**Why keep unknown monetary values NULL?** Zero claims a measured absence of value. Missing payment/item components are unknown and must remain visible. Reconciliation differences are investigated, not balanced with invented refunds.

**Why two engines?** Snowflake meets the brief; DuckDB is a regression harness for definitions and fast fixtures. Passing local tests or compilation never substitutes for actual Snowflake `PUT`/`COPY` and execution.

## Practise a live extension

Change the dispatch grace period from 24 to 48 hours. First explain how trigger dates, two-day promise lead, handover boundaries, workload and scenario outputs must all change. Parameterise the rule, update the native fixture, rebuild and regenerate outputs. Do not change only a graph label or continue using the original economics.

Alternatively add seller-level workload with denominators and a minimum-volume display rule. Retain multi-seller exclusions and explain why the result ranks workload rather than proving seller fault.

Practise making one small SQL/model change and explaining it without assistance. AI use is disclosed; execution evidence is not a substitute for the candidate's own understanding during the live extension.
