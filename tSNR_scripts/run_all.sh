#!/bin/bash

# This script runs all tSNR post-processing scripts for a given subject. The dicoms folder should be organized as follows:
#
# dicoms
# ├── 01-t1_mprage
# │   ├── dicom1
# │   ├── dicom2
# │   └── ...
# ├── 02-ep2d_bold_TTL
# │   ├── dicom1
# │   ├── dicom2
# │   └── ...
# ├── 03-ep2d_bold_TTL_dynShim_mask_SCseg
# │   ├── dicom1
# │   ├── dicom2
# │   └── ...
# ├── 04-ep2d_bold_TTL_dynShim_mask_bin
# │   ├── dicom1
# │   ├── dicom2
# │   └── ...
# ├── 05-ep2d_bold_TTL_dynShim_mask_2lvls
# │   ├── dicom1
# │   ├── dicom2
# │   └── ...
# ├── 06-ep2d_bold_TTL_dynShim_mask_linear
# │   ├── dicom1
# │   ├── dicom2
# │   └── ...
# ├── 07-ep2d_bold_TTL_dynShim_mask_gauss
# │   ├── dicom1
# │   ├── dicom2
# │   └── ...
#
# Inputs:
# 1. The path to the dicoms folder
# 2. The name of the subject
#
# Outputs:
# - tSNR maps for all shim options
# - Registered tSNR maps
# - Mean tSNR maps
# - tSNR per level maps
# - Reference files
# - QC files

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <path/to/dicoms> <subject_name>"
    exit 1
fi

DICOMS_PATH=$1
SUBJECT_NAME=$2

# Set paths
SCRIPT_PATH=$(dirname $0)
OUTPUT_PATH="${DICOMS_PATH%/*}/tSNR-$SUBJECT_NAME/"

