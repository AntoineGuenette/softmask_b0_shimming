#!/bin/bash

# Set file paths
SCRIPT_DIR=$(dirname "$(realpath "$0")")
OUTPUT_PATH="$SCRIPT_DIR/../../2025.05.12-acdc_274/tSNR-acdc274/centerlines/"

EPI_PATHS=()
for OPTION in Baseline DynShim_SCseg DynShim_bin DynShim_2levels DynShim_linear DynShim_gauss; do
    DIR="$SCRIPT_DIR/../../2025.05.12-acdc_274/tSNR-acdc274/$OPTION/EPIs/"
    if [ -d "$DIR" ]; then
        EPI_PATHS+=($(find "$DIR" -name "*_EPI_mc_mean.nii.gz"))
    else
        echo "Warning: Directory $DIR not found, skipping."
    fi
done

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_PATH"

# Loop through each EPI file and extract centerlines
for EPI_PATH in "${EPI_PATHS[@]}"; do
    # Get the base name of the EPI file
    BASE_NAME=$(basename "$EPI_PATH" "_EPI_mc_mean.nii.gz")
    
    # Extract centerlines using SCT
    sct_get_centerline -i "$EPI_PATH" -method viewer -gap 5.0 -o "$OUTPUT_PATH/${BASE_NAME}_centerline.nii.gz"
done
