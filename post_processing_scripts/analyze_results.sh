#!/bin/bash

# Check if three arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Illegal number of parameters"
    echo "Usage: ./compare_softmask.sh <dicoms_path> <subject_name> <verficiation>"
    echo "Example: ./compare_softmask.sh /path/to/dicoms subject_name 1"
    exit 1
fi

# Assign the arguments to variables
DICOMS_PATH=$1
SUBJECT_NAME=$2
VERIFICATION=$3

# Set file paths
SCRIPT_DIR=$(dirname "$(realpath "$0")")
OUTPUT_PATH="${DICOMS_PATH%/*}/sub-$SUBJECT_NAME/"
EPI_60vol_DIR_PATH="${DICOMS_PATH%/*}/epi_60vol-$SUBJECT_NAME/"
FMAP_DIR_PATH="${DICOMS_PATH%/*}/fmap-$SUBJECT_NAME/"
SORTED_DICOMS_PATH="${DICOMS_PATH%/*}/sorted_dicoms_opt/"

CATEGORIES=("baseline" "seg" "bin" "2lvl" "lin" "gaus")
for CATEGORY in "${CATEGORIES[@]}"; do
   
    CATEGORY_PATH="$SORTED_DICOMS_PATH/$CATEGORY"
    if [ $VERIFICATION == 1 ] && [ -f "${EPI_60vol_DIR_PATH}/sub-${SUBJECT_NAME}_bold_${CATEGORY}.nii.gz" ] && [ -f "${FMAP_DIR_PATH}/sub-${SUBJECT_NAME}_fmap_${CATEGORY}.nii.gz" ]; then
        echo -e "${CATEGORY} dicoms already sorted and converted to nifti. Skipping these steps...\n"
    else
        # Reorganize dicoms paths
        echo -e "Reorganizing ${CATEGORY} dicoms paths..."
        mkdir -p "$CATEGORY_PATH"
        EPI_PATH=$(find "$DICOMS_PATH" -type d -iname "*ep2d_bold*" -iname "*_${CATEGORY}*")
        FMAP_PATHS=$(find "$DICOMS_PATH" -type d -iname "*gre_fmap_epi*" -iname "*_${CATEGORY}*")

        if [ -d "$EPI_PATH" ]; then
            cp -r "$EPI_PATH" "$CATEGORY_PATH/"
        fi
        for FMAP_PATH in $FMAP_PATHS; do
            if [ -d "$FMAP_PATH" ]; then
                cp -r "$FMAP_PATH" "$CATEGORY_PATH/"
            fi
        done

        DIR_COUNT=$(find "$CATEGORY_PATH" -mindepth 1 -maxdepth 1 -type d | wc -l)
        if [ "$DIR_COUNT" -ne 3 ]; then
            echo "Error: Expected 3 directories for ${CATEGORY} dicoms, but found $DIR_COUNT."
            exit 1
        fi

        echo -e "All ${CATEGORY} dicoms sorted successfully.\n"

        # Convert dicoms to nifti
        NIFTI_PATH="${OUTPUT_PATH}/derivatives/nifti/${CATEGORY}"
        echo -e "Converting ${CATEGORY} dicoms to nifti..."
        st_dicom_to_nifti -i $CATEGORY_PATH --subject $SUBJECT_NAME -o $NIFTI_PATH
        echo -e "All ${CATEGORY} dicoms converted successfully.\n"

        # Move and rename the EPI file
        echo -e "Moving and renaming the EPI file...\n"
        EPI_60vol=$(find $NIFTI_PATH/sub-$SUBJECT_NAME/func -name "sub-${SUBJECT_NAME}_bold.nii.gz")
        
        if [ -f "$EPI_60vol" ]; then
            mkdir -p "$EPI_60vol_DIR_PATH"
            NEW_EPI_60vol="${EPI_60vol_DIR_PATH}/sub-${SUBJECT_NAME}_bold_${CATEGORY}.nii.gz"
            mv "$EPI_60vol" "$NEW_EPI_60vol"
            EPI_60vol="$NEW_EPI_60vol"
        fi
        
        # Move and rename the fieldmap file
        echo -e "Moving and renaming the fieldmap file...\n"
        MAGNITUDE_PATH=$(find $NIFTI_PATH/sub-$SUBJECT_NAME/fmap -name "sub-${SUBJECT_NAME}_magnitude1.nii.gz")
        PHASE1_PATH=$(find $NIFTI_PATH/sub-$SUBJECT_NAME/fmap -name "sub-${SUBJECT_NAME}_phase1.nii.gz")
        PHASE2_PATH=$(find $NIFTI_PATH/sub-$SUBJECT_NAME/fmap -name "sub-${SUBJECT_NAME}_phase2.nii.gz")
        echo -e "\nCreating fieldmap..."

        st_prepare_fieldmap $PHASE1_PATH $PHASE2_PATH \
        --mag $MAGNITUDE_PATH \
        --unwrapper prelude \
        --gaussian-filter true \
        --mask "${OUTPUT_PATH}/derivatives/masks/sct_bin_mask_fm.nii.gz" \
        --sigma 1 \
        -o "${FMAP_DIR_PATH}/sub-${SUBJECT_NAME}_fmap_${CATEGORY}.nii.gz" \

        # Remove unwanted directories if they exist
        echo -e "\nRemoving unwanted directories..."
        for DIR in derivatives sourcedata tmp_dcm2bids sub-$SUBJECT_NAME; do
            if [ -d "$NIFTI_PATH/$DIR" ]; then
                rm -rf "$NIFTI_PATH/$DIR"
            fi
        done

    fi

    # Show fieldmap with magnitude
    echo -e "Displaying ${CATEGORY} fieldmap with EPI image...\n"
    fsleyes \
        "${EPI_60vol_DIR_PATH}/sub-${SUBJECT_NAME}_bold_${CATEGORY}.nii.gz" -cm greyscale \
        "${FMAP_DIR_PATH}/sub-${SUBJECT_NAME}_fmap_${CATEGORY}.nii.gz" -cm brain_colours_diverging_bwr -a 50.0 -dr -100 100

    # Prompt user to approve the fieldmap
    echo -e "Does the fieldmap look good?\n"
    echo "1. Yes"
    echo "2. No, exit program"
    read -p "Enter your choice (1 or 2): " fieldmap_approval

    case $fieldmap_approval in
        1)
            echo -e "Fieldmap approved.\n"
            ;;
        2)
            echo -e "Exiting...\n"
            exit 1
            ;;
        *)
            echo -e "Invalid choice. Exiting...\n"
            exit 1
            ;;
    esac

done

# Remove the NIFTI folder if it exists
if [ -d "${OUTPUT_PATH}/derivatives/nifti" ]; then
    echo -e "\nRemoving sorted NIFTI folder..."
    rm -rf "${OUTPUT_PATH}/derivatives/nifti"
fi

# Remove the sorted dicoms folder if necessary
if [ -d "$SORTED_DICOMS_PATH" ]; then
    echo -e "\nRemoving sorted dicoms folder..."
    rm -r "$SORTED_DICOMS_PATH"
fi

# End of the script
echo -e "\nProcessing complete."