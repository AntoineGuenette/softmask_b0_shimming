#!/bin/bash

echo "
This script runs the entire experiment for a given subject. It is meant to be run from the command line after
the baseline MPrage, the baseline field map and one baseline EPI has been acquired. Your dicom folder should be organized as follows:

dicoms
├── 01_baseline_mprage_t1w (mag)
│   ├── dicom1
│   ├── dicom2
│   └── ...
├── 02_baseline_GRE (mag)
│   ├── dicom1
│   ├── dicom2
│   └── ...
|── 03_baseline_GRE (phase)
|    ├── dicom1
|    ├── dicom2
|    └── ...
|-- 04_baseline_EPI (AP or PA)
|    ├── dicom1
|    ├── dicom2
|    └── ...

It takes four arguments:
1. The path to the dicoms directory
2. The name / tag of the subject
3. The diameter of the binary mask
4. The width of the blur zone

Outputs:
- Directory with the nifti files (sub-<subject_name>)
It includes all niftis and optimization files (currents for the coil, predicted B0 field, etc.)
"

# Check if five arguments are provided
if [ "$#" -ne 5 ]; then
    echo "Illegal number of parameters"
    echo "Usage: ./compare_softmask.sh <dicoms_path> <subject_name> <diameter> <blur_width> <softmask_type>"
    exit 1
fi
# Check if mask type is valid
if [ "$5" != 'gaussian' ] && [ "$5" != 'constant' ] && [ "$5" != 'linear' ] && [ "$5" != 'gaussian_sum' ]; then
    echo "Invalid mask type. Options are 'gaussian', 'constant', 'linear', 'gaussian_sum'."
    echo "Exiting..."
    exit 1
fi

# Assign the arguments to variables
DICOMS_PATH=$1
SUBJECT_NAME=$2
DIAMETER=$3
BLUR_WIDTH=$4
SOFTMASK_TYPE=$5

# Set file paths
SCRIPT_DIR=$(dirname "$(realpath "$0")")

COIL_PROFILES_DIR="$SCRIPT_DIR/../coil_profiles"
COIL_PATH="${COIL_PROFILES_DIR}/coil_profiles_NP15.nii.gz"
COIL_CONFIG_PATH="${COIL_PROFILES_DIR}/NP15_config.json"
COIL_NAME="$(grep '"name"' "$COIL_CONFIG_PATH" | sed -E 's/.*"name": *"([^"]+)".*/\1/')"
echo Name of the chosen coil : $COIL_NAME

OUTPUT_PATH="${DICOMS_PATH%/*}/sub-$SUBJECT_NAME/"
SORTED_DICOMS_PATH="${DICOMS_PATH%/*}/sorted_dicoms_opt/"

# Sorting dicoms
echo -e "\nSorting dicoms..."
st_sort_dicoms -i $DICOMS_PATH -o $SORTED_DICOMS_PATH -r

# Dicoms to nifti
echo -e "\nConverting dicoms to nifti..."
st_dicom_to_nifti -i $SORTED_DICOMS_PATH --subject $SUBJECT_NAME -o $OUTPUT_PATH

# Set ohter file paths
MAGNITUDE_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}" -name "*magnitude1.nii.gz")
PHASE1_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}" -name "*phase1.nii.gz")
PHASE2_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}" -name "*phase2.nii.gz")
EPI_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}/func" -name "*.nii.gz")
MPRAGE_PATH="${OUTPUT_PATH}sub-${SUBJECT_NAME}/anat/sub-${SUBJECT_NAME}_T1w.nii.gz"

# Check if the files exist
if [ -z "$MAGNITUDE_PATH" ] || [ -z "$PHASE1_PATH" ] || [ -z "$PHASE2_PATH" ] || [ -z "$EPI_PATH" ]; then
    echo "Error: One or more required NIfTI files are missing! Exiting..."
    exit 1
fi

