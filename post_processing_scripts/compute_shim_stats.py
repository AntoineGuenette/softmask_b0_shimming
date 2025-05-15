import nibabel as nib
import os

from shimmingtoolbox.masking.mask_utils import resample_mask
from shimmingtoolbox.shim.shim_utils import calculate_metric_within_mask

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
FMAPs_path = os.path.join(experience_path, f"fmap-{subject_name}")
masks_path = os.path.join(experience_path, f"sub-{subject_name}", 'derivatives', 'masks')
output_path = os.path.join(experience_path, f"shim_stats-{subject_name}")
os.makedirs(output_path, exist_ok=True)

# Load the masks
seg_mask_path = os.path.join(masks_path, "segmentation.nii.gz")
nii_seg_mask = nib.load(seg_mask_path)
seg_mask_data = nii_seg_mask.get_fdata()

bin_mask_path = os.path.join(masks_path, "sct_bin_mask.nii.gz")
nii_bin_mask = nib.load(bin_mask_path)
bin_mask_data = nii_bin_mask.get_fdata()

twolvl_mask_path = os.path.join(masks_path, "st_soft_mask_2lvls.nii.gz")
nii_twolvl_mask = nib.load(twolvl_mask_path)
twolvl_mask_data = nii_twolvl_mask.get_fdata()

lin_mask_path = os.path.join(masks_path, "st_soft_mask_linear.nii.gz")
nii_lin_mask = nib.load(lin_mask_path)
lin_mask_data = nii_lin_mask.get_fdata()

gaus_mask_path = os.path.join(masks_path, "st_soft_mask_gauss.nii.gz")
nii_gaus_mask = nib.load(gaus_mask_path)
gaus_mask_data = nii_gaus_mask.get_fdata()

# Load the baseline data
baseline_FMAP_path = os.path.join(FMAPs_path, f"sub-{subject_name}_fmap_baseline.nii.gz")
nii_baseline_FMAP = nib.load(baseline_FMAP_path)
baseline_FMAP_data = nii_baseline_FMAP.get_fdata()

categories = ["seg", "bin", "2lvl", "lin", "gaus"]
masks = [nii_seg_mask, nii_bin_mask, nii_twolvl_mask, nii_lin_mask, nii_gaus_mask]
for category, mask in zip(categories, masks):
    
    # Load the fieldmap
    FMAP_path = os.path.join(FMAPs_path, f"sub-{subject_name}_fmap_{category}.nii.gz")
    nii_FMAP = nib.load(FMAP_path)
    FMAP_data = nii_FMAP.get_fdata()

    # Resample the masks to the EPI space
    print(f"\nResampling {category} mask to EPI space...")
    nii_resampled_mask = resample_mask(mask, nii_FMAP)
    resampled_mask_data = nii_resampled_mask.get_fdata()

    # Calculate the metrics in all the masked region
    print(f"Calculating metrics in all the {category} region...")
    unshimmed_std = calculate_metric_within_mask(baseline_FMAP_data, resampled_mask_data, metric="std")
    unshimmed_mae = calculate_metric_within_mask(baseline_FMAP_data, resampled_mask_data, metric="mae")
    unshimmed_rmse = calculate_metric_within_mask(baseline_FMAP_data, resampled_mask_data, metric="rmse")

    shimmed_std = calculate_metric_within_mask(FMAP_data, resampled_mask_data, metric="std")
    shimmed_mae = calculate_metric_within_mask(FMAP_data, resampled_mask_data, metric="mae")
    shimmed_rmse = calculate_metric_within_mask(FMAP_data, resampled_mask_data, metric="rmse")

    improvement_std = (unshimmed_std - shimmed_std) / unshimmed_std
    improvement_mae = (unshimmed_mae - shimmed_mae) / unshimmed_mae
    improvement_rmse = (unshimmed_rmse - shimmed_rmse) / unshimmed_rmse

    if category != "seg" :
        
        # Resample the segmentation mask to the EPI space
        print("\nResampling segmentation mask to EPI space...")
        nii_resampled_seg_mask = resample_mask(nii_seg_mask, nii_FMAP)
        resampled_seg_mask_data = nii_resampled_seg_mask.get_fdata()
        
        # Calculate the metrics onlyt in the spinal cord region
        print("Calculating metrics in the spinal cord region...")
        unshimmed_std_sc = calculate_metric_within_mask(baseline_FMAP_data, resampled_seg_mask_data, metric="std")
        unshimmed_mae_sc = calculate_metric_within_mask(baseline_FMAP_data, resampled_seg_mask_data, metric="mae")
        unshimmed_rmse_sc = calculate_metric_within_mask(baseline_FMAP_data, resampled_seg_mask_data, metric="rmse")

        shimmed_std_sc = calculate_metric_within_mask(FMAP_data, resampled_seg_mask_data, metric="std")
        shimmed_mae_sc = calculate_metric_within_mask(FMAP_data, resampled_seg_mask_data, metric="mae")
        shimmed_rmse_sc = calculate_metric_within_mask(FMAP_data, resampled_seg_mask_data, metric="rmse")

        improvement_std_sc = (unshimmed_std_sc - shimmed_std_sc) / unshimmed_std_sc
        improvement_mae_sc = (unshimmed_mae_sc - shimmed_mae_sc) / unshimmed_mae_sc
        improvement_rmse_sc = (unshimmed_rmse_sc - shimmed_rmse_sc) / unshimmed_rmse_sc

    # Prepare results for CSV
    rows = []
    # Metrics for the whole masked region
    rows.append(["masked_region", "Std", unshimmed_std, shimmed_std, improvement_std])
    rows.append(["masked_region", "MAE", unshimmed_mae, shimmed_mae, improvement_mae])
    rows.append(["masked_region", "RMSE", unshimmed_rmse, shimmed_rmse, improvement_rmse])

    # Metrics for the segmentation (SC) region, if available
    if category != "seg":
        rows.append(["segmentation", "Std", unshimmed_std_sc, shimmed_std_sc, improvement_std_sc])
        rows.append(["segmentation", "MAE", unshimmed_mae_sc, shimmed_mae_sc, improvement_mae_sc])
        rows.append(["segmentation", "RMSE", unshimmed_rmse_sc, shimmed_rmse_sc, improvement_rmse_sc])

    # Save results to CSV
    print(f"Saving results for {category}...")
    with open(os.path.join(output_path, f"shim_stats_{category}.csv"), "w") as f:
        f.write("Region,Metric,Unshimmed,Shimmed,Improvement\n")
        for row in rows:
            f.write(",".join(map(str, row)) + "\n")
    print(f"Shim stats for {category} saved in {output_path}/shim_stats_{category}.csv")

# Assemble all the results in a single CSV file
print("\nAssembling all results in a single CSV file...")
with open(os.path.join(output_path, "all_shim_stats.csv"), "w") as f:
    f.write("Category,Region,Metric,Unshimmed,Shimmed,Improvement\n")
    for category in categories:
        with open(os.path.join(output_path, f"shim_stats_{category}.csv"), "r") as f2:
            lines = f2.readlines()[1:]  # Skip the header
            for line in lines:
                f.write(f"{category},{line}")
print(f"All shim stats saved in {output_path}/all_shim_stats.csv")

print("\nAll done!")
