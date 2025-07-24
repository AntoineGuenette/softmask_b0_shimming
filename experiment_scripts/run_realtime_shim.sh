#!/bin/bash

# This script runs the entire experiment for a given subject. It is meant to be run from the command line after
# the baseline MPrage, the baseline field map. Your dicom folder should be organized as follows:

# dicoms
# ├── 01_baseline_mprage_t1w (mag)
# │   ├── dicom1
# │   ├── dicom2
# │   └── ...
# ├── 02_baseline_GRE (mag)
# │   ├── dicom1
# │   ├── dicom2
# │   └── ...
# |── 03_baseline_GRE (phase)
# |    ├── dicom1
# |    ├── dicom2
# |    └── ...

# It takes five arguments:
# 1. The path to the dicoms directory
# 2. The name / tag of the subject
# 3. The size of the binary mask
# 3. The center of the binary mask
# 4. The width of the blur zone. Must be a multiple of 3.
# 5. Skip the creation/verification of masks and fieldmap if they already exist (0 for no, 1 for yes)

# Outputs:
# - Directory with the nifti files (sub-<subject_name>)
# It includes all niftis and optimization files (currents for the coil, predicted B0 field, etc.)

# Check if five arguments are provided
if [ "$#" -ne 6 ]; then
    echo "Illegal number of parameters"
    echo "Usage: $0 <dicoms_path> <subject_name> <size> <center> <blur_width> <verification>"
    echo "Example: $0 /path/to/dicoms subject_name '10,10,10' '0,0,0' 6 1"
    exit 1
fi

# Assign the arguments to variables
DICOMS_PATH=$1
SUBJECT_NAME=$2
SIZE=$3
IFS=',' read -r -a SIZE_ARR <<< "$SIZE"
CENTER=$4
IFS=',' read -r -a CENTER_ARR <<< "$CENTER"
BLUR_WIDTH=$5
VERIFICATION=$6

# Set file paths
SCRIPT_DIR=$(dirname "$(realpath "$0")")
# COIL_PROFILES_DIR="$SCRIPT_DIR/../../coil_profiles"
# COIL_PATH="${COIL_PROFILES_DIR}/coil_profiles_NP15.nii.gz"
# COIL_CONFIG_PATH="${COIL_PROFILES_DIR}/NP15_config.json"
# COIL_NAME="$(grep '"name"' "$COIL_CONFIG_PATH" | sed -E 's/.*"name": *"([^"]+)".*/\1/')"
# echo Name of the chosen coil : $COIL_NAME
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
RESP_PATH=$(find "${OUTPUT_PATH}sourcedata" -name "*.resp")
MAGNITUDE_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}"/fmap -name "*magnitude1.nii.gz")
PHASE1_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}"/fmap -name "*phase1.nii.gz")
PHASE2_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}"/fmap -name "*phase2.nii.gz")
ANAT_PATH=$(find "${OUTPUT_PATH}sub-${SUBJECT_NAME}"/anat -name "*magnitude1.nii.gz")

# Check if the files exist
if [ -z "$MAGNITUDE_PATH" ] || [ -z "$PHASE1_PATH" ] || [ -z "$PHASE2_PATH" ] || [ -z "$ANAT_PATH" ]; then
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
FNAME_BIN_MASK="${MASK_DIR}/bin_mask.nii.gz"
FNAME_SOFT_MASK="${MASK_DIR}/soft_mask.nii.gz"
FNAME_BIN_MASK_FM="${MASK_DIR}/bin_mask_fm.nii.gz"

# Check if paths exist and skipping the creation of the masks if they do
if [ $VERIFICATION == 1 ] && [ -f "$FNAME_SEGMENTATION" ]; then
    echo -e "\nSegmentation mask already exists. Skipping creation..."
else
    echo -e "\nCreating segmentation from magnitude image..."
    st_mask box -i "${ANAT_PATH}" \
        --size ${SIZE_ARR[0]} ${SIZE_ARR[1]} ${SIZE_ARR[2]} \
        --center ${CENTER_ARR[0]} ${CENTER_ARR[1]} ${CENTER_ARR[2]} \
        -o "${FNAME_SEGMENTATION}" || exit
fi

if [ $VERIFICATION == 1 ] && [ -f "$FNAME_BIN_MASK" ]; then
    echo -e "\nBinary mask already exists. Skipping creation..."
else
    echo -e "\nCreating binary mask from segmentation..."
    st_mask softmask -i "${FNAME_SEGMENTATION}" -o "${FNAME_BIN_MASK}" -t '2levels' -w "$BLUR_WIDTH" -u 'mm' -b 1 || exit
fi

if [ $VERIFICATION == 1 ] && [ -f "$FNAME_SOFT_MASK" ]; then
    echo -e "\nsoft mask already exists. Skipping creation..."
