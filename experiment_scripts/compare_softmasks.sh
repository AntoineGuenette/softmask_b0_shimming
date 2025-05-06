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

It takes five arguments:
1. The path to the dicoms directory
2. The name / tag of the subject
3. The diameter of the binary mask
4. The width of the blur zone. Must be a multiple of 3.
5. Skip the creation/verification of masks and fieldmap if they already exist (0 for no, 1 for yes)

Outputs:
- Directory with the nifti files (sub-<subject_name>)
It includes all niftis and optimization files (currents for the coil, predicted B0 field, etc.)
"

# Check if five arguments are provided
if [ "$#" -ne 5 ]; then
    echo "Illegal number of parameters"
    echo "Usage: ./compare_softmask.sh <dicoms_path> <subject_name> <diameter> <blur_width> <verification>"
    echo "Example: ./compare_softmask.sh /path/to/dicoms subject_name 25 9 1"
    exit 1
fi

# Assign the arguments to variables
DICOMS_PATH=$1
SUBJECT_NAME=$2
DIAMETER=$3
BLUR_WIDTH=$4
VERIFICATION=$5

# Set file paths
SCRIPT_DIR=$(dirname "$(realpath "$0")")

COIL_PROFILES_DIR="$SCRIPT_DIR/../../coil_profiles"
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
FNAME_SOFT_MASK_GAUSS_SCT="${MASK_DIR}/sct_soft_mask_gauss.nii.gz"
FNAME_SOFT_MASK_SUM_ST="${MASK_DIR}/st_soft_mask_sum.nii.gz"
FNAME_SOFT_MASK_CST_ST="${MASK_DIR}/st_soft_mask_cst.nii.gz"
FNAME_SOFT_MASK_LIN_ST="${MASK_DIR}/st_soft_mask_lin.nii.gz"
FNAME_SOFT_MASK_GSS_ST="${MASK_DIR}/st_soft_mask_gss.nii.gz"

# Check if paths exist and skipping the creation of the masks if they do
if [ $VERIFICATION == 1 ] && [ -f "$FNAME_SEGMENTATION" ]; then
    echo -e "\nSegmentation mask already exists. Skipping creation..."
else
    echo -e "\nCreating segmentation from magnitude image..."
    start_time=$(gdate +%s%3N)
    sct_deepseg -i "${MPRAGE_PATH}" -c t1 -task seg_sc_contrast_agnostic -o "${FNAME_SEGMENTATION}" || exit
    end_time=$(gdate +%s%3N)
    elapsed_time_ms=$((end_time - start_time))
    elapsed_time_sec=$(echo "scale=3; $elapsed_time_ms / 1000" | bc)
    echo -e "\nSegmentation mask (seg) created in $elapsed_time_sec seconds."
fi

if [ $VERIFICATION == 1 ] && [ -f "$FNAME_BIN_MASK_SCT" ]; then
    echo -e "\nBinary mask already exists. Skipping creation..."
else
    echo -e "\nCreating binary mask from segmentation..."
    start_time=$(gdate +%s%3N)
    sct_create_mask -i "${MPRAGE_PATH}" -p centerline,"${FNAME_SEGMENTATION}" -size $DIAMETER -f cylinder -o "${FNAME_BIN_MASK_SCT}" || exit
    end_time=$(gdate +%s%3N)
    elapsed_time_ms=$((end_time - start_time))
    elapsed_time_sec=$(echo "scale=3; $elapsed_time_ms / 1000" | bc)
    echo -e "\nBinary mask (bin) created in $elapsed_time_sec seconds."
fi

if [ $VERIFICATION == 1 ] && [ -f "$FNAME_BIN_MASK_SCT_FM" ]; then
    echo -e "\nBinary mask for fieldmap already exists. Skipping creation..."
else
    echo -e "\nCreating binary mask from segmentation for fieldmap..."
    sct_create_mask -i "${MPRAGE_PATH}" -p centerline,"${FNAME_SEGMENTATION}" -size $((DIAMETER + 2 * BLUR_WIDTH + 15)) -f cylinder -o "${FNAME_BIN_MASK_SCT_FM}" || exit
