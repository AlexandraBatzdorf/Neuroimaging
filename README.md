# Neuroimaging
Processing neuroimaging data in R example, 2022.

Includes reading in and viewing DICOM images, converting to NIfTI, adjusting
voxel intensity values, performing and evaluating different inhomogeneity 
correction methods, skull stripping/brain extraction, automatic tissue 
segmentation, atlas registration, Gaussian smoothing, and white and gray
matter volume estimation.

The only download required before starting is [FSL software](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/). All other downloads—including retrieving sample data—occur within the R script.

### Required R packages: 
devtools, [cmaker*](https://github.com/stnava/cmaker), [ITKR*](https://github.com/stnava/ITKR), [ANTsR*](https://github.com/ANTsX/ANTsR), [extransr*](https://github.com/muschellij2/extrantsr), [papayar*](https://github.com/muschellij2/papayar), oro.dicom, oro.nifti,
reshape2, ggplot2, neurobase, qpdf, fslr, viridis  
*Hosted on GitHub.

[FSL software](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/) is required.

### Input flies:
[BRAINIX sample data](https://www.osirix-viewer.com/resources/dicom-image-library/) is available through OSIRIX.  
[Reference atlas](http://www.bic.mni.mcgill.ca/~vfonov/icbm/2009/mni_icbm152_nlin_asym_09b_nifti.zip) (MNI 152 T1w, 0.5mm, asymmetrical) can be retrieved from NIST.
