#!/usr/bin/python3

import nibabel as nib
import os

from nibabel.processing import resample_from_to

# Arguments
exp_year = '2025'
exp_month = '05'
exp_day = '12'
acdc_number = '274'
subject_name = f"acdc{acdc_number}"

# Paths
script_dir = os.path.dirname(os.path.abspath(__file__))
experience_path = os.path.abspath(os.path.join(script_dir, "..", "..", f"{exp_year}.{exp_month}.{exp_day}-acdc_{acdc_number}"))
print(f"Experience path: {experience_path}")
masks_path = os.path.join(experience_path, f"sub-{subject_name}", 'derivatives', 'masks')
tSNR_path = os.path.join(experience_path, f"tSNR-{subject_name}")
output_path = os.path.join(masks_path, "resampled_segmentation.nii.gz")

# Load the segmentation
seg_mask_path = os.path.join(masks_path, "segmentation.nii.gz")
nii_seg_mask = nib.load(seg_mask_path)
seg_mask_data = nii_seg_mask.get_fdata()

# Load the EPIs
EPI_baseline_path = os.path.join(tSNR_path, "Baseline", "EPIs", "Baseline_EPI_60vol_mean.nii.gz")
nii_EPI_baseline = nib.load(EPI_baseline_path)
EPI_seg_path = os.path.join(tSNR_path, "DynShim_SCseg", "EPIs", "DynShim_SCseg_EPI_60vol_mean.nii.gz")

# Resample the segmentation mask to the EPI space
print("\nResampling segmentation mask to EPI space...")
nii_resampled_seg_mask = resample_from_to(nii_seg_mask, nii_EPI_baseline)
resampled_seg_mask_data = nii_resampled_seg_mask.get_fdata()

# Save the resampled segmentation mask
nii_resampled_seg_mask.to_filename(output_path)

print("\nTo generate the animation, run the following command in the terminal:")
print(f"fsleyes {EPI_baseline_path} -cm greyscale {EPI_seg_path} -cm greyscale {output_path} -cm blue -a 50.0")