# Create mask from magnitude image
MASK_DIR="${OUTPUT_PATH}derivatives/masks"
if [ ! -d $MASK_DIR ]; then
    mkdir $MASK_DIR
fi

# File names of the masks
FNAME_SEGMENTATION="${MASK_DIR}/segmentation.nii.gz"
FNAME_BIN_MASK_SCT="${MASK_DIR}/sct_bin_mask.nii.gz"
FNAME_BIN_MASK_SCT_FM="${MASK_DIR}/sct_bin_mask_fm.nii.gz"

if [ "$SOFTMASK_TYPE" == 'constant' ]; then
    FNAME_SOFTMASK="${MASK_DIR}/st_soft_mask_cst.nii.gz"
elif [ "$SOFTMASK_TYPE" == 'linear' ]; then
    FNAME_SOFTMASK="${MASK_DIR}/st_soft_mask_lin.nii.gz"
elif [ "$SOFTMASK_TYPE" == 'gaussian' ]; then
    FNAME_SOFTMASK="${MASK_DIR}/st_soft_mask_gss.nii.gz"
elif [ "$SOFTMASK_TYPE" == 'gaussian_sum' ]; then
    FNAME_SOFT_MASK_GAUSS_SCT="${MASK_DIR}/sct_soft_mask_gauss.nii.gz"
    FNAME_SOFTMASK="${MASK_DIR}/st_soft_mask_sum.nii.gz"
else
    echo "Problem with the mask filing. Exiting..."
    exit 1
fi

# Create masks
echo -e "\nCreating segmentation from magnitude image..."
sct_deepseg -i "${MPRAGE_PATH}" -c t1 -task seg_sc_contrast_agnostic -o "${FNAME_SEGMENTATION}" || exit
echo -e "\nCreating binary masks from segmentation..."
sct_create_mask -i "${MPRAGE_PATH}" -p centerline,"${FNAME_SEGMENTATION}" -size $DIAMETER -f cylinder -o "${FNAME_BIN_MASK_SCT}" || exit
sct_create_mask -i "${MPRAGE_PATH}" -p centerline,"${FNAME_SEGMENTATION}" -size $((DIAMETER + 2 * BLUR_WIDTH + 15)) -f cylinder -o "${FNAME_BIN_MASK_SCT_FM}" || exit
if [ "$SOFTMASK_TYPE" == 'constant' ]; then
    echo -e "\nCreating constant soft mask from the binary mask..."
    st_mask create-softmask -i "${FNAME_BIN_MASK_SCT}" -o "${FNAME_SOFTMASK}" -b 'constant' -bw $BLUR_WIDTH || exit
elif [ "$SOFTMASK_TYPE" == 'linear' ]; then
    echo -e "\nCreating linear soft mask from the binary mask..."
    st_mask create-softmask -i "${FNAME_BIN_MASK_SCT}" -o "${FNAME_SOFTMASK}" -b 'linear' -bw $BLUR_WIDTH || exit
elif [ "$SOFTMASK_TYPE" == 'gaussian' ]; then
    echo -e "\nCreating gaussian soft mask from the binary mask..."
    st_mask create-softmask -i "${FNAME_BIN_MASK_SCT}" -o "${FNAME_SOFTMASK}" -b 'gaussian' -bw $BLUR_WIDTH || exit
elif [ "$SOFTMASK_TYPE" == 'gaussian_sum' ]; then
    echo -e "\nCreating gaussian soft mask from segmentation..."
    sct_create_mask -i "${MPRAGE_PATH}" -p centerline,"${FNAME_SEGMENTATION}" -size $DIAMETER -f gaussian -o "${FNAME_SOFT_MASK_GAUSS_SCT}" || exit
    echo -e "\nAdding the two previous masks..."
    st_mask gaussian-sct-softmask -ib "${FNAME_BIN_MASK_SCT}" -ig "${FNAME_SOFT_MASK_GAUSS_SCT}" -o "${FNAME_SOFTMASK}" || exit
