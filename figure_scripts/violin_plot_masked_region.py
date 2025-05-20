import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
import nibabel as nib
from shimmingtoolbox.masking.mask_utils import resample_mask
import pandas as pd
import os

def load_subject_data(subject_paths, name):
    mask_imgs = [nib.load(mask_path) for mask_path in subject_paths["mask_paths"]]
    fm_imgs = [nib.load(fm_path) for fm_path in subject_paths["fm_paths"]]
    
    # resample mask to fm resolution
    mask_imgs = [resample_mask(mask_img, fm_img) for mask_img, fm_img in zip(mask_imgs, fm_imgs)]
    
    # Replace 0 with NaN in mask
    mask_imgs_data = [mask_img.get_fdata() for mask_img in mask_imgs]
    mask_imgs_data = [np.where(mask == 0, np.nan, mask) for mask in mask_imgs_data]
    
    # apply binary mask to fm images
    fm_imgs_data = []
    for mask_img_data, fm_img in zip(mask_imgs_data, fm_imgs):
        fm_data = fm_img.get_fdata()
        fm_data = np.where(np.isnan(mask_img_data), np.nan, fm_data)
        fm_imgs_data.append(fm_data)
    
    return {'name': name, 'masks':mask_imgs_data, 'fms': fm_imgs_data}

def compute_slice_wise_weighted_rmse(fm_data, weight_mask):
    rmses = []
    for slice_idx in range(fm_data.shape[-1]):
        fm_slice = fm_data[..., slice_idx]
        weight_slice = np.sqrt(weight_mask[..., slice_idx])
        # Ignore NaNs in both fm_slice and weight_slice
        valid = ~np.isnan(fm_slice) & ~np.isnan(weight_slice)
        if np.any(valid):
            weighted_mse = np.nansum(weight_slice[valid] * (fm_slice[valid] ** 2)) / np.nansum(weight_slice[valid])
            rmses.append(np.sqrt(weighted_mse))
        else:
            rmses.append(np.nan)
    return rmses

def compute_rmse_subject(subject_data):
    # create [] to store rmses if not already present
    if 'rmses' not in subject_data:
        subject_data['rmses'] = []
    for fm_img, mask in zip (subject_data['fms'], subject_data['masks']):
        rmses = compute_slice_wise_weighted_rmse(fm_img, mask)
        subject_data['rmses'].append(rmses)
    subject_data['rmses_mean'] = [np.nanmean(rmses) for rmses in subject_data['rmses']]
    subject_data['rmses_std'] = [np.nanstd(rmses) for rmses in subject_data['rmses']]
    
def make_df_from_subject_data(subject_data_list):
    all_data = {
        'RMSE': [],
        'Shim': [],
        'Slice': [],
        'Subject': []
    }
    
    # Loop over each subject's data and collect the RMSEs
    for subject_data in subject_data_list:
        rmses = subject_data['rmses']
        
        # Flatten the RMSE data and append to the all_data dict
        all_data['RMSE'].extend([rmse for rmse_list in rmses for rmse in rmse_list])
        all_data['Shim'].extend(
            ['Baseline'] * len(rmses[0]) + ['seg'] * len(rmses[1]) + ['bin'] * len(rmses[2]) + \
            ['2lvl'] * len(rmses[3]) + ['lin'] * len(rmses[4]) + ['gaus'] * len(rmses[5])
        )
        all_data['Slice'].extend(list(range(len(rmses[0]))) * len(rmses))  # Slice index
        all_data['Subject'].extend([subject_data['name']] * (len(rmses[0]) * len(rmses)))
    
    # Create a DataFrame from the collected data
    df = pd.DataFrame(all_data)
    
    return df

def violin_plot_rmses_subjects(df):
    # Create the violin plot with hue based on the subject
    plt.figure(figsize=(15, 8))
    sns.violinplot(x='Shim', y='RMSE', hue='Shim', data=df, cut=0)
    # Formatting
    plt.xticks(ticks=[0, 1, 2, 3, 4, 5], labels=['Baseline\n(pas de shimming)', 'Binaire\nSegmentation', 'Binaire\nCylindrique', 'Pondéré\nDeux niveaux', 'Pondéré\nLinéaire', 'Pondéré\nGaussien'])
    plt.xlabel("Masque utilisé pour le shimming")
    plt.ylabel('RMSE')
    plt.title('Distribution tranche par tranche de la RMSE dans la région masquée')
    plt.tight_layout()
    plt.ylim(-15, 190)
    plt.gca().margins(x=0.1)  # Add extra space between groups
    # Add horizontal gridlines
    plt.grid(axis='y')
    plt.show()   

script_dir = os.path.dirname(os.path.abspath(__file__))
options = ['baseline', 'seg', 'bin', '2lvl', 'lin', 'gaus']
subject_paths = {
    "mask_paths": [
                os.path.join(script_dir, "../../2025.05.12-acdc_274/sub-acdc274/derivatives/masks/segmentation.nii.gz"),
                os.path.join(script_dir, "../../2025.05.12-acdc_274/sub-acdc274/derivatives/masks/segmentation.nii.gz"),
                os.path.join(script_dir, "../../2025.05.12-acdc_274/sub-acdc274/derivatives/masks/sct_bin_mask.nii.gz"),
                os.path.join(script_dir, "../../2025.05.12-acdc_274/sub-acdc274/derivatives/masks/st_soft_mask_2lvls.nii.gz"),
                os.path.join(script_dir, "../../2025.05.12-acdc_274/sub-acdc274/derivatives/masks/st_soft_mask_gauss.nii.gz"),
                os.path.join(script_dir, "../../2025.05.12-acdc_274/sub-acdc274/derivatives/masks/st_soft_mask_linear.nii.gz"),
            ],
    "fm_paths": [os.path.join(script_dir, f"../../2025.05.12-acdc_274/fmap-acdc274/sub-acdc274_fmap_{option}.nii.gz") for option in options]
}

subject_data = load_subject_data(subject_paths, 'acdc274')
compute_rmse_subject(subject_data)

print(f"Mean RMSE: {subject_data['rmses_mean']}")
print(f"Std RMSE: {subject_data['rmses_std']}")

# create a DataFrame from the subject data
df = make_df_from_subject_data([subject_data])

# Plot violin plot with hue based on subject
violin_plot_rmses_subjects(df)