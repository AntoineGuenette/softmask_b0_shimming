import nibabel as nib
import numpy as np
import matplotlib.pyplot as plt

# Color palette
bg_color = '#E3E3E3'
text_color = '#0D1B2A'
royal_blue = '#234E70'
bordeaux = '#8B1E3F'

# Path to save figures
save_path = '/Users/antoineguenette/Desktop/figures_affiche/fig_coupe_sagitalle_rect_axial'

# Load MPRAGE image
nii_mp_rage = nib.load('/Users/antoineguenette/Documents/projet_III/data/sub-acdc261/sub-acdc261/anat/sub-acdc261_T1w.nii.gz')
mp_rage = nii_mp_rage.get_fdata()

plt.figure(figsize=(12, 12))
plt.imshow(np.rot90(mp_rage[87, :, :]), cmap='gray')
plt.xticks([])
plt.yticks([])

# Tranches axiales 
# Max (bordeaux) : 52
# Min (royal blue) : 128



# Add red rectangle (bordeaux) at slice 52
plt.gca().add_patch(plt.Rectangle((96, 288), 15, 5, edgecolor=bordeaux, facecolor=bordeaux, linewidth=2))

# Add blue rectangle (royal blue) at slice 128
plt.gca().add_patch(plt.Rectangle((112, 188), 15, 5, edgecolor=royal_blue, facecolor=royal_blue, linewidth=2))

# Save figure
plt.savefig(f"{save_path}.svg", format='svg', bbox_inches='tight', facecolor=bg_color)
plt.savefig(f"{save_path}.png", dpi=300, bbox_inches='tight', facecolor=bg_color)