fi

if [ $VERIFICATION == 1 ] && [ -f "$FNAME_SOFT_MASK_GAUSS_SCT" ]; then
    echo -e "\nGaussian soft mask already exists. Skipping creation..."
else
    echo -e "\nCreating gaussian soft mask from segmentation..."
    sct_create_mask -i "${MPRAGE_PATH}" -p centerline,"${FNAME_SEGMENTATION}" -size $DIAMETER -f gaussian -o "${FNAME_SOFT_MASK_GAUSS_SCT}" || exit
fi

if [ $VERIFICATION == 1 ] && [ -f "$FNAME_SOFT_MASK_SUM_ST" ]; then
    echo -e "\nSum soft mask already exists. Skipping creation..."
else
    echo -e "\nAdding the two previous masks..."
    start_time=$(gdate +%s%3N)
    st_mask create-softmask -i "${FNAME_BIN_MASK_SCT}" -is "${FNAME_SOFT_MASK_GAUSS_SCT}" -o "${FNAME_SOFT_MASK_SUM_ST}" -t 'sum' || exit
    end_time=$(gdate +%s%3N)
    elapsed_time_ms=$((end_time - start_time))
    elapsed_time_sec=$(echo "scale=3; $elapsed_time_ms / 1000" | bc)
    echo -e "\nSum Soft mask (sum) created in $elapsed_time_sec seconds."
fi

if [ $VERIFICATION == 1 ] && [ -f "$FNAME_SOFT_MASK_CST_ST" ]; then
    echo -e "\nConstant soft mask already exists. Skipping creation..."
else
    echo -e "\nCreating constant soft mask from the binary mask..."
    start_time=$(gdate +%s%3N)
    st_mask create-softmask -i "${FNAME_BIN_MASK_SCT}" -o "${FNAME_SOFT_MASK_CST_ST}" -t '2levels' -bw $BLUR_WIDTH || exit
    end_time=$(gdate +%s%3N)
    elapsed_time_ms=$((end_time - start_time))
    elapsed_time_sec=$(echo "scale=3; $elapsed_time_ms / 1000" | bc)
    echo -e "\nConstant soft mask (cst) created in $elapsed_time_sec seconds."
fi

if [ $VERIFICATION == 1 ] && [ -f "$FNAME_SOFT_MASK_LIN_ST" ]; then
    echo -e "\nLinear soft mask already exists. Skipping creation..."
else
    echo -e "\nCreating linear soft mask from the binary mask..."
    start_time=$(gdate +%s%3N)
    st_mask create-softmask -i "${FNAME_BIN_MASK_SCT}" -o "${FNAME_SOFT_MASK_LIN_ST}" -t 'linear' -bw $BLUR_WIDTH || exit
    end_time=$(gdate +%s%3N)
    elapsed_time_ms=$((end_time - start_time))
    elapsed_time_sec=$(echo "scale=3; $elapsed_time_ms / 1000" | bc)
    echo -e "\nLinear soft mask (lin) created in $elapsed_time_sec seconds."
fi

if [ $VERIFICATION == 1 ] && [ -f "$FNAME_SOFT_MASK_GSS_ST" ]; then
    echo -e "\nGaussian soft mask already exists. Skipping creation..."
else
    echo -e "\nCreating gaussian soft mask from the binary mask..."
    start_time=$(gdate +%s%3N)
    st_mask create-softmask -i "${FNAME_BIN_MASK_SCT}" -o "${FNAME_SOFT_MASK_GSS_ST}" -t 'gaussian' -bw $BLUR_WIDTH || exit
    end_time=$(gdate +%s%3N)
    elapsed_time_ms=$((end_time - start_time))
    elapsed_time_sec=$(echo "scale=3; $elapsed_time_ms / 1000" | bc)
    echo -e "\nGaussian soft mask (gss) created in $elapsed_time_sec seconds."
