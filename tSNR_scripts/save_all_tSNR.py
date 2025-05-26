#!/usr/bin/env python3

import os
import csv
import sys

SUBJECT_NAME = sys.argv[1]
SUBJECT_PATH = sys.argv[2]

SCRIPT_PATH = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(SUBJECT_PATH, "all_tSNR_data.csv")

methods = ["Baseline", "DynShim_SCseg", "DynShim_bin", "DynShim_2levels", "DynShim_linear", "DynShim_gauss"]
spinal_map = {
    "2": "C2",
    "3": "C3",
    "4": "C4",
    "5": "C5",
    "6": "C6",
    "7": "C7",
    "8": "T1",
    "9": "T2",
    "10": "T3",
    "11": "T4"
}
baseline_wa_map = {}

def write_csv_row(writer, row):
    writer.writerow(row)

with open(OUTPUT_FILE, "w", newline="") as out_csv:
    writer = csv.writer(out_csv, delimiter=";")
    writer.writerow(["Condition", "VertLevel", "SpinalLevel", "WA", "STD", "WA_improvement"])

    for method in methods:
        print(f"Processing {method}...")

        # Per level
        tsnr_file = os.path.join(SUBJECT_PATH, method, "tSNR", "tSNR_perlevel.csv")
        if os.path.exists(tsnr_file):
            with open(tsnr_file, newline="") as csvfile:
                reader = csv.reader(csvfile)
                next(reader)  # skip header
                for fields in reader:
                    if len(fields) < 10 or not fields[4] or not fields[8] or not fields[9]:
                        continue
                    VertLevel = fields[4].strip().replace('"', '')
                    WA = fields[8].strip().replace('"', '')
                    STD = fields[9].strip().replace('"', '')
                    SpinalLevel = spinal_map.get(VertLevel, "NA")

                    if method == "Baseline":
                        baseline_wa_map[VertLevel] = WA
                        WA_improvement = "-"
                    else:
                        WA_base = baseline_wa_map.get(VertLevel)
                        if WA_base and WA_base != "0":
                            WA_improvement = str((float(WA) - float(WA_base)) / float(WA_base))
                        else:
                            WA_improvement = "NA"

                    write_csv_row(writer, [method, VertLevel, SpinalLevel, WA, STD, WA_improvement])
        else:
            print(f"Warning: {tsnr_file} not found")

        # Mean
        tsnr_file = os.path.join(SUBJECT_PATH, method, "tSNR", "mean_tSNR.csv")
        if os.path.exists(tsnr_file):
            with open(tsnr_file, newline="") as csvfile:
                reader = csv.reader(csvfile)
                next(reader)
                for fields in reader:
                    if len(fields) < 10 or not fields[8] or not fields[9]:
                        continue
                    WA = fields[8].strip().replace('"', '')
                    STD = fields[9].strip().replace('"', '')

                    if method == "Baseline":
                        baseline_wa = WA
                        WA_improvement = "-"
                    else:
                        WA_base = baseline_wa
                        if WA_base and WA_base != "0":
                            WA_improvement = str((float(WA) - float(WA_base)) / float(WA_base))
                        else:
                            WA_improvement = "NA"

                    write_csv_row(writer, [method, "All SC", "All SC", WA, STD, WA_improvement])
        else:
            print(f"Warning: {tsnr_file} not found")

print(f"All data saved in {OUTPUT_FILE}")