else
    echo -e "\nCreating soft mask from segmentation..."
    st_mask softmask -i "${FNAME_SEGMENTATION}" -o "${FNAME_SOFT_MASK}" -t '2levels' -w $BLUR_WIDTH -u 'mm' -b 0.1 || exit
fi

if [ $VERIFICATION == 1 ] && [ -f "$FNAME_BIN_MASK_FM" ]; then
    echo -e "\nBinary mask for fieldmap already exists. Skipping creation..."
else
    echo -e "\nCreating binary mask for fieldmap from binary mask..."
    st_mask softmask -i "${FNAME_BIN_MASK}" -o "${FNAME_BIN_MASK_FM}" -t '2levels' -w "$BLUR_WIDTH" -u 'mm' -b 1 || exit

fi

echo -e "\nAll masks checked and created successfully."

# Show masks with magnitude
echo -e "\nDisplaying masks with magnitude image..."
fsleyes \
    $ANAT_PATH -cm greyscale \
    $FNAME_SOFT_MASK -cm copper -a 50.0 \
    $FNAME_BIN_MASK -cm copper -a 50.0 \

# Promp user to approve the masks
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

# File names of the fieldmap
FIELDMAP_PATH="${OUTPUT_PATH}derivatives/fmap/fieldmap.nii.gz"
FIELDMAP_JSON_PATH="${OUTPUT_PATH}derivatives/fmap/fieldmap.json"

# Check if the fieldmap already exists and skip the creation if it does
if [ $VERIFICATION == 1 ] && [ -f "$FIELDMAP_PATH" ] && [ -f "$FIELDMAP_JSON_PATH" ]; then
    echo -e "\nFieldmap already exists. Skipping fieldmap creation..."
else
    # Create fieldmap
    echo -e "\nCreating fieldmap..."
    st_prepare_fieldmap $PHASE1_PATH $PHASE2_PATH \
     --mag $MAGNITUDE_PATH \
     --unwrapper prelude \
     --gaussian-filter true \
     --mask $FNAME_BIN_MASK_FM \
     --sigma 1 \
     -o $FIELDMAP_PATH
fi

# Show fieldmap with magnitude
echo -e "\nDisplaying fieldmap with magnitude image..."
fsleyes \
    $MAGNITUDE_PATH -cm greyscale \
    $FIELDMAP_PATH -cm brain_colours_diverging_bwr -a 50.0 -dr -100 100

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

# Run the shim for the binary masks
OUTPUT_DIR="${OPTI_OUTPUT_DIR}/dynamic_shim_binary_masks"
echo -e "\nShimming the fieldmap with binary masks..."
st_b0shim realtime-dynamic \
    --scanner-coil-order 0,1 \
    --scanner-coil-order-riro 0,1 \
    --fmap $FIELDMAP_PATH \
    --target $ANAT_PATH \
    --mask-static "$FNAME_BIN_MASK" \
    --mask-riro "$FNAME_BIN_MASK" \
    --mask-dilation-kernel-size 3 \
    --resp $RESP_PATH \
    --optimizer-criteria 'rmse' \
    --optimizer-method "least_squares" \
    --slices "auto" \
    --output-file-format-scanner "chronological-coil" \
    --output-value-format "absolute" \
    --fatsat "yes" \
    --regularization-factor 0.3 \
    --output "$OUTPUT_DIR" \
    --verbose 'debug'

# Run the shim for the soft masks
OUTPUT_DIR="${OPTI_OUTPUT_DIR}/dynamic_shim_soft_masks"
echo -e "\nShimming the fieldmap with soft masks..."
st_b0shim realtime-dynamic \
    --scanner-coil-order 0,1 \
    --scanner-coil-order-riro 0,1 \
    --fmap $FIELDMAP_PATH \
    --target $ANAT_PATH \
    --mask-static "$FNAME_SOFT_MASK" \
    --mask-riro "$FNAME_SOFT_MASK" \
    --mask-dilation-kernel-size 3 \
    --resp $RESP_PATH \
    --optimizer-criteria 'rmse' \
    --optimizer-method "least_squares" \
    --slices "auto" \
    --output-file-format-scanner "chronological-coil" \
    --output-value-format "absolute" \
    --fatsat "yes" \
    --regularization-factor 0.3 \
    --output "$OUTPUT_DIR" \
    --verbose 'debug'

# Remove the sorted dicoms folder if necessary
if [ -d "$SORTED_DICOMS_PATH" ]; then
    echo -e "\nRemoving sorted dicoms folder..."
    rm -r "$SORTED_DICOMS_PATH"
fi

# End of the script
echo -e "\nProcessing complete. Results saved in $OPTI_OUTPUT_DIR."