fi

echo -e "\nAll masks checked and created successfully."

# Show masks with magnitude
echo -e "\nDisplaying masks with magnitude image..."
fsleyes \
    $MPRAGE_PATH -cm greyscale \
    $FNAME_SOFT_MASK_CST_ST -cm copper -a 50.0 \
    $FNAME_SOFT_MASK_LIN_ST -cm copper -a 50.0 \
    $FNAME_SOFT_MASK_GSS_ST -cm copper -a 50.0 \
    $FNAME_SOFT_MASK_SUM_ST -cm copper -a 50.0 \
    $FNAME_BIN_MASK_SCT -cm yellow \
    $FNAME_SEGMENTATION -cm blue

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

fi

# Create output directory for the optimizations
OPTI_OUTPUT_DIR="${OUTPUT_PATH}derivatives/optimizations"
if [ ! -d $OUTPUT_DIR ]; then
    mkdir $OUTPUT_DIR
fi

# Run the shim for the segmentation
OUTPUT_DIR="${OPTI_OUTPUT_DIR}/dynamic_shim_segmentation"
echo -e "\nShimming the fieldmap with mask sct_seg_mask..."
st_b0shim dynamic \
    --coil $COIL_PATH $COIL_CONFIG_PATH \
    --fmap $FIELDMAP_PATH \
    --anat $EPI_PATH \
    --mask $FNAME_SEGMENTATION \
    --mask-dilation-kernel-size 3 \
    --optimizer-criteria 'rmse' \
    --optimizer-method "least_squares" \
    --slices "auto" \
    --output-file-format-coil "chronological-coil" \
    --output-value-format "absolute" \
    --fatsat "yes" \
    --regularization-factor 0.3 \
    --output "$OUTPUT_DIR"

# Create two files with the same currents, with and without fatsat
DYN_CURRENTS_DIR="${OUTPUT_DIR}/coefs_coil0_${COIL_NAME}_no_fatsat.txt"
DYN_CURRENTS_MODIFIED_DIR="${OUTPUT_DIR}/coefs_coil0_${COIL_NAME}_SAME_CURRENTS_FATSAT.txt"
fatsat=$(sed -n '1p' "$DYN_CURRENTS_DIR")
sed 'p' "$DYN_CURRENTS_DIR" > "$DYN_CURRENTS_MODIFIED_DIR"

# Define the masks in a list
masks=(
    "$FNAME_BIN_MASK_SCT"
    "$FNAME_SOFT_MASK_SUM_ST"
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
        --anat $EPI_PATH \
        --mask "$mask" \
        --mask-dilation-kernel-size 3 \
        --optimizer-criteria 'rmse' \
        --optimizer-method "least_squares" \
        --slices "auto" \
        --output-file-format-coil "chronological-coil" \
        --output-value-format "absolute" \
        --segmentation-mask "$FNAME_SEGMENTATION" \
        --fatsat "yes" \
        --regularization-factor 0.3 \
        --output "$OUTPUT_DIR"

    # Create two files with the same currents, with and without fatsat
    DYN_CURRENTS_DIR="${OUTPUT_DIR}/coefs_coil0_${COIL_NAME}_no_fatsat.txt"
    DYN_CURRENTS_MODIFIED_DIR="${OUTPUT_DIR}/coefs_coil0_${COIL_NAME}_SAME_CURRENTS_FATSAT.txt"
    fatsat=$(sed -n '1p' "$DYN_CURRENTS_DIR")
    sed 'p' "$DYN_CURRENTS_DIR" > "$DYN_CURRENTS_MODIFIED_DIR"
done

# Remove the sorted dicoms folder if necessary
if [ -d "$SORTED_DICOMS_PATH" ]; then
    echo -e "\nRemoving sorted dicoms folder..."
    rm -r "$SORTED_DICOMS_PATH"
fi

# End of the script
echo -e "\nProcessing complete. Results saved in $OPTI_OUTPUT_DIR."