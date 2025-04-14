import matplotlib.pyplot as plt
import numpy as np

def plot_shimming_performance_and_timing(data_dict, save_path=None):
    """
    Plot comparison of shimming performance (mean, std, rmse) and mask conversion time
    for different softmasking methods. Styled for poster with French labels and color theme.
    """

    # --- Color palette ---
    colors = {
        'segmentation_binaire':            '#8B1E3F',  # bordeaux
        'masque_binaire_cylindrique':      '#234E70',  # navy blue
        'masque_discret_a_deux_niveaux':   '#A9BCD0',  # bleu gris
        'masque_continu_lineaire':         '#A9BCD0',
        'masque_continu_gaussien':         '#A9BCD0',
        'masque_hybride_binaire_gaussien': '#A9BCD0',
        'masques\ncontinus':                 '#B08D57',  # bronze foncé
    }
     
    bg_color = '#E3E3E3'
    text_color = '#0D1B2A'

    # Compute and insert averaged "Masques continus"
    softmask_keys = ['masque_discret_a_deux_niveaux', 'masque_continu_lineaire', 'masque_continu_gaussien', 'masque_hybride_binaire_gaussien']
    if all(k in data_dict for k in softmask_keys):
        mean_metrics = {metric: np.mean([data_dict[k][metric] for k in softmask_keys]) for metric in ['mean', 'std', 'rmse', 'time']}
        data_dict['masques\ncontinus'] = mean_metrics

    methods = list(data_dict.keys())
    metrics = ['mean', 'std', 'rmse']

    # Extract precomputed percentage improvements and times
    improvements_pct = np.array([[data_dict[m][metric] for metric in metrics] for m in methods])

    x = np.arange(len(metrics))
    width = 0.12

    fig = plt.figure(figsize=(24, 12), facecolor=bg_color)
    gs = fig.add_gridspec(1, 3, width_ratios=[0.6, 2.5, 0.9])
    ax_legend = fig.add_subplot(gs[0])
    ax1 = fig.add_subplot(gs[1])
    ax2 = fig.add_subplot(gs[2])
    fig.subplots_adjust(wspace=0.20)

    # --- Legend subplot ---
    legend_labels = {
        'segmentation_binaire': 'Segmentation\nbinaire',
        'masque_binaire_cylindrique': 'Masque binaire\ncylindrique',
        'masque_discret_a_deux_niveaux': 'Masque discret\nà deux niveaux',
        'masque_continu_lineaire': 'Masque continu\nlinéaire',
        'masque_continu_gaussien': 'Masque continu\ngaussien',
        'masque_hybride_binaire_gaussien': 'Masque hybride\nbinaire-gaussien',
        'masques\ncontinus': 'Masques continus'
    }

    ax_legend.axis('off')
    legend_handles = [
        plt.Line2D([0], [0], marker='s', linestyle='None',
                   color=colors.get(key, '#CCCCCC'), label=legend_labels[key], markersize=12)
        for key in legend_labels
    ]
    ax_legend.legend(handles=legend_handles, loc='center left', fontsize=18, frameon=False)

    # --- Left: Improvement percentages ---
    for i, method in enumerate(methods):
        offset = (i - len(methods)/2) * width + width/2
        method_color = colors.get(method.lower(), '#CCCCCC')
        bars = ax1.bar(x + offset, improvements_pct[i], width,
                       label=method.capitalize(),
                       color=method_color)

        for j, bar in enumerate(bars):
            is_bold = method in ['segmentation_binaire', 'masque_binaire_cylindrique', 'masques\ncontinus']
            ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
                     f"{improvements_pct[i, j]:.1f}%",
                     ha='center', va='bottom',
                     fontsize=18,
                     fontweight='bold' if is_bold else 'normal',
                     rotation='vertical',
                     color='#0D1B2A')

    ax1.set_title("Amélioration de l'homogénétié\ndu champ magnétique", fontsize=28, fontweight='bold', color=text_color, pad=10)
    ax1.set_xticks(x)
    ax1.set_xticklabels(['Moyenne', 'Écart-type', 'RMSE'], fontsize=24, color=text_color)
    ax1.set_facecolor(bg_color)
    ax1.spines[['top', 'right']].set_visible(False)
    ax1.grid(axis='y', linestyle='--', linewidth=0.5, color='#DDD')

    # Apply broken y-axis from 70% to 100%
    ax1.set_ylim(70, 100)
    ax1.spines['bottom'].set_visible(False)
    ax1.tick_params(bottom=False)

    # --- Right: Timing in seconds ---
    timing_methods = [m for m in methods if m not in ['segmentation_binaire', 'masque_binaire_cylindrique']]
    x2 = np.arange(len(timing_methods))
    bars2 = ax2.bar(x2,
                     [data_dict[m]['time'] for m in timing_methods],
                     width=5*width,
                     color=[colors.get(m.lower(), '#CCCCCC') for m in timing_methods])

    for i, bar in enumerate(bars2):
        method_name = timing_methods[i]
        fontweight = 'bold' if method_name == 'masques\ncontinus' else 'normal'
        ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.05,
                 f"{[data_dict[m]['time'] for m in timing_methods][i]:.2f}s",
                    ha='center', va='bottom',
                    fontsize=18,
                    fontweight=fontweight,
                    rotation='horizontal',
                    color='#0D1B2A')

    ax2.set_title("Temps de conversion \ndes masques", fontsize=28, fontweight='bold', color=text_color, pad=10)
    ax2.set_xticks([])
    ax2.set_xticklabels([])
    ax2.set_facecolor(bg_color)
    ax2.spines[['top', 'right']].set_visible(False)
    ax2.grid(axis='y', linestyle='--', linewidth=0.5, color='#DDD')
    
    # Export
    if save_path:
        fig.savefig(f"{save_path}.svg", format='svg', bbox_inches='tight', facecolor=bg_color)
        fig.savefig(f"{save_path}.png", dpi=300, bbox_inches='tight', facecolor=bg_color)

    plt.show()


if __name__ == "__main__":
    data = {
    'segmentation_binaire': {'mean': 98.68, 'std': 95.62, 'rmse': 95.79, 'time': 149.030},
    'masque_binaire_cylindrique': {'mean': 98.09, 'std': 87.65, 'rmse': 88.20, 'time': 3.166},
    'masque_discret_a_deux_niveaux': {'mean': 98.54, 'std': 86.56, 'rmse': 87.04, 'time': 8.234},
    'masque_continu_lineaire': {'mean': 98.95, 'std': 86.64, 'rmse': 87.14, 'time': 2.841},
    'masque_continu_gaussien': {'mean': 90.62, 'std': 84.02, 'rmse': 84.47, 'time': 8.995},
    'masque_hybride_binaire_gaussien': {'mean': 94.70, 'std': 88.25, 'rmse': 88.64, 'time': 4.588},
    }

    output_path = "/Users/antoineguenette/Desktop/figures_affiche/figure_shimming_performance_timing"
    
    plot_shimming_performance_and_timing(data, save_path=output_path)
