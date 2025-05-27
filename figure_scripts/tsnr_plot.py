import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os

# Get the directory of the script being run
script_dir = os.path.dirname(os.path.abspath(__file__))
data_path = os.path.join(script_dir, '../../2025.05.12-acdc_274/tSNR-acdc274/all_tSNR_data.csv')

# Load the data that was saved previously
df_all_subjects = pd.read_csv(data_path, sep=';')

# Set up the figure and style
f, axes = plt.subplots(1, 2, figsize=(15, 8))
sns.set(style="whitegrid")

# Plot 1: tSNR per spinal level
plot1 = sns.lineplot(
    data=df_all_subjects,
    x='SpinalLevel', y='WA', hue='Condition',
    hue_order=['Baseline', 'DynShim_SCseg', 'DynShim_bin', 'DynShim_2levels', 'DynShim_linear', 'DynShim_gauss'],
    markers=True, style='Condition', dashes=False, 
    palette=['blue', 'green', 'purple', 'red', 'orange', 'brown'],
    ax=axes[0]
)
axes[0].grid(True)
axes[0].set_title("tSNR par vertèbre")

# Plot 2: tSNR improvement per spinal level
df_all_subjects["WA_improvement"] = pd.to_numeric(df_all_subjects["WA_improvement"], errors="coerce")
plot2 = sns.lineplot(
    data=df_all_subjects,
    x='SpinalLevel', y='WA_improvement', hue='Condition',
    hue_order=['DynShim_SCseg', 'DynShim_bin', 'DynShim_2levels', 'DynShim_linear', 'DynShim_gauss'],
    markers=True, style='Condition', dashes=False, 
    palette=['green', 'purple', 'red', 'orange', 'brown'],
    ax=axes[1]
)
axes[1].grid(True)
axes[1].set_title("Amélioration du tSNR par vertèbre")

f.suptitle("Comparaison du tSNR et de son amélioration pour chaque masque utilisé", fontsize=16)

axes[0].legend_.remove()
axes[1].legend_.remove()

# Set custom legend labels (same for both plots)
legend_mapping = {
    'Baseline': 'Baseline',
    'DynShim_SCseg': 'Seg',
    'DynShim_bin': 'Bin',
    'DynShim_2levels': '2lvl',
    'DynShim_linear': 'lin',
    'DynShim_gauss': 'gaus'
}
handles, labels = plot1.get_legend_handles_labels()
custom_labels = [legend_mapping.get(label, label) for label in labels]
f.legend(handles, custom_labels, title='Masque utilisé', fontsize=10, title_fontsize=12, loc='upper left')

# Save the figure
output_path = os.path.join(script_dir, "../../2025.05.12-acdc_274/figures")
output_file = os.path.join(output_path, "tSNR_plot.png")
f.savefig(output_file, dpi=300, bbox_inches='tight')
