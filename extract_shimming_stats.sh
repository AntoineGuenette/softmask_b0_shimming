#!/usr/bin/env bash
echo """
This script extracts the mean, standard deviation, RMSE, and time taken for different mask types from the terminal output file.

It takes one argument:
1. Path to the terminal output file (terminal_results.txt)

Output:
- A dictionary with mask types as keys and their respective statistics as values.
"""

if [ $# -ne 1 ]; then
    echo "Illegal number of parameters"
    echo "Usage: ./extract_shimming_stats.sh <terminal_results.txt>"
    exit 1
fi

FILE="$1"

echo "data = {"

for MASK in seg bin cst lin gss sum; do
  case "$MASK" in
    seg) NAME="segmentation" ;;
    bin) NAME="masque\\nbinaire" ;;
    cst) NAME="constant" ;;
    lin) NAME="linéaire" ;;
    gss) NAME="gaussien" ;;
    sum) NAME="somme" ;;
  esac

  MEAN=$(egrep -i "mask_${MASK}|${MASK}_mask" "$FILE" -A12 | grep -i "percentage increase of the weighted mean" | grep -Eo '[0-9]+\.[0-9]+' | head -1)
  STD=$(egrep -i "mask_${MASK}|${MASK}_mask" "$FILE" -A13 | grep -i "percentage decrease in standard deviation (std)" | grep -Eo '[0-9]+\.[0-9]+' | head -1)
  RMSE=$(egrep -i "mask_${MASK}|${MASK}_mask" "$FILE" -A14 | grep -i "percentage decrease in root mean squared error (rmse)" | grep -Eo '[0-9]+\.[0-9]+' | head -1)
  TIME=$(grep -i "mask (${MASK}) created" "$FILE" | grep -Eo '[0-9]+\.[0-9]+' | head -1)

  echo "    '$NAME': {'mean': ${MEAN:-0.0}, 'std': ${STD:-0.0}, 'rmse': ${RMSE:-0.0}, 'time': ${TIME:-0.0}},"
done

echo "}"