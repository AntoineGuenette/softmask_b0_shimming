import nibabel as nib
import numpy as np
import matplotlib.pyplot as plt
import os

from scipy.ndimage import center_of_mass
from nibabel.processing import resample_from_to
from epi_mosaic import crop_center

# Option names
options = ['Baseline', 'DynShim_SCseg', 'DynShim_bin', 'DynShim_2levels', 'DynShim_linear', 'DynShim_gauss']
categories = ["baseline", "seg", "bin", "2lvl", "lin", "gaus"]

# Load the data
script_dir = os.path.dirname(os.path.abspath(__file__))
FMAP_PATHS = [os.path.join(script_dir, f"../../2025.05.12-acdc_274/fmap-acdc274/sub-acdc274_fmap_{category}.nii.gz") for category in categories]
EPI_PATHS = [os.path.join(script_dir, f"../../2025.05.12-acdc_274/tSNR-acdc274/{option}/EPIs/{option}_EPI_mc_mean.nii.gz") for option in options]
MASK_PATHS = [os.path.join(script_dir, f"../../2025.05.12-acdc_274/tSNR-acdc274/{option}/seg/sc_centerline.nii.gz") for option in options]

FMAPs = [nib.load(FMAP_PATH) for FMAP_PATH in FMAP_PATHS]
EPIs = [nib.load(EPI_PATH) for EPI_PATH in EPI_PATHS]
masks = [nib.load(MASK_PATH) for MASK_PATH in MASK_PATHS]
masks = [resample_from_to(mask, EPI, order=0) for mask, EPI in zip(masks, EPIs)]
FMAPs = [resample_from_to(FMAP, EPI, order=0) for FMAP, EPI in zip(FMAPs, EPIs)]

# Get mask
masks_data = [mask.get_fdata().astype(bool) for mask in masks]
    
# Get the data
FMAPs_data = [FMAP.get_fdata() for FMAP in FMAPs]

# Initialize crop size and mosaic list
crop_size = 20
mosaics = []

# Crop the center of the data
for FMAP_data, mask_data in zip(FMAPs_data, masks_data):
    data_crop = np.zeros((crop_size, crop_size, FMAPs_data[0].shape[2]))

    for slice in range(FMAP_data.shape[-1]):
        if not np.any(mask_data[:, :, slice]):
            center = (FMAP_data.shape[0] // 2, FMAP_data.shape[1] // 2 - 10)
        else:
            center = center_of_mass(mask_data[:, :, slice])
        if not np.isnan(center[0]) and not np.isnan(center[1]):
            center = (int(center[0]), int(center[1]))
            data_crop[:, :, slice] = crop_center(FMAP_data[:, :, slice], center, crop_size) 
    data = data_crop[:, :, ::-1]
    mosaics.append(np.concatenate([np.rot90(data[:, :, i]) for i in range(data.shape[2])], axis=1))

mosaic_repeated = np.concatenate(mosaics, axis=0)

# Save the figure
output_path = os.path.join(script_dir, "../../2025.05.12-acdc_274/figures")
output_file = os.path.join(output_path, "fmap_mosaic.png")
plt.imsave(output_file, mosaic_repeated, cmap='bwr', vmin=-100, vmax=100)