#!/usr/bin/env bash
echo "Choisissez une option pour l'obtention du centerline ('optic' ou 'viewer') : "
read choice
mode=""
case "$choice" in
    optic) mode="optic" ;;
    viewer) mode="viewer" ;;
    *) echo "Option invalide. Veuillez entrer 'svm', 'cnn' ou 'viewer'." ;;
esac

if [ -n "$mode" ]; then
    sct_get_centerline \
                -i sub-6_T1w.nii \
                -c t1 \
                -method ${mode} \
                -o centerline_${mode}.nii.gz
    sct_create_mask \
        -i  sub-6_T1w.nii \
        -p centerline,centerline_${mode}.nii.gz \
        -size 20 \
        -f cylinder \
        -o binmask_${mode}_cylinder_sub-6_T1w.nii.gz
    sct_create_mask \
        -i  sub-6_T1w.nii \
        -p centerline,centerline_${mode}.nii.gz \
        -size 20 \
        -f gaussian \
        -o binmask_${mode}_gaussian_sub-6_T1w.nii.gz
    fsleyes \
        sub-6_T1w.nii -cm greyscale \
        centerline_${mode}.nii.gz -cm blue -a 70.0 \
        binmask_${mode}_cylinder_sub-6_T1w.nii.gz -cm yellow -a 50.0 \
        binmask_${mode}_gaussian_sub-6_T1w.nii.gz -cm copper -a 50.0
fi
