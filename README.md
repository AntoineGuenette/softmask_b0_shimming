# softmask_b0_shimming

This repository contains a set of scripts developed to analyze MRI data and generate figures comparing dynamic shimming techniques using different types of masks (binary and soft). The project was carried out as part of the GBM3100 _Projet individuel en génie biomédical_ course at Polytechnique Montréal, in collaboration with the [NeuroPoly](https://neuro.polymtl.ca) lab.

> [!NOTE]  
> The bash scripts can only be run on Unix-based operating systems.

### Before starting

Before using these scripts, you need to:
1. Install dependencies
* [Anaconda or Miniconda](https://www.anaconda.com/download/success)
* [Shimming Toolbox's v1.2](https://github.com/shimming-toolbox/shimming-toolbox/releases/tag/v1.2)
```
git clone -b v1.2 https://github.com/shimming-toolbox/shimming-toolbox/ ~/shimming-toolbox/
cd ~/shimming-toolbox/
make install
```
>[!NOTE]
> If you already have Shimming Toolbox installed, please remove it from your directory before cloning the repository.
```
rm -rf ~/shimming-toolbox/
```
* [SCT v7.0](https://github.com/spinalcordtoolbox/spinalcordtoolbox/releases/tag/7.0)
```
git clone -b 7.0 https://github.com/spinalcordtoolbox/spinalcordtoolbox/ ~/spinalcordtoolbox/
cd ~/spinalcordtoolbox/
./install_sct
```
* [FSL](https://fsl.fmrib.ox.ac.uk/fsl/docs/#/install/index) (follow instructions on their website)
2. Clone the GitHub repository
```
cd <path_to_where_you_want_the_repository>
git clone https://github.com/shimming-toolbox/spinalcord-signal-recovery.git
```
3. Move to the repository
```
cd spinalcord-signal-recovery
```
4. Create a conda environment using the env.yml file
```
conda env create -n <name_of_your_env> -f env.yml
```
5. Activate the new environment
```
conda activate <name_of_your_env>
```

### How to use

Here are all the script folders :
* [experiment_scripts](https://github.com/AntoineGuenette/softmask_b0_shimming/tree/main/experiment_scripts): These scripts are used at the scanner during the acquisition to obtain the shimming coefficients
* [figure_scripts](https://github.com/AntoineGuenette/softmask_b0_shimming/tree/main/figure_scripts): Generate figures for comparing shimming techniques
* [post_processing_scripts](https://github.com/AntoineGuenette/softmask_b0_shimming/tree/main/post_processing_scripts): Process the data
* [tSNR_scripts](https://github.com/AntoineGuenette/softmask_b0_shimming/tree/main/tSNR_scripts): Process the data to generate tSNR measurements
* [poster_scripts](https://github.com/AntoineGuenette/softmask_b0_shimming/tree/main/poster_scripts): Generate figures for the project presentation poster 
