import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt
import nibabel as nib
from nibabel.processing import resample_from_to
import pandas as pd
import os

def load_subject_data(subject_paths, name):
    mask_img = nib.load(subject_paths["mask_path"])
    fm_imgs = [nib.load(fm_path) for fm_path in subject_paths["fm_paths"]]
    fm_ref_img = fm_imgs[1]  # Use the second fieldmap (DynSHim_SCseg) as reference for resampling
    
    # resample mask to fm resolution
    mask_img = resample_from_to(mask_img, fm_ref_img, order=0, mode='grid-constant', cval=0)
    
    # Replace 0 with NaN in mask
    mask_img_data = mask_img.get_fdata()
    mask_img_data[mask_img_data == 0] = np.nan
    
    # apply binary mask to fm images
    fm_imgs_data = [fm_img.get_fdata() * mask_img_data for fm_img in fm_imgs]
    
    return {'name': name, 'mask':mask_img_data, 'fms': fm_imgs_data}

def compute_slice_wise_weighted_rmse(fm_data, mask):
    rmses = []
    for slice_idx in range(fm_data.shape[-1]):
        fm_slice = fm_data[..., slice_idx]
        weight_slice = np.sqrt(mask[..., slice_idx])
        # Ignore NaNs in both fm_slice and weight_slice
        valid = ~np.isnan(fm_slice) & ~np.isnan(weight_slice)
        if np.any(valid):
            weighted_mse = np.nansum(weight_slice[valid] * (fm_slice[valid] ** 2)) / np.nansum(weight_slice[valid])
            rmses.append(np.sqrt(weighted_mse))
        else:
            rmses.append(np.nan)
    return rmses

def compute_rmse_subject(subject_data):
    if 'rmses' not in subject_data:
        subject_data['rmses'] = []
    for fm_img in subject_data['fms']:
        rmses = compute_slice_wise_weighted_rmse(fm_img, subject_data['mask'])
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

def violin_plot_rmses_subjects(df, output_path):
    # Create the violin plot with hue based on the subject
    plt.figure(figsize=(15, 8))
    sns.violinplot(x='Shim', y='RMSE', hue='Shim', data=df, cut=0)
    # Formatting
    plt.xticks(ticks=[0, 1, 2, 3, 4, 5], 
               labels=['Baseline\n(pas de shimming)', 'Binaire\nSegmentation', 'Binaire\nCylindrique',
                       'Pondéré\nDeux niveaux', 'Pondéré\nLinéaire', 'Pondéré\nGaussien'])
    plt.xlabel("Masque utilisé pour le shimming")
    plt.ylabel('RMSE dans la moelle épinière')
    plt.title('Distribution tranche par tranche de la RMSE dans la moelle épinière')
    means = subject_data['rmses_mean']
    stds = subject_data['rmses_std']
    for i, (mean, std) in enumerate(zip(means, stds)):
        text = f"$\\mu$ : {mean:.1f} | $\\sigma$ : {std:.1f}"
        plt.text(i, -5, text, ha='center', va='center', fontsize=10, fontweight='bold')
    plt.tight_layout()
    plt.ylim(-10, 190)
    plt.gca().margins(x=0.1)  # Add extra space between groups
    # Add horizontal gridlines
    plt.grid(axis='y')
    
    # Save the figure
    output_file = os.path.join(output_path, "violin_plot.png")
    plt.savefig(output_file, dpi=300, bbox_inches='tight')

if __name__ == "__main__":

    script_dir = os.path.dirname(os.path.abspath(__file__))
    options = ['baseline', 'seg', 'bin', '2lvl', 'lin', 'gaus']
    subject_paths = {
        "mask_path": os.path.join(script_dir, "../../2025.05.12-acdc_274/sub-acdc274/derivatives/masks/segmentation.nii.gz"),
        "fm_paths": [os.path.join(script_dir, f"../../2025.05.12-acdc_274/fmap-acdc274/sub-acdc274_fmap_{option}.nii.gz")
                    for option in options]
    }

    subject_data = load_subject_data(subject_paths, 'acdc274')
    compute_rmse_subject(subject_data)

    # create a DataFrame from the subject data
    df = make_df_from_subject_data([subject_data])

    # Plot violin plot with hue based on subject
    output_path = os.path.join(script_dir, "../../2025.05.12-acdc_274/figures")
    violin_plot_rmses_subjects(df, output_path)