#!/bin/bash

echo """
This script computes the tSNR for six 60-volume EPI images. The DICOM folder should be organized as follows:

dicoms
├── 01-ep2d_bold_TTL_dynShim_mask_SCseg
│   ├── dicom1
│   ├── dicom2
│   └── ...
├── 02-ep2d_bold_TTL_dynShim_mask_bin
│   ├── dicom1
│   ├── dicom2
│   └── ...
├── 03-ep2d_bold_TTL_dynShim_mask_2vals
│   ├── dicom1
│   ├── dicom2
│   └── ...
├── 04-ep2d_bold_TTL_dynShim_mask_linear
│   ├── dicom1
│   ├── dicom2
│   └── ...
├── 05-ep2d_bold_TTL_dynShim_mask_gauss
│   ├── dicom1
│   ├── dicom2
│   └── ...
├── 06-ep2d_bold_TTL_dynShim_mask_gaussSum
│   ├── dicom1
│   ├── dicom2
│   └── ...

It takes two arguments:
1. The path to the folder containing the DICOM files
2. The name/tag of the subject

Outputs:
- Mean image of the EPI
- Mask of the spinal cord
- Mask centred around the spinal cord in EPI
- Motion corrected EPI
- Detrended EPI
- Standard deviation of the EPI
- tSNR map
"""

# Check if the correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <path_to_dicom_folder> <subject_name>"
    exit 1
fi

DICOMS_PATH=$1
SUBJECT_NAME=$2

# Set file paths
SCRIPT_DIR=$(dirname "$(realpath "$0")")

OUTPUT_PATH="${DICOMS_PATH%/*}/tsnr-$SUBJECT_NAME/"

# Dicoms to nifti
echo -e "\nConverting dicoms to nifti..."
st_dicom_to_nifti -i $DICOMS_PATH --subject $SUBJECT_NAME -o $OUTPUT_PATH

# Set ohter file paths
SHIMMED_EPI_BIN_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}" -name "*01_bold.nii.gz")
SHIMMED_EPI_2VALS_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}" -name "*02_bold.nii.gz")
SHIMMED_EPI_LINEAR_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}" -name "*03_bold.nii.gz")
SHIMMED_EPI_GAUSS_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}" -name "*04_bold.nii.gz")
SHIMMED_EPI_GAUSS_SUM_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}" -name "*05_bold.nii.gz")
SHIMMED_EPI_SCSEG_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}" -name "*06_bold.nii.gz")

OUTPUT_PATH_BIN=${OUTPUT_PATH}sub-acdc261/bin/
OUTPUT_PATH_2VALS=${OUTPUT_PATH}sub-acdc261/2vals/
OUTPUT_PATH_LINEAR=${OUTPUT_PATH}sub-acdc261/linear/
OUTPUT_PATH_GAUSS=${OUTPUT_PATH}sub-acdc261/gauss/
OUTPUT_PATH_GAUSS_SUM=${OUTPUT_PATH}sub-acdc261/gauss_sum/
OUTPUT_PATH_SCSEG=${OUTPUT_PATH}sub-acdc261/scseg/

echo "Output paths:"
echo "SHIMMED_EPI_BIN_PATH: $SHIMMED_EPI_BIN_PATH"
echo "SHIMMED_EPI_2VALS_PATH: $SHIMMED_EPI_2VALS_PATH"
echo "SHIMMED_EPI_LINEAR_PATH: $SHIMMED_EPI_LINEAR_PATH"
echo "SHIMMED_EPI_GAUSS_PATH: $SHIMMED_EPI_GAUSS_PATH"
echo "SHIMMED_EPI_GAUSS_SUM_PATH: $SHIMMED_EPI_GAUSS_SUM_PATH"
echo "SHIMMED_EPI_SCSEG_PATH: $SHIMMED_EPI_SCSEG_PATH"
echo "OUTPUT_PATH_BIN: $OUTPUT_PATH_BIN"
echo "OUTPUT_PATH_2VALS: $OUTPUT_PATH_2VALS"
echo "OUTPUT_PATH_LINEAR: $OUTPUT_PATH_LINEAR"
echo "OUTPUT_PATH_GAUSS: $OUTPUT_PATH_GAUSS"
echo "OUTPUT_PATH_GAUSS_SUM: $OUTPUT_PATH_GAUSS_SUM"
echo "OUTPUT_PATH_SCSEG: $OUTPUT_PATH_SCSEG"

# Calculate tSNR for each EPI
# echo -e "\nCalculating tSNR for each EPI..."
# echo -e "\nCalculating tSNR for 01_bold..."
# "$SCRIPT_DIR/calculate_tSNR.sh" $SHIMMED_EPI_BIN_PATH $OUTPUT_PATH_BIN
# echo -e "\nCalculating tSNR for 02_bold..."
# "$SCRIPT_DIR/calculate_tSNR.sh" $SHIMMED_EPI_2VALS_PATH $OUTPUT_PATH_2VALS
# echo -e "\nCalculating tSNR for 03_bold..."
# "$SCRIPT_DIR/calculate_tSNR.sh" $SHIMMED_EPI_LINEAR_PATH $OUTPUT_PATH_LINEAR
# echo -e "\nCalculating tSNR for 04_bold..."
# "$SCRIPT_DIR/calculate_tSNR.sh" $SHIMMED_EPI_GAUSS_PATH $OUTPUT_PATH_GAUSS
# echo -e "\nCalculating tSNR for 05_bold..."
# "$SCRIPT_DIR/calculate_tSNR.sh" $SHIMMED_EPI_GAUSS_SUM_PATH $OUTPUT_PATH_GAUSS_SUM
# echo -e "\nCalculating tSNR for 06_bold..."
# "$SCRIPT_DIR/calculate_tSNR.sh" $SHIMMED_EPI_SCSEG_PATH $OUTPUT_PATH_SCSEG
# echo -e "\nAll tSNR calculations completed."
