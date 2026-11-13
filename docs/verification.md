# Executed verification

Verified on **13 November 2026 (UTC)**. Snowflake is the actual submission platform; the local target is an independent regression harness.

## Results

| Check | Actual result | Evidence |
|---|---|---|
| Publisher files | Seven unmodified files, 547,664 source records; headers, UTF-8 and CSV widths validated | [Source manifest](source_manifest.json) |
| Snowflake ingestion | Seven successful per-file `PUT`/`COPY` loads across the initial run and reviews extension with expected row counts and no skipped malformed rows | [COPY results](evidence/snowflake_load.json) |
| Snowflake rerun | All seven files returned `already_loaded`; hash/audit counts agreed, with no new rows | [Rerun report](evidence/snowflake_rerun.json) and [actual RAW counts](evidence/snowflake_environment.json) |
| Snowflake dbt build | **20 models + 110 data tests + 7 unit tests = 137 successful nodes; 0 warnings/errors/skips** | [Per-node statuses, timing and query IDs](evidence/dbt_build_snowflake.json) |
| Local dbt build | Same **137** successful nodes | [Local build evidence](evidence/dbt_build_local.json) |
| Python regression checks | **5 passed** using `pytest -q tests` | [Test cases](../tests/test_ingest.py) |
| Engine comparison | All **16** analytical query outputs and **two** derived scenario files matched | [Comparison report](evidence/engine_parity.json) |
| Business memo | **196 words**, including To/Subject; within the 200-word limit | [B4 memo](../analysis_answers.md#b4-client-memo-under-200-words) |

The Snowflake build completed at **00:29:40 UTC**, with **50.01 seconds** reported by dbt. This is build elapsed time, not a billed-credit estimate. The verified runtime was Snowflake **10.41.101**, AWS **EU_WEST_2 (London)**, role `SYSADMIN`, database `ELIO_ASSESSMENT`, and warehouse `ELIO_ASSESSMENT_WH`. `SHOW WAREHOUSES` confirmed **X-Small**, **auto-suspend 60 seconds**, and **auto-resume true**. Snowsight showed an Enterprise trial. [Runtime query and warehouse evidence](evidence/snowflake_environment.json).

`dbt_build_snowflake.json` contains the real run's invocation ID and individual query IDs. [Analytical execution metadata](../analysis/results/snowflake/execution_metadata.json) contains all 16 SQL query IDs and the SQL file hash. The comparison script checks equal SQL hashes and query sets, exact counts/labels/dates/nulls, and numerical rounding tolerances of `1e-6` absolute / `1e-12` relative for floating outputs.

## Boundary cases exercised

- Two items and three payments remain two items; payments do not multiply merchandise value.
- Missing monetary components remain NULL, while genuine zero-valued records remain zero.
- Delivery later on the promised calendar date is on time; the following date is late.
- Missing estimates and reversed delivery dates have unknown timeliness. An unknown first-occasion order cannot become an on-time activation candidate.
- Same-day split orders form one shopping occasion. Canceled orders and purchases beyond the cutoff do not inflate delivered repeat purchasing.
- A repeat exactly on day 60 qualifies; immature outcomes are NULL; a mature non-repeater is false.
- An in-flight later order suppresses activation, while an order beyond the historical cutoff is ignored.
- Malformed money and fractional integer keys are flagged. UTF-8 BOM/Portuguese input, bad CSV widths, invalid UTF-8 and unsafe SQL identifiers are covered by ingestion tests.
- Review/order compound keys preserve repeated review IDs; first-response selection excludes future/reversed responses and prevents order/GMV fanout.
- Dispatch fixtures cover exact trigger and 48-hour boundaries, missing items, partial deadlines/seller IDs, unapproved orders, multiple sellers, short promise lead, already-delivered suppression and final canceled proxies.
- The actual loader runs twice against isolated temporary fixture files without duplicate data or audit records.

## Observed exceptions retained

The delivered-order quality query reports **8** missing delivery timestamps, **1** missing payment record and **299** payment discrepancies above R$0.01. Across all statuses there are **303** discrepancies. The reviews extension has 99,224 review/order pairs, 98,410 distinct review IDs and 98,673 distinct reviewed orders. The additional cloud evidence queries report **610** products without categories, **2** untranslated named categories, and **9** zero-valued payments (6 vouchers, 3 `not_defined`). See [order quality output](../analysis/results/snowflake/order_quality.json) and [catalogue/payment evidence](evidence/snowflake_environment.json).

These records are visible exceptions, not invented corrections. Green tests mean the stated structural, parsing, relationship and reconciliation contracts pass; they do not certify every source business field as complete or accurate.

## Reproduction and limits

Use the commands in the [README](../README.md). `scripts/record_build_evidence.py` exports selected non-secret fields from both real dbt artifacts. `scripts/compare_results.py` compares regenerated aggregate and scenario outputs, and `scripts/record_snowflake_evidence.py` records read-only environment/quality queries. Full dbt manifests and logs are generated in ignored `dbt_project/target/` and `data/`; committed evidence deliberately excludes connection credentials and session tokens.

This is one verified development run against a static public extract, not a deployed production system or executed GitHub Actions workflow. No live intervention or measured treatment effect is claimed. The dispatch worklist is a tested reference SQL query against the historical snapshot, not an operational integration; its cutoff preview is empty. Remaining business gates are live state/event quality, actual finance costs, an existing operations workflow, a costed learning budget and adequate experimental sample. The CRM fallback additionally needs contact/consent and contribution inputs.

## Assessment coverage

| Requirement | Delivered artifact |
|---|---|
| Snowflake setup, RAW load, lineage and error policy | `ingest/`, README, source/load evidence |
| Implemented normalised entities and star marts | `dbt_project/models/`, [ERDs and design reasoning](data_model.md) |
| Surrogate keys, types, duplicates, materialisations, dbt tests and column docs | SQL models, macros, `schema.yml`, unit fixtures |
| At least three A5 query categories | Top products, monthly trends, dispatch anomalies, geography/category breakdowns in `sql/analytics_queries.sql` |
| B1-B4 insight, action, economics, measurement, caveats and memo | `analysis_answers.md`, `docs/opportunity_assessment.md`, executable calculations and charts |
| Optional B5 and productionisation discussion | Governed LLM proposal in B5; [Part C discussion](productionisation.md) |
| Pinned dependencies, credential example and reproducibility | Requirements/lock files, `profiles.yml.example`, README |
| Small commits and a feature PR to main | Repository history and [assessment PR #1](https://github.com/michaela-liu1225/elio-assessment/pull/1) |
| Live explanation and extension preparation | [Walkthrough](live_walkthrough.md) |
