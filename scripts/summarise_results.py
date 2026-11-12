"""Create auditable decision scenarios and a standalone chart from SQL results."""
import argparse
import json
import math
from pathlib import Path
from statistics import NormalDist

ROOT = Path(__file__).resolve().parents[1]


def wilson(successes, total, z=1.96):
    p = successes / total
    denominator = 1 + z*z/total
    centre = (p + z*z/(2*total)) / denominator
    half = z * math.sqrt(p*(1-p)/total + z*z/(4*total*total)) / denominator
    return [centre-half, centre+half]


def sample_per_arm(p0, uplift):
    """Normal approximation; two-sided alpha 5%, power 80%, equal allocation."""
    p1 = p0 + uplift
    mean = (p0+p1)/2
    z_alpha, z_power = NormalDist().inv_cdf(.975), NormalDist().inv_cdf(.8)
    numerator = z_alpha*math.sqrt(2*mean*(1-mean)) + z_power*math.sqrt(p0*(1-p0)+p1*(1-p1))
    return math.ceil(numerator*numerator/(uplift*uplift))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--target', choices=['local', 'snowflake'], default='local')
    args = parser.parse_args()
    source = ROOT / 'analysis/results' / args.target
    read = lambda name: json.loads((source / f'{name}.json').read_text())
    retention, baseline, audience = (read(name)[0] for name in
                                     ['retention_overall', 'activation_baseline', 'activation_audience'])
    reachable = int(audience['candidate_customers'] * .5)
    aov = baseline['subsequent_order_aov']
    assumptions = {'reachable_share': .5, 'net_contribution_rate_before_marketing': .10,
                   'contact_cost_brl': .02, 'illustrative_uplifts_absolute': [0, .0025, .005, .01],
                   'coupon_comparison_brl': 10, 'fixed_costs': 'excluded; must be costed before launch'}
    scenarios = []
    for uplift in assumptions['illustrative_uplifts_absolute']:
        incremental_orders = reachable * uplift  # one order per incremental converting buyer
        gmv = incremental_orders * aov
        contribution = gmv * .10
        contact_cost = reachable * .02
        coupon_cost = reachable * (baseline['repeat_rate'] + uplift) * 10
        scenarios.append({'uplift_absolute': uplift, 'reachable_customers': reachable,
                          'incremental_orders': incremental_orders, 'incremental_gmv_brl': gmv,
                          'net_contribution_before_fixed_costs_brl': contribution-contact_cost,
                          'with_brl10_coupon_brl': contribution-contact_cost-coupon_cost})
    metrics = {'engine': args.target, 'cutoff': '2018-08-31', 'retention': retention,
               'retention_95pct_wilson': wilson(retention['repeat_customers'], retention['customers']),
               'activation_baseline': baseline,
               'activation_baseline_95pct_wilson': wilson(baseline['repeat_customers'], baseline['eligible_customers']),
               'audience': audience, 'assumptions': assumptions, 'scenarios': scenarios,
               'sample_per_arm_at_0_5_percentage_point_uplift': sample_per_arm(baseline['repeat_rate'], .005),
               'breakeven_uplift_before_fixed_costs': .02/(aov*.10)}
    (source / 'decision_metrics.json').write_text(json.dumps(metrics, indent=2)+'\n')

    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.ticker import PercentFormatter, FuncFormatter
    rows = read('monthly_retention')
    p = [r['repeat_rate'] for r in rows]
    cis = [wilson(r['repeat_customers'], r['customers']) for r in rows]
    fig, axes = plt.subplots(2, 1, figsize=(11, 7), gridspec_kw={'height_ratios': [3, 1]}, sharex=True)
    fig.patch.set_facecolor('#fafaf7')
    for ax in axes:
        ax.set_facecolor('#fafaf7')
        ax.spines[['top', 'right']].set_visible(False)
        ax.grid(axis='y', alpha=.15)
    x = list(range(len(rows)))
    axes[0].errorbar(x, p, yerr=[[v-lo for v,(lo,hi) in zip(p,cis)],
                               [hi-v for v,(lo,hi) in zip(p,cis)]],
                     fmt='o-', color='#185d71', capsize=3, linewidth=1.6)
    axes[0].yaxis.set_major_formatter(PercentFormatter(1))
    axes[0].set_ylabel('Customers with a second purchase date within 60 days')
    axes[0].set_title('Observed repeat purchase is low across mature cohorts', loc='left', fontsize=17, pad=18)
    axes[0].text(0, 1.02, 'Distinct shopping dates; delivered orders; 95% Wilson intervals',
                 transform=axes[0].transAxes, fontsize=10, color='#555555')
    axes[1].bar(x, [r['customers'] for r in rows], color='#b0c8cf')
    axes[1].set_ylabel('Customers')
    axes[1].yaxis.set_major_formatter(FuncFormatter(lambda v,p: f'{v/1000:.0f}k'))
    axes[1].set_xticks(x, [str(r['cohort_month'])[:7] for r in rows], rotation=45, ha='right')
    axes[1].set_xlabel('First observed delivered purchase month')
    fig.text(.08,.015,f'Olist public dataset | cutoff 2018-08-31 | partial cohort months excluded | executed on {args.target}',
             fontsize=9, color='#555555')
    fig.tight_layout(rect=[0,.035,1,1])
    output = ROOT / 'analysis/figures'
    output.mkdir(parents=True,exist_ok=True)
    fig.savefig(output/f'retention_cohorts_{args.target}.png',dpi=180)
    plt.close(fig)
    print(json.dumps(metrics,indent=2))


if __name__ == '__main__':
    main()
