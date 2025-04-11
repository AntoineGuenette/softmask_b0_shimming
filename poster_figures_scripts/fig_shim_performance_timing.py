import matplotlib.pyplot as plt
import numpy as np

def plot_shimming_performance_and_timing(data_dict, save_path=None):
    """
    Plot comparison of shimming performance (mean, std, rmse) and mask conversion time
    for different softmasking methods. Styled for poster with French labels and color theme.
    """

    # --- Color palette ---
    colors = {
        'masque\nbinaire': '#234E70',  # navy blue
        'constant': '#D4AF37',         # gold
        'linéaire': '#D4AF37',         # gold
        'gaussien': '#D4AF37',         # gold
        'somme': '#D4AF37',            # gold
        'masques\ncontinus': '#8B1E3F', # bordeaux
    }

    bg_color = '#E3E3E3'
    text_color = '#0D1B2A'

    # Compute and insert averaged "Masques continus"
    softmask_keys = ['constant', 'linéaire', 'gaussien', 'somme']
    if all(k in data_dict for k in softmask_keys):
        mean_metrics = {metric: np.mean([data_dict[k][metric] for k in softmask_keys]) for metric in ['mean', 'std', 'rmse', 'time']}
        data_dict['masques\ncontinus'] = mean_metrics

    methods = list(data_dict.keys())
    time_methods = ['constant', 'linéaire', 'gaussien', 'somme']
    metrics = ['mean', 'std', 'rmse']

    # Extract precomputed percentage improvements and times
    improvements_pct = np.array([[data_dict[m][metric] for metric in metrics] for m in methods])
    times = [data_dict[m]['time'] for m in methods]

    x = np.arange(len(metrics))
    width = 0.12

    fig = plt.figure(figsize=(20, 9), facecolor=bg_color)
    gs = fig.add_gridspec(1, 2, width_ratios=[2.5, 1])
    ax1 = fig.add_subplot(gs[0])
    ax2 = fig.add_subplot(gs[1])
    fig.subplots_adjust(wspace=0.2)

    # --- Left: Improvement percentages ---
    for i, method in enumerate(methods):
        offset = (i - len(methods)/2) * width + width/2
        method_color = colors.get(method.lower(), '#CCC')
        bars = ax1.bar(x + offset, improvements_pct[i], width,
                       label=method.capitalize(),
                       color=method_color)

        for j, bar in enumerate(bars):
            ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
                     f"{improvements_pct[i, j]:.1f}%", ha='center', va='bottom',
                     fontsize=11, rotation=90, color='#555')

    ax1.set_title("Amélioration de l'homogénétié \ndu champ magnétique", fontsize=20, color=text_color, pad=10)
    ax1.set_ylabel("Amélioration (%)", fontsize=16, color=text_color)
    ax1.set_xticks(x)
    ax1.set_xticklabels(['Moyenne', 'Écart-type', 'RMSE'], fontsize=16, color=text_color)
    ax1.legend(frameon=False, fontsize=12)
    ax1.set_facecolor(bg_color)
    ax1.spines[['top', 'right']].set_visible(False)
    ax1.grid(axis='y', linestyle='--', linewidth=0.5, color='#DDD')

    # Apply broken y-axis from 30% to 100%
    ax1.set_ylim(30, 100)
    ax1.spines['bottom'].set_visible(False)
    ax1.tick_params(bottom=False)

    # --- Right: Timing in seconds ---
    timing_methods = [m for m in methods if m not in ['segmentation', 'masque\nbinaire']]
    x2 = np.arange(len(timing_methods))
    bars2 = ax2.bar(x2,
                     [data_dict[m]['time'] for m in timing_methods],
                     width=5*width,
                     color=[colors.get(m.lower(), '#CCC') for m in timing_methods])

    for i, bar in enumerate(bars2):
        ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01,
                 f"{[data_dict[m]['time'] for m in timing_methods][i]:.2f}s", ha='center', va='bottom', fontsize=11, rotation=90, color='#555')

    ax2.set_title("Temps de conversion \ndes masques", fontsize=20, color=text_color, pad=10)
    ax2.set_ylabel("Temps (s)", fontsize=16, color=text_color)
    ax2.set_xticks(x2)
    ax2.set_xticklabels([m.capitalize() for m in timing_methods], fontsize=16, rotation=90, color=text_color)
    ax2.set_facecolor(bg_color)
    ax2.spines[['top', 'right']].set_visible(False)
    ax2.grid(axis='y', linestyle='--', linewidth=0.5, color='#DDD')

    # fig.suptitle("Comparaison des performances de shimming et du coût de conversion", fontsize=16, color=text_color, y=1.02)

    # Export
    if save_path:
        fig.savefig(f"{save_path}.svg", format='svg', bbox_inches='tight', facecolor=bg_color)
        fig.savefig(f"{save_path}.png", dpi=300, bbox_inches='tight', facecolor=bg_color)

    plt.show()


if __name__ == "__main__":
    data = {
    'segmentation': {'mean': 99.98, 'std': 89.54, 'rmse': 89.73, 'time': 40.656},
    'masque\nbinaire': {'mean': 96.41, 'std': 80.65, 'rmse': 80.89, 'time': 3.138},
    'constant': {'mean': 88.67, 'std': 82.64, 'rmse': 82.73, 'time': 8.664},
    'linéaire': {'mean': 85.57, 'std': 81.61, 'rmse': 81.71, 'time': 2.764},
    'gaussien': {'mean': 36.25, 'std': 76.33, 'rmse': 75.48, 'time': 8.835},
    'somme': {'mean': 52.90, 'std': 81.12, 'rmse': 80.41, 'time': 4.677},
    }


    output_path = "/Users/antoineguenette/Desktop/figures_affiche/figure_shimming_performance_timing"
    plot_shimming_performance_and_timing(data, save_path=output_path)
