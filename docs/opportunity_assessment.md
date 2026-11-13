# Choosing where to act

This decision note compares three opportunities before selecting the single action in [Part B](../analysis_answers.md). All commercial amounts are BRL. [Executable scenario calculations](../scripts/evaluate_opportunities.py) use the same Q2 eligibility-flow window and save [auditable inputs/results](../analysis/results/snowflake/commercial_decision.json).

## Why this fits the client problem

Elio's [eZone engagement](https://elio.agency/work/ezone) links a trusted data foundation to carrier-cost investigation and compares acquisition, conversion, retention and win-back before selecting interventions. Its [service proposition](https://elio.agency/) connects data engineering to measurable consumer-business decisions. Those primary sources, consulted 13 November 2026, motivate an opportunity comparison and an explicit operating owner. They do not establish the economics of Olist, and none of Elio's published client uplift figures is used in this assessment's calculations.

## Priority judgement, on a 1-10 scale

Higher scores mean a stronger case for a small investigation with the current data, including better-controlled risks. They are subjective and equally weighted, not statistical estimates of ROI or interview success.

| Opportunity | Logic | Feasibility | Potential effectiveness | Risk control | Mean | Why |
|---|---:|---:|---:|---:|---:|---|
| Dispatch recovery | 8 | 6 | 6 | 7 | **6.75** | Timestamped risk signal, plausible owner and intervention; live freshness, cancellation times and cost evidence still missing. |
| No-discount repurchase reminder | 6 | 6 | 4 | 7 | **5.75** | Clear experiment design, but very low natural repeat, unknown reach/margin and modest contribution even with ambitious lift. |
| Category acquisition/merchandising | 5 | 3 | 5 | 4 | **4.25** | Sales concentration is visible, but absent exposure, conversion and unit economics make spend allocation speculative. |

Dispatch recovery is the first **validation priority**, not an unconditional rollout. If live dispatch feeds are unavailable but a consented CRM audience and positive contribution economics already exist, the feasibility ranking reverses. Geography/seller heterogeneity, canceled orders and monthly variation prevent causal interpretation of the historical risk gap.

## Comparable quarterly economics

The previous 5,718-person CRM backlog is a single historical cutoff. It should not be used to make a quarterly operations intervention look artificially larger. Here CRM uses 18,058 customers becoming eligible during Q2, of whom an assumed 50% (9,029) are reachable; operations uses 679 Q2 trigger-date proxy alerts. Both carry the same **illustrative R$500 setup allowance** for comparison; real setup costs can differ.

| Scenario, not forecast | Before setup | After R$500 setup |
|---|---:|---:|
| Dispatch: no late-rate improvement; R$0.50 per alert | -R$340 | -R$840 |
| Dispatch: -5 percentage points; R$30 avoided cost per prevented late delivery | R$505 | R$5 |
| Dispatch: -10 points; R$30 avoided cost | R$1,350 | R$850 |
| CRM: +0.50 points purchase probability; 50% reach, 10% contribution, R$0.02 per message | R$443 | -R$57 |
| CRM: +1.00 point, otherwise same assumptions | R$1,066 | R$566 |
| Category promotion | **Not estimable** | **Not estimable** |

The CRM Q2 natural repeat rate is 63/18,058 = 0.349%, so +0.50 points implies roughly 2.4 times the natural rate. Its 67 subsequent orders average R$138.03 merchandise value; incremental buyers need not spend the same amount. The CRM formula is `reachable × absolute lift × order value × contribution − all message costs − setup`. Contribution means after non-marketing variable costs; it is not a reported marketplace take rate.

The dispatch scenarios apply avoided failures only to the **563 assessable delivered orders**, while charging all **679 proxy alerts**. This avoids valuing every flagged order as a loss, but it cannot remove bias from unknown cancellations or missing event histories. The R$103,412 merchandise GMV attached to assessable alerts is not counted as recoverable revenue. Savings must be genuinely avoidable costs documented by finance; fixed overhead allocations and speculative repeat-purchase/LTV benefits are excluded.

## What would change the decision?

| Avoidable cost per prevented late delivery | Dispatch net at -5 points | Dispatch net at -10 points |
|---|---:|---:|
| R$10 | -R$558 | -R$277 |
| R$30 | R$5 | R$850 |
| R$50 | R$568 | R$1,976 |

At the ten-point dispatch / half-point CRM assumptions and equal setup budgets, dispatch overtakes CRM only above about **R$13.89 avoidable cost per prevented late delivery**. Dispatch itself breaks even above **R$14.91**, or **R$29.82** at a five-point improvement. A higher actual CRM contribution rate, larger reachable audience, lower CRM setup cost, or expensive manual dispatch handling can reverse the ranking. No positive ROI forecast is warranted until these inputs are checked.

## Minimum inputs before spending

Operations supplies original deadline history, current order/cancellation events, carrier-event arrival time, seller contacts and an existing task queue. Finance supplies net credits/refunds, support handling time, incremental carrier costs and the true setup budget. The pilot needs assignment and intervention logs at order/seller grain, including suppressed tasks and missing outcomes. These are proposed integrations; they are not silently assumed to exist in the public dataset.

If those inputs require a bespoke build whose cost exceeds the small plausible benefit, stop. The commercial skill demonstrated here is choosing and bounding the next decision, not inventing a large opportunity to justify a technology project.
