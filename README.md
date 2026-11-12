# Olist: a trustworthy foundation for a measured retention decision

This Elio assessment turns six uncleaned commerce files into tested dbt entities and marts, then evaluates a second-purchase campaign. The recommendation is a capped, no-discount reminder experiment with an explicit spending gate, not an assumed revenue uplift.

**Verified:** Snowflake loading and `dbt build` pass: **17 models, 89 data tests and 5 unit tests**, with no failures or warnings. All **nine analytical outputs match** local execution; **five Python tests pass**. See [actual execution evidence](docs/verification.md).

Read [the client analysis and memo](analysis_answers.md), [the data model](docs/data_model.md), and [verification evidence](docs/verification.md).

## Environment

Snowflake is the primary warehouse, following the brief. DuckDB is an additional regression target, never a substitute for a claimed Snowflake run.

| Setting | Default / status |
|---|---|
| Trial | Enterprise, AWS Europe (London); actual activated trial |
| Warehouse | `ELIO_ASSESSMENT_WH`, X-Small, auto-suspend 60 seconds, auto-resume |
| Database | `ELIO_ASSESSMENT` |
| Schemas | `RAW`, `DEV_STAGING`, `DEV_CONFORMED`, `DEV_MARTS` |
| Role | `SYSADMIN` for isolated trial bootstrap; production roles discussed separately |
| Python | 3.12; developed on 3.12.14 |
| dbt Core / Snowflake adapter | 1.12.7 / 1.12.5 |
| Snowflake connector | 4.8.0 |
| Local adapter / engine | dbt-duckdb 1.11.1 / DuckDB 2.0.0 |
| Analysis | Cutoff 2018-08-31; 60-day window; cohorts start 2017-01-01 |

## Setup

Run from the repository root:

```bash
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install -c requirements-lock.txt -r requirements-dev.txt
mkdir -p .profiles
cp profiles.yml.example .profiles/profiles.yml
python ingest/download_data.py
```

`requirements.txt` contains the minimal pinned Snowflake dependencies; the development file adds local validation and plots. The lock file records the complete tested environment. No third-party dbt packages are needed: the empty `packages.yml` means `dbt deps` reports no packages to install.

The download script uses the publisher's public Kaggle endpoint and validates six exact headers, UTF-8 and record widths. If the endpoint requires login or is unavailable, download the original archive from [Olist on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), place unchanged CSVs in `data/raw/`, and compare hashes with [the recorded manifest](docs/source_manifest.json). Raw data is excluded from Git.

## Snowflake load and dbt build

Activate the trial and select a role allowed to create the isolated assessment database/warehouse, or have an administrator pre-create them. Export connection settings; keep credentials in ignored files or environment variables.

```bash
export SNOWFLAKE_ACCOUNT='your_organisation-your_account'
export SNOWFLAKE_USER='your_user'
export SNOWFLAKE_ROLE='SYSADMIN'
export SNOWFLAKE_DATABASE='ELIO_ASSESSMENT'
export SNOWFLAKE_WAREHOUSE='ELIO_ASSESSMENT_WH'
export SNOWFLAKE_AUTHENTICATOR='OAUTH_AUTHORIZATION_CODE'
export DBT_SCHEMA='DEV'

python ingest/load_raw.py --target snowflake --bootstrap
cd dbt_project
dbt debug --profiles-dir ../.profiles --target dev
dbt deps --profiles-dir ../.profiles --target dev
dbt build --profiles-dir ../.profiles --target dev --target-path target/snowflake
cd ..
python scripts/run_analysis.py --target snowflake
python scripts/summarise_results.py --target snowflake
python scripts/record_snowflake_evidence.py
```

The loader creates fully qualified raw tables, a file format and an internal stage, uploads with `PUT`, then runs `COPY INTO`. It captures filename, source row number, file hash and load time. Strict preflight, `ON_ERROR=ABORT_STATEMENT`, per-file transactions and audit/count checks prevent silent partial loads and duplicated reruns. See [ingestion decisions](ingest/README.md).

`--bootstrap` creates objects only if absent. It does not resize or repair configuration drift in existing objects; verify their warehouse size/auto-suspend if reusing a name. `SYSADMIN` is convenient for a new isolated trial, not the proposed production service role.

