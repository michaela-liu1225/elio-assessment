"""Compare three decisions on a common quarterly flow, with labelled assumptions.

No observed GMV is counted as recoverable revenue. Operational savings require
finance-verified avoidable costs; historical associations are not causal effects.
"""
import argparse
import json
import math
from pathlib import Path

from summarise_results import sample_per_arm, wilson

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', choices=['local', 'snowflake'], required=True)
    args = parser.parse_args()
    directory = ROOT / 'analysis/results' / args.target
    read = lambda name: json.loads((directory / f'{name}.json').read_text())
    groups = {r['is_historical_alert']: r for r in read('dispatch_quarter')}
    alert, comparator = groups[True], groups[False]
    statuses = read('dispatch_status')
    workload = sum(r['proxy_alerts'] for r in statuses)
    handovers = sum(r['handovers_next_48h'] for r in statuses)
    activation = read('activation_quarter')[0]
    reachable = math.floor(activation['eligible_customers'] * .5)
    fixed_cost, cost_per_alert, avoided_cost = 500, .5, 30
    scenarios = []
    for reduction in [0, .05, .10]:
        avoided = alert['orders'] * reduction
        savings = avoided * avoided_cost
        handling = workload * cost_per_alert
        scenarios.append({'absolute_late_rate_reduction': reduction,
                          'avoided_late_deliveries': avoided,
                          'gross_avoidable_cost_brl': savings,
                          'all_proxy_alert_handling_cost_brl': handling,
                          'net_before_setup_brl': savings - handling,
                          'net_after_setup_brl': savings - handling - fixed_cost})
    crm_scenarios = []
    for lift in [0, .0025, .005, .01]:
        orders = reachable * lift
        gmv = orders * activation['subsequent_order_aov']
        net = gmv * .10 - reachable * .02
        crm_scenarios.append({'absolute_purchase_probability_lift': lift,
                              'incremental_orders': orders, 'incremental_gmv_brl': gmv,
                              'net_before_setup_brl': net, 'net_after_setup_brl': net-fixed_cost})

    states = {}
    for row in read('dispatch_geography'):
        states.setdefault(row['delivery_state'], {})[row['is_historical_alert']] = row
    shared = [rows for rows in states.values() if True in rows and False in rows]
    common_alert_count = sum(rows[True]['orders'] for rows in shared)
    adjusted_control = sum(rows[True]['orders'] * rows[False]['late_orders'] / rows[False]['orders']
                           for rows in shared) / common_alert_count
    cluster_factor = 1.25  # planning sensitivity only; estimate intraclass correlation in shadow mode
    late_n = sample_per_arm(alert['late_rate'], -.10)
    dispatch_n = sample_per_arm(handovers/workload, .15)
    metrics = {
        'engine': args.target, 'flow_window': ['2018-04-01', '2018-06-30'],
        'dispatch_delivered_baseline': alert, 'dispatch_comparator': comparator,
        'late_rate_95pct_wilson': wilson(alert['late_orders'], alert['orders']),
        'all_status_proxy_workload': workload,
        'unassessable_or_not_delivered_proxy_alerts': workload-alert['orders'],
        'dispatch_48h_planning_rate_all_statuses': handovers/workload,
        'state_standardised_comparator': {'states': len(shared), 'common_alert_orders': common_alert_count,
                                          'rate': adjusted_control, 'causal': False},
        'assumptions': {'avoidable_cost_per_prevented_late_delivery_brl': avoided_cost,
                        'cost_per_proxy_alert_brl': cost_per_alert,
                        'one_time_setup_budget_brl': fixed_cost,
                        'dispatch_absolute_reductions': [0, .05, .10],
                        'crm_reachable_share': .5, 'crm_contribution_rate': .10,
                        'crm_message_cost_brl': .02,
                        'warning': 'All financial inputs and treatment effects are assumptions, not observed results.'},
        'dispatch_scenarios': scenarios, 'crm_quarter_baseline': activation,
        'crm_reachable_customers': reachable, 'crm_scenarios': crm_scenarios,
        'break_even_avoidable_cost_at_10pp_brl': (workload*cost_per_alert+fixed_cost)/(alert['orders']*.10),
        'break_even_avoidable_cost_at_5pp_brl': (workload*cost_per_alert+fixed_cost)/(alert['orders']*.05),
        'break_even_absolute_reduction_at_brl30': (workload*cost_per_alert+fixed_cost)/(alert['orders']*avoided_cost),
        'dispatch_cost_to_equal_crm_0_5pp_scenario_brl': (crm_scenarios[2]['net_before_setup_brl']+workload*cost_per_alert)/(alert['orders']*.10),
        'sample_size': {'alpha_two_sided': .05, 'power': .80,
                        'assumed_cluster_design_effect': cluster_factor,
                        'dispatch_48h_15pp_per_arm_independent': dispatch_n,
                        'dispatch_48h_15pp_total_with_design_effect': math.ceil(2*dispatch_n*cluster_factor),
                        'late_10pp_per_arm_independent': late_n,
                        'late_10pp_total_with_design_effect': math.ceil(2*late_n*cluster_factor),
                        'expected_proxy_alerts_over_10_weeks': workload/13*10,
                        'warning': 'Normal approximation and assumed design effect; validate actual eligibility, ICC and cluster sizes before randomisation.'},
        'cost_sensitivity_after_setup': [
            {'avoidable_cost_brl': cost, 'absolute_reduction': delta,
             'net_brl': alert['orders']*delta*cost-workload*cost_per_alert-fixed_cost}
            for cost in [10,30,50] for delta in [.05,.10]],
    }
    (directory/'commercial_decision.json').write_text(json.dumps(metrics,indent=2)+'\n')

    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.ticker import PercentFormatter
    fig, axes = plt.subplots(1, 2, figsize=(12, 5.2), gridspec_kw={'width_ratios':[1,1.55]})
    fig.patch.set_facecolor('#fafaf7')
    for ax in axes:
        ax.set_facecolor('#fafaf7'); ax.spines[['top','right']].set_visible(False)
        ax.grid(axis='y',alpha=.15); ax.set_axisbelow(True)
        ax.yaxis.set_major_formatter(PercentFormatter(1))
    labels = ['Handover already\nobserved', 'No handover\n24h after deadline']
    vals = [comparator['late_rate'], alert['late_rate']]
    axes[0].bar(labels, vals, color=['#9caeb1','#bb603d'],width=.62)
    for i,row in enumerate([comparator,alert]):
        axes[0].text(i, row['late_rate']+.013, f"{row['late_rate']:.1%}\n{row['late_orders']:,}/{row['orders']:,}", ha='center', fontsize=10)
    axes[0].set_ylim(0,.40); axes[0].set_ylabel('Late delivery rate')
    axes[0].set_title('Q2 trigger cohort',loc='left',fontsize=13,pad=14)
    rows = read('dispatch_monthly')
    for flag,color,label in [(True,'#bb603d','Missing handover at trigger'),(False,'#718b91','Handover observed by trigger')]:
        subset=[r for r in rows if r['is_historical_alert']==flag]
        axes[1].plot([r['trigger_month'][:7] for r in subset],[r['late_rate'] for r in subset],
                     'o-',color=color,label=label,linewidth=1.7)
    axes[1].set_ylim(0,.55); axes[1].set_title('The relationship persists; baseline varies sharply',loc='left',fontsize=13,pad=14)
    axes[1].legend(frameon=False,fontsize=9,loc='upper left')
    axes[1].tick_params(axis='x',labelrotation=35)
    fig.suptitle('A dispatch exception is a useful risk signal',fontsize=18,x=.075,ha='left',y=.99)
    fig.text(.075,.07,'Single-seller orders; valid dispatch context; mature, observed deliveries only. Descriptive association, not intervention lift.',fontsize=9,color='#555555')
    fig.text(.075,.035,f'Olist public dataset | cutoff 2018-08-31 | executed on {args.target} | all-status workload is costed separately',fontsize=9,color='#555555')
    fig.tight_layout(rect=[.02,.12,1,.92])
    fig.savefig(ROOT/f'analysis/figures/dispatch_risk_{args.target}.png',dpi=180)
    plt.close(fig)
    print(json.dumps(metrics,indent=2))


if __name__ == '__main__':
    main()
