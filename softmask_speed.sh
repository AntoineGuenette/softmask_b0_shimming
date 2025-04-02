#!/bin/bash

echo """
Ce script mesure le temps d'exécution de la segmentation et de la création de différents types de masques.

Prends trois arguments :
1. Chemin vers le dossier contenant l'image anatomique
2. Diamètre du masque binaire
3. Largeur du flou du soft mask
"""

# Vérification de l'entrée des arguments
if [ "$#" -ne 3 ]; then
    echo "Mauvais nombre de paramètres"
    echo "Usage: ./softmask_speed.sh <chemin> <diamètre> <largeur_flou>"
    exit 1
fi

path=$1
size=$2
blur_width=$3

path_anat=$(ls "$path"/*.nii | head -n 1)

# Fichiers temporaires pour stocker les noms des commandes et les temps d'exécution
commands_file=$(mktemp)
times_file=$(mktemp)

measure_time() {
    local cmd_name="$1"
    shift  # Supprime le premier argument pour exécuter la commande réelle
    local start_time=$(date +%s)

    "$@"  # Exécute la commande

    local end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))

    # Stocke les résultats dans des fichiers temporaires
    echo "$cmd_name" >> "$commands_file"
    echo "$elapsed_time" >> "$times_file"
}

echo """
==================================== Création de la segmentation ====================================
"""
measure_time "Segmentation" sct_deepseg \
    -i $path_anat \
    -c t1 \
    -task seg_sc_contrast_agnostic \
    -o ${path}/segmentation.nii.gz

echo """
============================== Création du masque binaire cylindrique ===============================
"""
measure_time "Masque binaire" sct_create_mask \
    -i $path_anat \
    -p centerline,${path}/segmentation.nii.gz \
    -size $size \
    -f cylinder \
    -o ${path}/binmask_deepseg_sub-6_T1w.nii.gz

echo """
==================================== Création du masque gaussien ====================================
"""
measure_time "Masque gaussien" sct_create_mask \
    -i $path_anat \
    -p centerline,${path}/segmentation.nii.gz \
    -size $size \
    -f gaussian \
    -o ${path}/gausmask_deepseg_sub-6_T1w.nii.gz

echo """
=============================== Création du softmask gaussien (SCT) ================================
"""
measure_time "Softmask gaussien SCT" st_mask gaussian-sct-softmask \
    -ib ${path}/binmask_deepseg_sub-6_T1w.nii.gz \
    -ig ${path}/gausmask_deepseg_sub-6_T1w.nii.gz \
    -o ${path}/softmask_gaussct_sub-6_T1w.nii.gz 

echo """
================================== Création du softmask constant ===================================
"""
measure_time "Softmask constant" st_mask create-softmask \
    -i ${path}/binmask_deepseg_sub-6_T1w.nii.gz \
    -o ${path}/softmask_constant_sub-6_T1w.nii.gz \
    -b 'constant' \
    -bw $blur_width

echo """
================================== Création du softmask linéaire ===================================
"""
measure_time "Softmask linéaire" st_mask create-softmask \
    -i ${path}/binmask_deepseg_sub-6_T1w.nii.gz \
    -o ${path}/softmask_linear_sub-6_T1w.nii.gz \
    -b 'linear' \
    -bw $blur_width

echo """
=============================== Création du softmask gaussien (ST) =================================
"""
measure_time "Softmask gaussien ST" st_mask create-softmask \
    -i ${path}/binmask_deepseg_sub-6_T1w.nii.gz \
    -o ${path}/softmask_gaussfilt_sub-6_T1w.nii.gz \
    -b 'gaussian' \
    -bw $blur_width

echo "================================== Résumé des temps d'exécution =================================="
echo -e "\nPour un diamètre de size=$size et une largeur de blur_width=$blur_width :"
paste -d "|" "$commands_file" "$times_file" | while IFS="|" read -r cmd time; do
    echo "$cmd : $time secondes"
done

echo -e "\n=============================== Nettoyage des fichiers temporaires =============================="
rm "$commands_file" "$times_file"

echo -e "\n===================================== Affichage des masques =====================================\n"
fsleyes \
    $path_anat -cm greyscale \
    ${path}/softmask_constant_sub-6_T1w.nii.gz -cm copper -a 50.0 \
    ${path}/softmask_linear_sub-6_T1w.nii.gz -cm copper -a 50.0 \
    ${path}/softmask_gaussfilt_sub-6_T1w.nii.gz -cm copper -a 50.0 \
    ${path}/softmask_gaussct_sub-6_T1w.nii.gz -cm copper -a 50.0 \
    ${path}/binmask_deepseg_sub-6_T1w.nii.gz -cm yellow \
    ${path}/segmentation.nii.gz -cm blue
