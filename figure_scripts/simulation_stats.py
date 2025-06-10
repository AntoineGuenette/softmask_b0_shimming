import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import pytesseract
import os
import re

from PIL import Image, ImageEnhance, ImageOps

# Option names
options = ['segmentation', 'sct_bin_mask',
           'st_soft_mask_2lvls', 'st_soft_mask_linear', 'st_soft_mask_gauss']

# Define the paths to the images
script_path = os.path.dirname(os.path.abspath(__file__))
subject_path = os.path.join(script_path, "../../2025.05.12-acdc_274-TESTS")
optimization_path = os.path.join(subject_path, 'sub-acdc274', 'derivatives', 'optimizations')
image_paths = [os.path.join(optimization_path, f'dynamic_shim_{option}', 'fig_shimmed_vs_unshimmed.png') for option in options]

all_before_stats = []
all_after_stats = []

for image_path, option in zip(image_paths, options):
    # Open the image and convert it to grayscale
    image = Image.open(image_path)
    gray_image = ImageOps.grayscale(image)
    enhanced_image = ImageEnhance.Contrast(gray_image).enhance(2.0)

    # Define the boxes for cropping
    before_box = (80, 100, 520, 220)
    after_box = (680, 100, 1120, 220)
    before_crop = enhanced_image.crop(before_box)
    after_crop = enhanced_image.crop(after_box)

    # Exctract text from the cropped images
    before_text = pytesseract.image_to_string(before_crop)
    after_text = pytesseract.image_to_string(after_crop)

    # Get the data from the text
    def extract_stats(text, option):
        stats = {"option": option, "std": None, "mean": None, "mae": None, "rmse": None}
        pattern = r"std[:=]?\s*([-+]?\d*\.?\d+)[,\s]+mean[:=]?\s*([-+]?\d*\.?\d+)[,\s]+mae[:=]?\s*([-+]?\d*\.?\d+)[,\s]+rmse[:=]?\s*([-+]?\d*\.?\d+)"
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            stats["std"], stats["mean"], stats["mae"], stats["rmse"] = map(float, match.groups())
        return stats
    before_stats = extract_stats(before_text, option)
    after_stats = extract_stats(after_text, option)

    # Append the stats to the lists
    all_before_stats.append(before_stats)
    all_after_stats.append(after_stats)

# Convert the lists to DataFrames
df = pd.DataFrame(all_after_stats)
metrics = ["std", "mae", "rmse"]
x = np.arange(len(df))

bar_width = 0.2
fig, ax = plt.subplots(figsize=(10, 6))

for i, metric in enumerate(metrics):
    values = df[metric].values
    positions = x + i * bar_width
    bars = ax.bar(positions, values, width=bar_width, label=metric)
    for bar in bars:
        height = bar.get_height()
        ax.annotate(f'{height:.1f}',
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 3),
                    textcoords="offset points",
                    ha='center', va='bottom')

ax.set_xticks(x + bar_width * (len(metrics) - 1) / 2)
masks = ['Segmenation', 'Binaire', 'Pondéré 2 niveaux',
         'Pondéré linéare', 'Pondéré gaussien']
ax.set_xticklabels(masks, rotation=45)
ax.set_ylabel("Valeur")
ax.set_title("Comparaison des statistiques (non pondéré) de simulation après shimming pour chaque méthode")
ax.legend()

# Save the figure
output_path = os.path.join(subject_path, "figures")
output_file = os.path.join(output_path, "simulation_stats_non_weighted.png")
plt.savefig(output_file, dpi=300, bbox_inches='tight')