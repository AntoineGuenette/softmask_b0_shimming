#!/usr/bin/env bash

# This script extracts the mean, standard deviation, RMSE, and time taken for different mask types
# from multiple terminal output .txt files within a directory.

# It takes one argument:
# 1. Path to the directory containing terminal output files (*.txt)

# Output:
# - A dictionary with mask types as keys and the average of their respective statistics across all files.

if [ $# -ne 1 ]; then
    echo "Illegal number of parameters"
    echo "Usage: ./extract_shimming_stats.sh <directory_path>"
    exit 1
fi

DIR="$1"

declare -A sum_mean sum_std sum_rmse sum_time count

for FILE in "$DIR"/*.txt; do
  echo "Processing file: $FILE"
  for MASK in seg bin cst lin gss sum; do
    case "$MASK" in
      seg) NAME="segmentation_binaire" ;;
      bin) NAME="masque_binaire_cylindrique" ;;
      cst) NAME="masque_discret_a_deux_niveaux" ;;
      lin) NAME="masque_continu_lineaire" ;;
      gss) NAME="masque_continu_gaussien" ;;
      sum) NAME="masque_hybride_binaire_gaussien" ;;
    esac

    MEAN=$(egrep -i "mask_${MASK}|${MASK}_mask" "$FILE" -A12 | grep -i "percentage increase of the weighted mean" | grep -Eo '[0-9]+\.[0-9]+' | head -1)
    STD=$(egrep -i "mask_${MASK}|${MASK}_mask" "$FILE" -A13 | grep -i "percentage decrease in standard deviation (std)" | grep -Eo '[0-9]+\.[0-9]+' | head -1)
    RMSE=$(egrep -i "mask_${MASK}|${MASK}_mask" "$FILE" -A14 | grep -i "percentage decrease in root mean squared error (rmse)" | grep -Eo '[0-9]+\.[0-9]+' | head -1)
    TIME=$(grep -i "mask (${MASK}) created" "$FILE" | grep -Eo '[0-9]+\.[0-9]+' | head -1)

    key="$NAME"
    sum_mean["$key"]=$(echo "${sum_mean["$key"]:-0} + ${MEAN:-0}" | bc)
    sum_std["$key"]=$(echo "${sum_std["$key"]:-0} + ${STD:-0}" | bc)
    sum_rmse["$key"]=$(echo "${sum_rmse["$key"]:-0} + ${RMSE:-0}" | bc)
    sum_time["$key"]=$(echo "${sum_time["$key"]:-0} + ${TIME:-0}" | bc)
    count["$key"]=$(( ${count["$key"]:-0} + 1 ))
  done
done

echo "data = {"
for key in "segmentation_binaire" "masque_binaire_cylindrique" "masque_discret_a_deux_niveaux" "masque_continu_lineaire" "masque_continu_gaussien" "masque_hybride_binaire_gaussien"; do
  avg_mean=$(LC_NUMERIC=C printf "%.2f" $(echo "scale=6; ${sum_mean["$key"]} / ${count["$key"]}" | bc))
  avg_std=$(LC_NUMERIC=C printf "%.2f" $(echo "scale=6; ${sum_std["$key"]} / ${count["$key"]}" | bc))
  avg_rmse=$(LC_NUMERIC=C printf "%.2f" $(echo "scale=6; ${sum_rmse["$key"]} / ${count["$key"]}" | bc))
  avg_time=$(LC_NUMERIC=C printf "%.3f" $(echo "scale=6; ${sum_time["$key"]} / ${count["$key"]}" | bc))
  echo "    '$key': {'mean': $avg_mean, 'std': $avg_std, 'rmse': $avg_rmse, 'time': $avg_time},"
done
echo "}"