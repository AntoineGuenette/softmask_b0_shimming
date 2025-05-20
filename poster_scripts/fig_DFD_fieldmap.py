import nibabel as nib
import numpy as np
import matplotlib.pyplot as plt

# Path to save figures
save_path = '/Users/antoineguenette/Desktop/figures_affiche/fig_DFD_fieldmap'

# Load fieldmap image
nii_fieldmap = nib.load('/Users/antoineguenette/Documents/projet_III/data/sub-acdc262/sub-acdc262/fmap/sub-acdc262_fieldmap.nii.gz')