*** Make sure you are in the repo before starting ***

### How to run

1. Change the directory to this folder
```
cd ./experiment_script/
```

2. Execute the script. Here is how you must call each script :

* [compare_softmasks_pbox.sh](https://github.com/AntoineGuenette/softmask_b0_shimming/blob/main/experiment_scripts/compare_softmasks_pbox.sh) : This script is used with a phantom to compare dynamic B0 shimming using different softmask types. The binary mask is a sphere with a radius specified by the user.
```
./compare_softmasks_pbox.sh <dicoms_path> <subject_name> <radius> <blur_width> <verification>
```

* [compare_softmasks_thr.sh](https://github.com/AntoineGuenette/softmask_b0_shimming/blob/main/experiment_scripts/compare_softmasks_pthr.sh) : This script is used with a phantom to compare dynamic B0 shimming using different softmask types. The binary mask is created with a threshold value specified by the user.
```
./compare_softmasks_pthr.sh <dicoms_path> <subject_name> <threshold> <blur_width> <verification>
```

* [compare_softmasks.sh](https://github.com/AntoineGuenette/softmask_b0_shimming/blob/main/experiment_scripts/compare_softmasks.sh) : This script is used with a human subject to compare dynamic B0 shimming using different softmask types.
```
./compare_softmasks.sh <dicoms_path> <subject_name> <diameter[mm]> <blur_width[mm]> <verification>
```

* [compare_ponderations.sh](https://github.com/AntoineGuenette/softmask_b0_shimming/blob/main/experiment_scripts/compare_ponderations.sh) : This script is used with a human subject to compare dynamic B0 shimming using different ponderations for a two-level softmask.
```
./compare_ponderations.sh <dicoms_path> <subject_name> <diameter[mm]> <blur_width[mm]> <verification>
```

* [run_realtime_shim.sh](https://github.com/AntoineGuenette/softmask_b0_shimming/blob/main/experiment_scripts/run_realtime_shim.sh) : This script is used with a phantom to compare dynamic B0 real-time shimming with a binary mask and a softmask.
```
./run_realtime_shim.sh <dicoms_path> <subject_name> <size> <center> <blur_width> <verification>
```