The development profile uses [Snowflake OAuth for local applications](https://docs.snowflake.com/en/user-guide/oauth-local-applications), which supports the trial's Google/OIDC login without creating a client secret. Set `SNOWFLAKE_USER` to the actual Snowflake username, which may differ from the email login alias. A successful Snowsight sign-in does not itself authenticate a CLI. `externalbrowser` is an alternative only for accounts with a configured SAML identity provider; it is not the Google/OIDC login method. For key-pair authentication, use the example `ci` target and set `SNOWFLAKE_PRIVATE_KEY_PATH` plus the optional `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`; the loader supports these variables too. The account owner must register the key. Never commit a password, private key, token, actual `profiles.yml` or `.env`.

The query runner defaults to `ELIO_ASSESSMENT.DEV_MARTS`; pass `--database NAME --schema TARGET_MARTS` for other identifiers. Snowflake runs save query IDs in `analysis/results/snowflake/execution_metadata.json`. The analytical dates/windows are fixed for this assessment: regenerate SQL filters, results and the narrative if changing them.

Interactive development uses one dbt thread to avoid overlapping Google authorization flows on the first login; the key-pair CI example retains four threads. The Snowflake SDK/dbt can reuse temporary credentials through their local credential cache; the tested macOS environment uses Keychain. Credentials are never copied into the project or Git.

## Local reproduction and regression checks

```bash
python ingest/load_raw.py --target local
python ingest/load_raw.py --target local  # second run skips committed files
pytest -q tests
cd dbt_project
dbt deps --profiles-dir ../.profiles --target local
dbt build --profiles-dir ../.profiles --target local --target-path target/local
cd ..
python scripts/run_analysis.py --target local
python scripts/summarise_results.py --target local
python scripts/compare_results.py  # after both engines' analysis outputs exist
```

The same dbt models run locally; small type/date/parser macros differ by adapter. SQLGlot translates Snowflake analytics syntax for the local runner. Engine-labelled outputs distinguish local execution from real Snowflake evidence.

Offline Snowflake compilation is also possible without an account login:

```bash
cd dbt_project
dbt compile --profiles-dir ../.profiles --target dev --select 'resource_type:model' \
  --no-introspect --no-populate-cache --target-path target/snowflake_compile
```

Compilation does not prove warehouse permissions, `PUT`/`COPY` or Snowflake runtime behaviour.

## Model and quality decisions

RAW preserves source strings; staging uses decimals, integers and timestamps. Keys, relationships, malformed non-empty values, status values and additive amount/row conservation are tested. Business fixtures cover payment fanout, missing versus zero values, delivery on the promised date, missing estimates/reversed delivery dates, unknown timeliness, same-day split orders, a repeat exactly on day 60, immature cohorts, in-flight suppression, future purchases and fractional item sequences. Python tests cover BOM/Portuguese handling, malformed CSV/UTF-8, identifier validation and actual loader idempotency.

Staging/conformed models are views and marts are full-refresh tables. The small static extract lacks reliable update events, so incremental loading or SCD2 history would require unsupported assumptions. Missing payment/delivery components, payment discrepancies and unknown/untranslated categories remain visible. [The model document](docs/data_model.md) explains grains, 3NF, star denormalisation and temporal limits.

## Repository layout

```text
ingest/                     source contract, download, Snowflake/local loading
dbt_project/models/         staging, conformed entities, marts, unit fixtures
dbt_project/macros/         small compatibility and quality macros
dbt_project/tests/          conservation and cohort-window data tests
sql/analytics_queries.sql   stakeholder queries against marts
analysis_answers.md         B1-B5, including a <=200-word client memo
analysis/results/           aggregate results labelled by execution engine
analysis/figures/           reproducible cohort chart
docs/data_model.md          3NF ERD, star schema, keys/types/materialisations
docs/productionisation.md   environments, idempotency, cost and CI discussion
docs/live_walkthrough.md    presentation and technical discussion preparation
docs/verification.md        actual verification and remaining gates
tests/                     ingestion regression tests
scripts/                   SQL execution and scenario/plot calculations
profiles.yml.example        environment-based configuration without secrets
```

History separates setup, ingestion, models, analysis and validation. The feature branch is `codex/olist-assessment`; [implementation PR #1](https://github.com/michaela-liu1225/elio-assessment/pull/1) targets `main`. The original confidential assessment PDF is not committed. Raw files, environments, credentials, profiles, compiled dbt artifacts and logs are ignored.

## Scope and next steps

Streamlit, predictive LTV and an LLM implementation are omitted so the mandatory pipeline and commercial recommendation remain explainable. Production priorities are actual finance/contact/consent inputs, authoritative update events, least-privilege roles, isolated PR schemas and orchestration. See [Part C discussion](docs/productionisation.md).

AI assistance was used for implementation, drafting and edge-case review, as permitted by the brief. The candidate should run and review the submission personally and practise a live extension using [the walkthrough](docs/live_walkthrough.md). No measured campaign uplift is claimed.

Data attribution: **Olist Brazilian E-Commerce Public Dataset**, published by Olist on Kaggle, **CC BY-NC-SA 4.0**. This repository contains aggregate educational analysis and download instructions, not a redistributed data archive.
