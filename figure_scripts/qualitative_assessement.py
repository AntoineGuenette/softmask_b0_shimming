import nibabel as nib
import numpy as np
import matplotlib.pyplot as plt
from scipy.ndimage import center_of_mass
from nibabel.processing import resample_from_to
import os

def crop_center(data, center, size):
    """
    Crops a square region around the center of the data.

    Args:
        data (ndarray): 2D data to be cropped
        center (tuple): (row, col) coordinates of the center
        size (int): Size of the square region to crop
        
    Returns:
        ndarray: Cropped 2D data
    """
    row, col = center
    half_size = size // 2
    row_start = max(0, row - half_size)
    row_end = min(data.shape[0], row + half_size)
    col_start = max(0, col - half_size)
    col_end = min(data.shape[1], col + half_size)
    return data[row_start:row_end, col_start:col_end]

# Option names
options = ['Baseline', 'DynShim_SCseg', 'DynShim_bin', 'DynShim_2levels', 'DynShim_linear', 'DynShim_gauss']

# Load the data
script_dir = os.path.dirname(os.path.abspath(__file__))
EPI_PATHS = [os.path.join(script_dir, f"../../2025.05.12-acdc_274/tSNR-acdc274/{option}/EPIs/{option}_EPI_mc_mean.nii.gz") for option in options]
MASK_PATHS = [os.path.join(script_dir, f"../../2025.05.12-acdc_274/tSNR-acdc274/{option}/seg/sc_centerline.nii.gz") for option in options]

EPIs = [nib.load(EPI_PATH) for EPI_PATH in EPI_PATHS]
masks = [nib.load(MASK_PATH) for MASK_PATH in MASK_PATHS]
masks= [resample_from_to(mask, EPI, order=0) for mask, EPI in zip(masks, EPIs)]

# Get mask
masks_data = [mask.get_fdata().astype(bool) for mask in masks]
    
# Get the data
crop_size = 20
EPIs_data = [EPI.get_fdata() for EPI in EPIs]
data_crop = np.zeros((crop_size, crop_size, EPIs_data[0].shape[2]))
mosaics = []

# Crop the center of the data
for EPI_data, mask_data in zip(EPIs_data, masks_data):
    for slice in range(EPI_data.shape[-1]):
        if not np.any(mask_data[:, :, slice]):
            center = (EPI_data.shape[0] // 2, EPI_data.shape[1] // 2 - 10)
        else:
            center = center_of_mass(mask_data[:, :, slice])
        if not np.isnan(center[0]) and not np.isnan(center[1]):
            center = (int(center[0]), int(center[1]))
            data_crop[:, :, slice] = crop_center(EPI_data[:, :, slice], center, crop_size) 
    data = data_crop[:, :, ::-1]
    mosaics.append(np.concatenate([np.rot90(data[:, :, i]) for i in range(data.shape[2])], axis=1))

mosaic_repeated = np.concatenate(mosaics, axis=0)

# Save the figure
output_path = "/Users/antoineguenette/Desktop/Scolaire/NeuroPoly/Stage_E25/Experiences/2025.05.12-acdc_274/figures"
output_file = os.path.join(output_path, "all_EPIs.png")
plt.imsave(output_file, mosaic_repeated, cmap='gray', vmin=0, vmax=200)