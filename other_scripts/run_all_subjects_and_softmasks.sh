#!/bin/bash

echo -e "\n--- RUNNING ALL SOFTMASKS FOR SUBJECT 01 --- "

echo -e "\n--- RUNNING 2 LEVELS SOFTMASK ---\n"
../experiment_scripts/softmask_shim.sh /Users/antoineguenette/Desktop/démonstration_projet_III/Sujets/01 01 25 9 2levels 1
echo -e "\n--- RUNNING LINEAR SOFTMASK ---\n"
../experiment_scripts/softmask_shim.sh /Users/antoineguenette/Desktop/démonstration_projet_III/Sujets/01 01 25 9 linear 1
echo -e "\n--- RUNNING GAUSSIAN SOFTMASK ---\n"
../experiment_scripts/softmask_shim.sh /Users/antoineguenette/Desktop/démonstration_projet_III/Sujets/01 01 25 9 gaussian 1
echo -e "\n--- RUNNING HYBRID SOFTMASK ---\n"
../experiment_scripts/softmask_shim.sh /Users/antoineguenette/Desktop/démonstration_projet_III/Sujets/01 01 25 9 hybrid 1

echo -e "\n--- RUNNING ALL SOFTMASKS FOR SUBJECT 02 ---\n"

echo -e "\n--- RUNNING 2 LEVELS SOFTMASK ---\n"
../experiment_scripts/softmask_shim.sh /Users/antoineguenette/Desktop/démonstration_projet_III/Sujets/02 02 25 9 2levels 1
echo -e "\n--- RUNNING LINEAR SOFTMASK ---\n"
../experiment_scripts/softmask_shim.sh /Users/antoineguenette/Desktop/démonstration_projet_III/Sujets/02 02 25 9 linear 1
echo -e "\n--- RUNNING GAUSSIAN SOFTMASK ---\n"
../experiment_scripts/softmask_shim.sh /Users/antoineguenette/Desktop/démonstration_projet_III/Sujets/02 02 25 9 gaussian 1
echo -e "\n--- RUNNING HYBRID SOFTMASK ---\n"
../experiment_scripts/softmask_shim.sh /Users/antoineguenette/Desktop/démonstration_projet_III/Sujets/02 02 25 9 hybrid 1