# Set dicom paths
t1w_PATH_DICOMS=$DICOMS_PATH/*-T1w
BASELINE_PATH_DICOMS=$DICOMS_PATH/*-ep2d_bold_baseline_PA_tsnr
DynShim_SCseg_PATH_DICOMS=$DICOMS_PATH/*-ep2d_bold_seg_PA_tsnr
DynShim_bin_PATH_DICOMS=$DICOMS_PATH/*-ep2d_bold_bin_cyclindrique_PA_tsnr
DynShim_2levels_PATH_DICOMS=$DICOMS_PATH/*-ep2d_bold_soft_2lvl_PA_tsnr
DynShim_linear_PATH_DICOMS=$DICOMS_PATH/*-ep2d_bold_soft_lin_PA_tsnr
DynShim_gauss_PATH_DICOMS=$DICOMS_PATH/*-ep2d_bold_soft_gaus_PA_tsnr

# Set nifti paths
t1w_FOLDER_PATH=$OUTPUT_PATH/T1w
BASELINE_PATH=$OUTPUT_PATH/Baseline
DynShim_SCseg_PATH=$OUTPUT_PATH/DynShim_SCseg
DynShim_bin_PATH=$OUTPUT_PATH/DynShim_bin
DynShim_2levels_PATH=$OUTPUT_PATH/DynShim_2levels
DynShim_linear_PATH=$OUTPUT_PATH/DynShim_linear
DynShim_gauss_PATH=$OUTPUT_PATH/DynShim_gauss

# Convert dicoms to nifti
echo -e "\nConverting dicoms to nifti..."
st_dicom_to_nifti -i $t1w_PATH_DICOMS --subject $SUBJECT_NAME -o $t1w_FOLDER_PATH
st_dicom_to_nifti -i $BASELINE_PATH_DICOMS --subject $SUBJECT_NAME -o $BASELINE_PATH
st_dicom_to_nifti -i $DynShim_SCseg_PATH_DICOMS --subject $SUBJECT_NAME -o $DynShim_SCseg_PATH
st_dicom_to_nifti -i $DynShim_bin_PATH_DICOMS --subject $SUBJECT_NAME -o $DynShim_bin_PATH
st_dicom_to_nifti -i $DynShim_2levels_PATH_DICOMS --subject $SUBJECT_NAME -o $DynShim_2levels_PATH
st_dicom_to_nifti -i $DynShim_linear_PATH_DICOMS --subject $SUBJECT_NAME -o $DynShim_linear_PATH
st_dicom_to_nifti -i $DynShim_gauss_PATH_DICOMS --subject $SUBJECT_NAME -o $DynShim_gauss_PATH

# Set reference path (segmentation shim)  
REF_FOLDER_PATH=$DynShim_SCseg_PATH

for SHIM_PATH in {$BASELINE_PATH,$DynShim_SCseg_PATH,$DynShim_bin_PATH,$DynShim_2levels_PATH,$DynShim_linear_PATH,$DynShim_gauss_PATH}
do

    OPT_NAME=$(basename $SHIM_PATH)
    echo -e "\nProcessing $OPT_NAME..."
    if test -d $SHIM_PATH; then
        
        # Move and rename the EPI file
        echo -e "\nMoving and renaming the EPI file..."
        EPI_60vol_PATH=$(find $SHIM_PATH/sub-$SUBJECT_NAME/func -name "sub-${SUBJECT_NAME}_bold.nii.gz")
        if [ -f "$EPI_60vol_PATH" ]; then
            mkdir -p "$SHIM_PATH/EPIs"
            mv "$EPI_60vol_PATH" "$SHIM_PATH/EPIs/${OPT_NAME}_EPI_60vol.nii.gz"
            EPI_60vol_PATH="$SHIM_PATH/EPIs/${OPT_NAME}_EPI_60vol.nii.gz"
            echo -e "\n$OPT_NAME EPI file moved to $EPI_60vol_PATH"
        fi
        
        # Remove unwanted directories if they exist
        echo -e "\nRemoving unwanted directories..."
        for DIR in derivatives sourcedata tmp_dcm2bids sub-$SUBJECT_NAME; do
            if [ -d "$SHIM_PATH/$DIR" ]; then
                rm -rf "$SHIM_PATH/$DIR"
            fi
        done
        echo -e "\nAll unwanted directories removed successfully."
        
        # Compute the tSNR
        echo -e "\nComputing tSNR for $OPT_NAME..."
        "$SCRIPT_PATH/tSNR_sc.sh" $EPI_60vol_PATH $OPT_NAME
    fi
done

if test -d $t1w_FOLDER_PATH; then
    
    # Move and rename the MPRAGE file
    echo -e "\nMoving and renaming the MPRAGE file..."
    t1w_PATH=$(find $t1w_FOLDER_PATH/sub-$SUBJECT_NAME/anat -name "sub-${SUBJECT_NAME}_T1w.nii.gz")
    if [ -f "$t1w_PATH" ]; then
        mkdir -p "$t1w_FOLDER_PATH"
        mv "$t1w_PATH" "$t1w_FOLDER_PATH/T1w.nii.gz"
        t1w_PATH="$t1w_FOLDER_PATH/T1w.nii.gz"
        echo -e "\nMPRAGE file moved to $t1w_PATH"
    fi
    
    # Remove unwanted directories if they exist
    echo -e "\nRemoving unwanted directories..."
    for DIR in derivatives sourcedata tmp_dcm2bids sub-$SUBJECT_NAME; do
        if [ -d "$t1w_FOLDER_PATH/$DIR" ]; then
            rm -rf "$t1w_FOLDER_PATH/$DIR"
        fi
    done
    echo -e "\nAll unwanted directories removed successfully."

    # Prepare reference
    echo -e "\nPreparing reference..."
    "$SCRIPT_PATH/prepare_ref.sh" $REF_FOLDER_PATH $t1w_PATH
fi

for SHIM_PATH in {$BASELINE_PATH,$DynShim_SCseg_PATH,$DynShim_bin_PATH,$DynShim_2levels_PATH,$DynShim_linear_PATH,$DynShim_gauss_PATH}
do
    OPT_NAME=$(basename $SHIM_PATH)
    if test -d $SHIM_PATH; then
        # Register the tSNR to the reference
        echo -e "\nRegistering tSNR to reference for $OPT_NAME..."
        "$SCRIPT_PATH/register_tSNR.sh" $REF_FOLDER_PATH $t1w_FOLDER_PATH $SHIM_PATH
    fi
done