# Neuroimaging
### Processing neuroimaging data in R example, 2022.

Includes reading in and viewing DICOM images, converting to NIfTI, adjusting voxel intensity values, performing and evaluating different inhomogeneity  correction methods, skull stripping/brain extraction, automatic tissue  segmentation, atlas registration, Gaussian smoothing, and white and gray matter volume estimation.

The only download required before starting is [FSL software](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/). All other downloads—including retrieving sample data—occur within [the R script](https://github.com/AlexandraBatzdorf/Neuroimaging/blob/main/Processing_Script.R).

This script is meant for a single case, but it can be modified easily to construct a batch processing pipeline.

## Required R packages: 
[oro.dicom](https://cran.r-project.org/package=oro.dicom), [oro.nifti](https://cran.r-project.org/package=oro.nifti), [devtools](https://cran.r-project.org/package=devtools), [neurobase*](https://github.com/muschellij2/neurobase), [cmaker*](https://github.com/stnava/cmaker), [ITKR*](https://github.com/stnava/ITKR), [ANTsR*](https://github.com/ANTsX/ANTsR), [extransr*](https://github.com/muschellij2/extrantsr), [papayar*](https://github.com/muschellij2/papayar), [fslr*](https://github.com/muschellij2/fslr), [reshape2](https://cran.r-project.org/package=reshape2), [ggplot2](https://cran.r-project.org/package=ggplot2), [qpdf](https://cran.r-project.org/package=qpdf), [viridis](https://cran.r-project.org/package=viridis)  
*Hosted on GitHub.

[FSL software](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/) is required.

## Input flies:
[BRAINIX sample data](https://codeload.github.com/AlexandraBatzdorf/BRAINIX/zip/refs/heads/main) is available through [OsiriX](https://www.osirix-viewer.com/resources/dicom-image-library/).  
[Reference atlas](http://www.bic.mni.mcgill.ca/~vfonov/icbm/2009/mni_icbm152_nlin_asym_09b_nifti.zip) (MNI 152 T1w, 0.5mm, asymmetrical) can be retrieved from NIST.

## Compatibility:  
Tested on a Mac running OS Monterey 12.1 using R version 4.0.2. Several utilized R packages hosted on GitHub are configured for Mac or Linux. If running R version 4.1 or later, it is highly recomended to switch active R version to 4.0 using, e.g., [RSwitch](https://rud.is/rswitch/).
