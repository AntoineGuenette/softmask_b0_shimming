#!/bin/bash

DICOMS_PATH=$1
SUBJECT_NAME=$2

echo "running test_b0shim ..."
st_b0shim dynamic \
    --coil /Users/antoineguenette/Documents/projet_III/coil_profiles/coil_profiles_NP15.nii.gz /Users/antoineguenette/Documents/projet_III/coil_profiles/NP15_config.json \
    --fmap /Users/antoineguenette/Documents/projet_III/data/softmask_shimming/sub-sum/derivatives/fmap/fieldmap.nii.gz \
    --anat /Users/antoineguenette/Documents/projet_III/data/softmask_shimming/sub-sum/sub-sum/func/sub-sum_bold.nii.gz \
    --mask /Users/antoineguenette/Documents/projet_III/data/softmask_shimming/sub-sum/derivatives/masks/st_soft_mask_sum.nii.gz \
    --mask-dilation-kernel-size 5 \
    --optimizer-method "pseudo_inverse" \
    --slices "auto" \
    --output-file-format-coil "chronological-coil" \
    --output-value-format "absolute" \
    --fatsat "yes" \
    --output /Users/antoineguenette/Documents/projet_III/data/softmask_shimming/sub-sum/derivatives/optimizations/dynamic_shim_gaussian_sum \