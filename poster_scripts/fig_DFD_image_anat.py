import nibabel as nib
import numpy as np
import matplotlib.pyplot as plt

# Path to save figures
save_path = '/Users/antoineguenette/Desktop/figures_affiche/fig_DFD_image_anat'

# Load MPRAGE image
nii_mp_rage = nib.load('/Users/antoineguenette/Documents/projet_III/data/sub-acdc262/sub-acdc262/anat/sub-acdc262_T1w.nii.gz')
mp_rage = nii_mp_rage.get_fdata()

# Create sagittal slice
sagittal_slice = mp_rage[87, :, :]

# Create figure
plt.figure(figsize=(12, 12))
plt.imshow(np.rot90(sagittal_slice), cmap='gray')
plt.xticks([])
plt.yticks([])

# Increase brightness by scaling pixel values
brightened_slice = np.clip(sagittal_slice * 1.5, 0, np.max(sagittal_slice))

# Update the displayed image
plt.imshow(np.rot90(brightened_slice), cmap='gray')

# Save figure
plt.savefig(f"{save_path}.png", dpi=300, bbox_inches='tight', facecolor='#E3E3E3')
plt.savefig(f"{save_path}.svg", format='svg', bbox_inches='tight', facecolor='#E3E3E3')