#!/bin/bash

echo "
This script runs the entire experiment for a given phantom. It is meant to be run from the command line after
the baseline field map has been acquired. Your dicom folder should be organized as follows:

dicoms
├── 01_baseline_GRE (mag)
│   ├── dicom1
│   ├── dicom2
│   └── ...
|── 02_baseline_GRE (phase)
|    ├── dicom1
|    ├── dicom2
|    └── ...

It takes four arguments:
1. The path to the dicoms directory
2. The name / tag of the subject
3. The threshold for the binary mask
4. The width of the blur zone. Must be a multiple of 3.
5. Skip the creation/verification of masks and fieldmap if they already exist (0 for no, 1 for yes)

Outputs:
- Directory with the nifti files (sub-<subject_name>)
It includes all niftis and optimization files (currents for the coil, predicted B0 field, etc.)
"

# Check if five arguments are provided
if [ "$#" -ne 5 ]; then
    echo "Illegal number of parameters"
    echo "Usage: ./compare_softmask.sh <dicoms_path> <subject_name> <threshold> <blur_width> <verification>"
    echo "Example: ./compare_softmask.sh /path/to/dicoms subject_name 25 9 1"
    exit 1
fi

# Assign the arguments to variables
DICOMS_PATH=$1
SUBJECT_NAME=$2
THRESHOLD=$3
BLUR_WIDTH=$4
VERIFICATION=$5

# Set file paths
SCRIPT_DIR=$(dirname "$(realpath "$0")")

COIL_PROFILES_DIR="$SCRIPT_DIR/../coil_profiles"
COIL_PATH="${COIL_PROFILES_DIR}/coil_profiles_NP15.nii.gz"
COIL_CONFIG_PATH="${COIL_PROFILES_DIR}/NP15_config.json"
COIL_NAME="$(grep '"name"' "$COIL_CONFIG_PATH" | sed -E 's/.*"name": *"([^"]+)".*/\1/')"
echo Name of the chosen coil : $COIL_NAME

OUTPUT_PATH="${DICOMS_PATH%/*}/sub-$SUBJECT_NAME/"
SORTED_DICOMS_PATH="${DICOMS_PATH%/*}/sorted_dicoms_opt/"

# Check if the sorted dicoms and nifti conversion have already been done
if [ $VERIFICATION == 1 ] && [ -d "$OUTPUT_PATH" ]; then
    echo -e "\nDicoms already sorted and converted to nifti. Skipping these steps..."
else
    # Sorting dicoms
    echo -e "\nSorting dicoms..."
    st_sort_dicoms -i $DICOMS_PATH -o $SORTED_DICOMS_PATH -r

    # Dicoms to nifti
    echo -e "\nConverting dicoms to nifti..."
    st_dicom_to_nifti -i $SORTED_DICOMS_PATH --subject $SUBJECT_NAME -o $OUTPUT_PATH
fi

# Set ohter file paths
MAGNITUDE_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}" -name "*magnitude1.nii.gz")
PHASE1_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}" -name "*phase1.nii.gz")
PHASE2_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}" -name "*phase2.nii.gz")

# Check if the files exist
if [ -z "$MAGNITUDE_PATH" ] || [ -z "$PHASE1_PATH" ] || [ -z "$PHASE2_PATH" ] ; then
    echo "Error: One or more required NIfTI files are missing! Exiting..."
    exit 1
fi

# Create mask from magnitude image
MASK_DIR="${OUTPUT_PATH}derivatives/masks"
if [ ! -d $MASK_DIR ]; then
    mkdir $MASK_DIR
fi

# File names of the masks
FNAME_BIN_MASK_SCT="${MASK_DIR}/sct_bin_mask.nii.gz"
FNAME_BIN_MASK_SCT_FM="${MASK_DIR}/sct_bin_mask_fm.nii.gz"
FNAME_SOFT_MASK_CST_ST="${MASK_DIR}/st_soft_mask_cst.nii.gz"
FNAME_SOFT_MASK_LIN_ST="${MASK_DIR}/st_soft_mask_lin.nii.gz"
FNAME_SOFT_MASK_GSS_ST="${MASK_DIR}/st_soft_mask_gss.nii.gz"

# Check if paths exist and skipping the creation of the masks if they do
if [ $VERIFICATION == 1 ] && [ -f "$FNAME_BIN_MASK_SCT" ] && [ -f "$FNAME_BIN_MASK_SCT_FM" ] && [ -f "$FNAME_SOFT_MASK_CST_ST" ] && [ -f "$FNAME_SOFT_MASK_LIN_ST" ] && [ -f "$FNAME_SOFT_MASK_GSS_ST" ]; then
    echo -e "\nMasks already exist. Skipping mask creation..."