else
    echo "Problem with the mask creation. Exiting..."
    exit 1
fi

# Show masks with magnitude
echo -e "\nDisplaying masks with magnitude image..."
fsleyes $MPRAGE_PATH -cm greyscale $FNAME_SOFTMASK -cm copper $FNAME_SEGMENTATION -cm blue
        
# Promp user to approve the masks
echo -e "\nDoes the mask look good?"
echo "1. Yes"
echo "2. No, exit program"
read -p "Enter your choice (1 or 2): " mask_approval

case $mask_approval in
    1)
        echo -e "\nMask approved."
        ;;
    2)
        echo -e "\nExiting..."
        exit 1
        ;;
    *)
        echo -e "\nInvalid choice. Exiting..."
        exit 1
        ;;
esac

# Create fieldmap
echo -e "\nCreating fieldmap..."
FIELDMAP_PATH="${OUTPUT_PATH}derivatives/fmap/fieldmap.nii.gz"
FIELDMAP_JSON_PATH="${OUTPUT_PATH}derivatives/fmap/fieldmap.json"
st_prepare_fieldmap $PHASE1_PATH $PHASE2_PATH \
 --mag $MAGNITUDE_PATH \
 --unwrapper prelude \
 --gaussian-filter true \
 --mask $FNAME_BIN_MASK_SCT_FM \
 --sigma 1 \
 -o $FIELDMAP_PATH

# Show fiedlmap with magnitude
echo -e "\nDisplaying fieldmap with magnitude image..."
fsleyes $MAGNITUDE_PATH $FIELDMAP_PATH -dr -100 100

# Prompt user to approve the fieldmap
echo -e "\nDoes the fieldmap look good?"
echo "1. Yes"
echo "2. No, exit program"
read -p "Enter your choice (1 or 2): " fieldmap_approval

case $fieldmap_approval in
    1)
        echo -e "\nFieldmap approved."
        ;;
    2)
        echo -e "\nExiting..."
        exit 1
        ;;
    *)
        echo -e "\nInvalid choice. Exiting..."
        exit 1
        ;;
esac

# Create output directory for the optimizations
OPTI_OUTPUT_DIR="${OUTPUT_PATH}derivatives/optimizations"
if [ ! -d $OUTPUT_DIR ]; then
    mkdir $OUTPUT_DIR
fi

# Shimming the fieldmap
OUTPUT_DIR="${OPTI_OUTPUT_DIR}/dynamic_shim_${SOFTMASK_TYPE}"
echo -e "\nShimming the fieldmap..."
st_b0shim dynamic \
    --coil $COIL_PATH $COIL_CONFIG_PATH \
    --fmap $FIELDMAP_PATH \
    --anat $EPI_PATH \
    --mask "$FNAME_SOFTMASK" \
    --mask-dilation-kernel-size 5 \
    --optimizer-method "pseudo_inverse" \
    --slices "auto" \
    --output-file-format-coil "chronological-coil" \
    --output-value-format "absolute" \
    --fatsat "yes" \
    --output "$OUTPUT_DIR" \

# Create two files with the same currents, with and without fatsat
DYN_CURRENTS_DIR="${OUTPUT_DIR}/coefs_coil0_${COIL_NAME}_no_fatsat.txt"
DYN_CURRENTS_MODIFIED_DIR="${OUTPUT_DIR}/coefs_coil0_${COIL_NAME}_SAME_CURRENTS_FATSAT.txt"
fatsat=$(sed -n '1p' "$DYN_CURRENTS_DIR")
sed 'p' "$DYN_CURRENTS_DIR" > "$DYN_CURRENTS_MODIFIED_DIR"

# Remove the sorted dicoms folder
echo -e "\nRemoving sorted dicoms folder..."
rm -r $SORTED_DICOMS_PATH

# End of the script
echo -e "\nProcessing complete. Results saved in $OPTI_OUTPUT_DIR."