else
    # Create masks
    echo -e "\nCreating binary masks..."
    st_mask threshold -i $MAGNITUDE_PATH --thr $THRESHOLD -o $FNAME_BIN_MASK_SCT || exit
    st_mask create-softmask -i "${FNAME_BIN_MASK_SCT}" -o "${FNAME_BIN_MASK_SCT_FM}" -b 'constant' -bw $((BLUR_WIDTH * 2)) -bv 1 || exit
    echo -e "\nCreating constant soft mask from the binary mask..."
    st_mask create-softmask -i "${FNAME_BIN_MASK_SCT}" -o "${FNAME_SOFT_MASK_CST_ST}" -b 'constant' -bw $BLUR_WIDTH || exit
    echo -e "\nCreating linear soft mask from the binary mask..."
    st_mask create-softmask -i "${FNAME_BIN_MASK_SCT}" -o "${FNAME_SOFT_MASK_LIN_ST}" -b 'linear' -bw $BLUR_WIDTH || exit
    echo -e "\nCreating gaussian soft mask from the binary mask..."
    st_mask create-softmask -i "${FNAME_BIN_MASK_SCT}" -o "${FNAME_SOFT_MASK_GSS_ST}" -b 'gaussian' -bw $BLUR_WIDTH || exit

    # Show masks with magnitude
    echo -e "\nDisplaying masks with magnitude image..."
    fsleyes \
        $MAGNITUDE_PATH -cm greyscale \
        $FNAME_SOFT_MASK_CST_ST -cm copper -a 50.0 \
        $FNAME_SOFT_MASK_LIN_ST -cm copper -a 50.0 \
        $FNAME_SOFT_MASK_GSS_ST -cm copper -a 50.0 \
        $FNAME_BIN_MASK_SCT -cm yellow

    # Prompt user to approve the masks
    echo -e "\nDo the masks look good?"
    echo "1. Yes"
    echo "2. No, exit program"
    read -p "Enter your choice (1 or 2): " mask_approval

    case $mask_approval in
        1)
            echo -e "\nMasks approved."
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
fi

# File names of the fieldmap
FIELDMAP_PATH="${OUTPUT_PATH}derivatives/fmap/fieldmap.nii.gz"
FIELDMAP_JSON_PATH="${OUTPUT_PATH}derivatives/fmap/fieldmap.json"

# Check if the fieldmap already exists and skip the creation if it does
if [ $VERIFICATION == 1 ] && [ -f "$FIELDMAP_PATH" ] && [ -f "$FIELDMAP_JSON_PATH" ]; then
    echo -e "\nFieldmap already exists. Skipping fieldmap creation and validation..."
else
    # Create fieldmap
    echo -e "\nCreating fieldmap..."
    st_prepare_fieldmap $PHASE1_PATH $PHASE2_PATH \
    --mag $MAGNITUDE_PATH \
    --unwrapper prelude \
    --gaussian-filter true \
    --mask $FNAME_BIN_MASK_SCT_FM \
    --sigma 1 \
    -o $FIELDMAP_PATH

    # Show fieldmap with magnitude
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
fi

# Create output directory for the optimizations
OPTI_OUTPUT_DIR="${OUTPUT_PATH}derivatives/optimizations"
if [ ! -d $OUTPUT_DIR ]; then
    mkdir $OUTPUT_DIR
fi

# Define the masks in a list
masks=(
    "$FNAME_BIN_MASK_SCT"
    "$FNAME_SOFT_MASK_CST_ST"
    "$FNAME_SOFT_MASK_LIN_ST"
    "$FNAME_SOFT_MASK_GSS_ST"
)

# Run the shim for each mask
for mask in "${masks[@]}"
do
    MASK_NAME=$(basename "$mask" .nii.gz)
    OUTPUT_DIR="${OPTI_OUTPUT_DIR}/dynamic_shim_${MASK_NAME}"
    echo -e "\nShimming the fieldmap with mask $MASK_NAME..."
    st_b0shim dynamic \
        --coil $COIL_PATH $COIL_CONFIG_PATH \
        --fmap $FIELDMAP_PATH \
        --anat $MAGNITUDE_PATH \
        --mask "$mask" \
        --mask-dilation-kernel-size 5 \
        --optimizer-method "pseudo_inverse" \
        --slices "auto" \
        --output-file-format-coil "chronological-coil" \
        --output-value-format "absolute" \
        --fatsat "yes" \
        --output "$OUTPUT_DIR"

    # Create two files with the same currents, with and without fatsat
    DYN_CURRENTS_DIR="${OUTPUT_DIR}/coefs_coil0_${COIL_NAME}_no_fatsat.txt"
    DYN_CURRENTS_MODIFIED_DIR="${OUTPUT_DIR}/coefs_coil0_${COIL_NAME}_SAME_CURRENTS_FATSAT.txt"
    fatsat=$(sed -n '1p' "$DYN_CURRENTS_DIR")
    sed 'p' "$DYN_CURRENTS_DIR" > "$DYN_CURRENTS_MODIFIED_DIR"
done

# Remove the sorted dicoms folder
echo -e "\nRemoving sorted dicoms folder..."
rm -r $SORTED_DICOMS_PATH

# End of the script
echo -e "\nProcessing complete. Results saved in $OPTI_OUTPUT_DIR."