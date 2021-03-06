## Alexandra Batzdorf, Processing Neuroimaging Data in R Example, 2022
# FSL software is required: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/
# Required R packages: oro.dicom, oro.nifti, devtools, neurobase*, cmaker*, ITKR*, 
# ANTsR*, extrantsr*, papayar*, fslr*, reshape2, ggplot2, qpdf, viridis
# *Hosted on GitHub.



# Download BRAINIX sample data, which is available through OsiriX: 
# https://www.osirix-viewer.com/resources/dicom-image-library/
{download.file(url="https://tinyurl.com/BRAINIXimages", destfile='~/BRAINIX.zip')
unzip(zipfile='~/BRAINIX.zip', exdir='~/')}


# Download MNI reference atlas (MNI 152 T1w, 0.5mm, asymmetrical), which 
# can be retrieved from NIST: 
# http://www.bic.mni.mcgill.ca/~vfonov/icbm/2009/mni_icbm152_nlin_asym_09b_nifti.zip
{download.file(url="https://tinyurl.com/MNIatlas", destfile='~/MNI.zip')
unzip(zipfile='~/MNI.zip', exdir='~/')}


# Install required GitHub packages. (Note: they may take several minutes 
# to install.)
{if (!require(oro.dicom)) {install.packages("oro.dicom"); require(oro.dicom)}
  if (!require(oro.nifti)) {install.packages("oro.nifti"); require(oro.nifti)}
  if (!require(devtools)) {install.packages("devtools"); require(devtools)}
  if (!require(ANTsR) | !require(extrantsr)) {
    devtools::install_github("muschellij2/neurobase"); require(neurobase)
    devtools::install_github("stnava/cmaker"); require(cmaker)
    devtools::install_github("stnava/ITKR"); require(ITKR)
    devtools::install_github("stnava/ANTsR"); require(ANTsR)
    devtools::install_github("muschellij2/extrantsr"); require(extrantsr)
  } else {
    require(ANTsR); require(extrantsr)
  }
  if (!require(papayar)) {devtools::install_github("muschellij2/papayar") 
    require(papayar)}
  if (!require(fslr)) {devtools::install_github("muschellij2/fslr"); require(fslr)}
  options(fsl.path="/usr/local/fsl")}


# Read in DICOM images.
T1.example <- readDICOM("~/BRAINIX-main/DICOM/T1/")


# Convert DICOMs to NIfTI format.
T1.nifti <- dicom2nifti(T1.example)


# Save compressed NIfTI file.
{dir.create("~/BRAINIX-main/T1_Processing_Output")
  output.path <- "~/BRAINIX-main/T1_Processing_Output"
  setwd(output.path)
  writeNIfTI(nim=T1.nifti, filename="T1_NIfTI")}


# Visualize a few slices of the NIfTI file in a lightbox layout.
image(T1.nifti, z=c(8, 12, 15, 18), plot.type="single")
# View orthographic projections of image stacks in all three planes,
orthographic(T1.nifti, crosshairs=F)
# or scroll through slices interactively.
papaya(list(T1.nifti), daemon=T)


# Check the histograms of voxel intensities--both all intensities and those >15--to 
# make sure everything looks okay.
# First, create a data frame containing both the full set of voxel intensities and
# just those >15.
{if (!require(reshape2)) {install.packages("reshape2"); library(reshape2)}
  NIfTI.df <- function(nii, minval) {
    min.excl <- c(nii[nii>minval])
    length(min.excl) <- max(length(min.excl), length(c(nii)))
    niivals <- cbind(full=c(nii), min.excl)
    niivals <- data.frame(niivals)
    colnames(niivals) <- c("Initial Values", 
                           paste('Initial', 'Values', '>', minval))
    df <- melt(niivals)
  }
  T1.df <- NIfTI.df(T1.nifti, 15)}
# Next, plot the values.
# Set the theme elements.
{if (!require(ggplot2)) {install.packages("ggplot2"); library(ggplot2)}
  Theme <- theme_classic() + 
    theme(text=element_text(size=10, family="sans", color="black", face="bold"),
          strip.text.x=element_text(size=10, family="sans", color="black",
                                    face="bold", hjust=0.5),
          strip.background=element_blank(), line=element_line(color="black"),
          axis.text=element_text(size=10, family="sans", color="black",
                                 face="bold"),
          axis.ticks=element_line(size=1, color="black"),
          panel.border=element_rect(color="black", fill=NA, size=2), 
          legend.key=element_blank(), legend.background=element_blank(),
          legend.title=element_text(size=8, family="sans", color="black", 
                                    face="bold"), 
          legend.text=element_text(size=8, family="sans", color="black",
                                   face="bold"),
          legend.title.align=0.5, legend.justification=c(1,1), 
          legend.position=c(1,1))}
# Create the graphs. (Note the different y-axes.)
{intensity.hist <-
  ggplot(data=T1.df, aes(x=value, y=..density..)) +
    geom_histogram(fill="red", color="black", na.rm=T, bins=40, alpha=0.7) +
    facet_wrap(~variable, scales="free_y") +
    labs(x="Voxel Intensity (AU)", y="Density") +
    scale_x_continuous(limits=c(-25, 1900)) +
    Theme
  ggsave("Initial_Voxel_Intensities.pdf", plot=intensity.hist, device="pdf",
         width=5, height=3, units='in')
  intensity.hist}


# Adjust the voxel intensity values using a linear spline function (modification 
# of lin.sp function from github.com/muschellij2).
lin.spline <- function(x, spline.knots, spline.slopes) {
  spline.knots <- c(min(x), spline.knots, max(x))
  slopeS <- spline.slopes[1]
  for(j in 2:length(spline.slopes)) {
    slopeS <- c(slopeS, spline.slopes[j] - sum(slopeS))
  }
  rvals <- numeric(length(x))
  for(i in 2:length(spline.knots)) {
    rvals <- ifelse(x>=spline.knots[i-1], slopeS[i-1]*(x - spline.knots[i-1]) + rvals, rvals)
  }
  return(rvals)
}
# Set the desired values.
{spline.knots <- c(.3, .6); spline.slopes <- c(1, .5, .25)
  T1.spline <- lin.spline(T1.nifti, spline.knots*max(T1.nifti), spline.slopes)
  writeNIfTI(nim=T1.spline, filename="T1_Spline")}


# View the linear spline transformation curve.
# First, create a log-transformed histogram of original (red) and transformed
# (blue) voxel intensities.
{T1.df.full <- subset(T1.df, variable=="Initial Values")
  T1.spline.df <- NIfTI.df(T1.spline, 15)
  T1.spline.full <- subset(T1.spline.df, variable=="Initial Values")
  T1.spline.transform <- cbind('Initial Values'=T1.df.full$value,
                               'Spline-Transformed Values'=T1.spline.full$value)
  T1.spline.transform <- data.frame(T1.spline.transform)
  T1.transform.df <- melt(T1.spline.transform)
  hist.log <-
  ggplot(data=T1.transform.df, aes(x=value)) +
    geom_histogram(aes(y=log1p(..count..), fill=variable, alpha=variable,
                   color=variable), position="identity", na.rm=T, bins=40) +
    labs(x="Voxel Intensity (AU)", y="Log-Transformed Count") +
    scale_x_continuous(limits=c(-120.7692, 2100), expand=c(0,0)) +
    scale_fill_manual(labels=c("Initial Values", "Spline-Transformed Values"),
                      values=c("red", "blue"), guide=guide_legend(nrow=1)) + 
    scale_alpha_manual(labels=c("Initial Values", "Spline-Transformed Values"), 
                       values = c(0.7, 0.5), guide=guide_legend(nrow=1)) +
    scale_color_manual(labels=c("Initial Values", "Spline-Transformed Values"),
                       values=c("red3", "blue4"), guide=guide_legend(nrow=1)) +
    Theme +
    theme(legend.title=element_blank(), aspect.ratio=1/1)
  hist.log}
# Extract the scaling factor for the spline curve from the log-transformed
# histogram to overlay the spline transformation curve.
{init.vals <- T1.spline.transform$Initial.Values[
    T1.spline.transform$Initial.Values>0]
  length(init.vals) <- max(length(init.vals), length(T1.transform.df$value))
  T1.transform.df$initial.vals <- init.vals
  scaling.factor <- function(values.to.scale, original.scale, new.scale) {
    scaling <- ((max(values.to.scale, na.rm=T)/max(original.scale, na.rm=T))*
                max(new.scale, na.rm=T))/max(values.to.scale, na.rm=T)
  }
  hist.log.build <- ggplot_build(hist.log)$layout$panel_params[[1]]
  hist.scaling.factor <- scaling.factor(T1.spline.full$value, 
                         hist.log.build$x.range, hist.log.build$y.range)
  spline.logscaled <- hist.scaling.factor*
    T1.spline.transform$Spline.Transformed.Values[
      T1.spline.transform$Spline.Transformed.Values>0]
  length(spline.logscaled) <- max(length(spline.logscaled), 
                                  length(T1.transform.df$value))
  T1.transform.df$spline.logscaled <- spline.logscaled}
# Plot the log-transformed histogram with the spline curve superimposed.
# Add a second y-axis and a dashed red reference line so that the blue line 
# represents the relationship between original voxel intensity values (x-axis) 
# and spline-transformed voxel intensity values (y-axis).
{spline.hist.log <-
  hist.log +
    annotate("segment", x = 0, y = 0, xend = 1884, yend = 14.24028,
             color="red3", size=1.5, lineend="round", linetype=2) +
    geom_line(data=T1.transform.df, aes(x=initial.vals, y=spline.logscaled),
              color="blue4", size=2, lineend="round", na.rm=T) +
    scale_y_continuous(limits=c(-0.7558533, 15.8729200), expand=c(0,0),
                       sec.axis=sec_axis(~./0.007558534, 
                       name="Spline-Transformed Voxel Intensity (AU)")) +
    theme(axis.text.y.right=element_text(color="blue4"),
          axis.ticks.y.right=element_line(color="blue4", size=1),
          axis.title.y.right=element_text(color="blue4"))
  ggsave("Intensity_Transformation_Curve.pdf", plot=spline.hist.log, device="pdf",
         width=4.5, height=4, units='in')
  spline.hist.log}


# View an axial orthographic projection before (left) and after (right) 
# the linear spline intensity transformation.
{double_ortho(T1.nifti, T1.spline, crosshairs=F, mfrow=c(1,2))
  par(new=T, mfrow=c(1,1), mar=c(4, 4, 4, 4))
  title(main="Before Transformation        After Transformation", 
        col.main="white", adj=0.5)
  pdf(file="temp.pdf", height=3.5, width=5)
  double_ortho(T1.nifti, T1.spline, crosshairs=F, mfrow=c(1,2))
  par(new=T, mfrow=c(1,1), mar=c(4, 4, 4, 4))
  title(main="Before Transformation      After Transformation", 
        col.main="white", adj=0.5)
  dev.off()
  if (!require(qpdf)) {install.packages("qpdf"); library(qpdf)}
  pdf_subset('temp.pdf', pages=3, output='Intensity_Transformation.pdf')
  unlink("temp.pdf")}


# Perform a Guillemaud and Brady inhomogeneity correction.
{T1.biasGB.spline <- fsl_biascorrect(T1.spline, retimg=T, 
                                      outfile=file.path(paste0(output.path,
                                                        "/T1_BiasGB.nii.gz")))}


# Visualize the difference between the corrected and uncorrected images to get
# a sense of the field bias.
biasGB.diff <- niftiarr(T1.spline, T1.spline - T1.biasGB.spline)
# Estimate the quantiles of the difference image to use as colorbar breaks.
{biasGB.diff.q <- quantile(biasGB.diff[biasGB.diff !=0], probs = seq(0, 1, by=0.1))
  ortho2(T1.spline, biasGB.diff, col.y=rainbow(10, alpha=0.8), crosshairs=F, 
         ybreaks = biasGB.diff.q, ycolorbar=T)
  pdf(file="GB_Field_Bias_Map.pdf", height=4.5, width=4.5)
  ortho2(T1.spline, biasGB.diff, col.y=rainbow(10, alpha=0.8), crosshairs=F, 
         ybreaks = biasGB.diff.q, ycolorbar=T)
  par(new=T, mfrow=c(1,1))
  title(main="Guillemaud and Brady Field Bias Map", 
        col.main="white", adj=1)
  dev.off()}


# Alternatively, perform an N4 inhomogeneity correction.
{T1.biasN4.spline <- bias_correct(T1.spline, correction="N4", retimg=T, 
                                  outfile=file.path(paste0(output.path,
                                                    "/T1_BiasN4.nii.gz")))}
# Visualize the N4-estimated field bias.
{biasN4.diff <- niftiarr(T1.spline, T1.spline - T1.biasN4.spline)
  biasN4.diff.q <- quantile(biasN4.diff[biasN4.diff !=0], probs = seq(0, 1, by=0.1))
  ortho2(T1.spline, biasN4.diff, col.y=rainbow(10, alpha=0.8), crosshairs=F, 
         ybreaks = biasN4.diff.q, ycolorbar=T)
  pdf(file="N4_Field_Bias_Map.pdf", height=4.5, width=4.5)
  ortho2(T1.spline, biasN4.diff, col.y=rainbow(10, alpha=0.8), crosshairs=F, 
         ybreaks = biasN4.diff.q, ycolorbar=T)
  par(new=T, mfrow=c(1,1))
  title(main="N4 Field Bias Map", 
        col.main="white", adj=0.45)
  dev.off()}


# Compare the Guillemaud and Brady inhomogeneity correction (left) to the N4
# inhomogeneity correction (right).
{par(mfrow=c(2,2))
  double_ortho(T1.biasGB.spline, T1.biasN4.spline, crosshairs=F)
  par(new=T, mfrow=c(1,1), mar=c(5.1, 0, 3.8, 2.1))
  title(main="GB                  N4", 
        col.main="white", adj=0.15)
  pdf(file="GB_N4_Orthographic.pdf", height=5, width=5)
  par(mfrow=c(2,2))
  double_ortho(T1.biasGB.spline, T1.biasN4.spline, crosshairs=F)
  par(new=T, mfrow=c(1,1), mar=c(5.1, 0, 4.1, 2.1))
  title(main="GB                  N4", 
        col.main="white", adj=0.15)
  dev.off()}
# First, create a dataframe of voxel intensity values of several slices
# following each field bias correction (modification of code from 
# github.com/emsweene).
{slices <- c(8, 10, 12, 14, 16, 18)
  vals <- lapply(slices, function(x) {
    cbind(GB=c(T1.biasGB.spline[,,x]), N4=c(T1.biasN4.spline[,,x]),
          slice=x)
  })
  vals <- do.call("rbind", vals)
  vals <- data.frame(vals)
  vals <- vals[vals$GB>5 & vals$N4>5, ]
  colnames(vals)[1:2]=c("GB Bias-Corrected Values", "N4 Bias-Corrected Values")
  v <- melt(vals, id.vars="slice")}
# Then, plot the values. 
# Each line color corresponds to one image slice.
{v$slice <- factor(v$slice, ordered=T, levels=c(14, 12, 10, 16, 8, 18))
  if (!require(viridis)) {install.packages("viridis"); library(viridis)}
  GB.N4.comparison <-
  ggplot(data=v, aes(x=value)) +
    geom_line(aes(color=slice), stat="density") + 
    facet_wrap(~variable) +
    scale_colour_manual(name="Slice", values=turbo(6, begin=0.9, end=0.1)) +
    labs(x="Voxel Intensity (AU)", y="Density") +
    Theme +
    theme(legend.position="none")
  GB.N4.comparison}


# In this case, the gray matter peaks appear better aligned following the
# Guillemaud and Brady inhomogeneity correction. Verify this by estimating
# the coefficient of joint variation (CVJ) of white and gray matter (Ganzetti, 
# Wenderoth, & Mantini, 2016).
# First, remove non-brain tissue--i.e., perform skull stripping.
{T1.bet.biasGB <- fslbet(infile=T1.biasGB.spline)
  T1.bet.biasN4 <- fslbet(infile=T1.biasN4.spline)}
# Estimate the center of gravity and use it to improve brain segmentations.
{cogGB <- cog(T1.bet.biasGB, ceil=T)
  cogGB <- paste("-c", paste(cogGB, collapse=" "))
  T1.bet.biasGB <- fslbet(infile=T1.biasGB.spline, opts=cogGB,
                          outfile=file.path(paste0(output.path,
                          "/GB_Skull_Stripped.nii.gz")))
  cogN4 <- cog(T1.bet.biasN4, ceil=T)
  cogN4 <- paste("-c", paste(cogN4, collapse=" "))
  T1.bet.biasN4 <- fslbet(infile=T1.biasN4.spline, opts=cogN4,
                          outfile=file.path(paste0(output.path,
                          "/N4_Skull_Stripped.nii.gz")))}
# Segment the white and gray matter and create masked images.
{dir.create("~/BRAINIX-main/T1_Processing_Output/Segmentations")
  output.path.seg <- "~/BRAINIX-main/T1_Processing_Output/Segmentations"
  fast(file=T1.bet.biasGB, outfile=file.path(paste0(output.path.seg,
               "/GB_Tissue_Segmentation.nii.gz")), bias_correct=F)
  fast(file=T1.bet.biasN4, outfile=file.path(paste0(output.path.seg,
               "/N4_Tissue_Segmentation.nii.gz")), bias_correct=F)
  GB.seg <- readNIfTI2(file.path(output.path.seg, 
                       "/GB_Tissue_Segmentation_seg.nii.gz"))
  GB.GM.mask <- GB.seg==2
  GB.GM <- T1.bet.biasGB; GB.GM[!GB.GM.mask] = 0; GB.GM <- GB.GM[GB.GM>0]
  GB.WM.mask <- GB.seg==3
  GB.WM <- T1.bet.biasGB; GB.WM[!GB.WM.mask] = 0; GB.WM <- GB.WM[GB.WM>0]
  N4.seg <- readNIfTI2(file.path(output.path.seg, "/N4_Tissue_Segmentation_seg.nii.gz"))
  N4.GM.mask <- N4.seg==2
  N4.GM <- T1.bet.biasN4; N4.GM[!N4.GM.mask] = 0; N4.GM <- N4.GM[N4.GM>0]
  N4.WM.mask <- N4.seg==3
  N4.WM <- T1.bet.biasN4; N4.WM[!N4.WM.mask] = 0; N4.WM <- N4.WM[N4.WM>0]}
# Calculate the CVJ for each bias correction method.
{GB.CVJ <- (sd(GB.WM) + sd(GB.GM))/(mean(GB.WM) - mean(GB.GM))
  N4.CVJ <- (sd(N4.WM) + sd(N4.GM))/(mean(N4.WM) - mean(N4.GM))
  CVJ.df <- data.frame(variable=c("GB Bias-Corrected Values", 
                                  "N4 Bias-Corrected Values"), 
                       CVJ=c(paste("CVJ =", format(round(GB.CVJ, 2), 
                                                   nsmall=2)), 
                             paste("CVJ =", format(round(N4.CVJ, 2), 
                                                   nsmall=2))))
  GB.N4.comparison.cvj <-
  GB.N4.comparison +
    geom_text(data=CVJ.df, aes(x=Inf, y=Inf, label=CVJ),
              hjust=1.1, vjust=1.5, size=3.515, family="sans",
              fontface="bold", color="black")
  ggsave("GB_N4_Comparison.pdf", plot=GB.N4.comparison.cvj, device="pdf",
         width=5, height=3, units='in')
  GB.N4.comparison.cvj}


# The CVJ is slightly lower following the Guillemaud and Brady inhomogeneity
# correction than it is following the N4 inhomogeneity correction, confirming 
# that the Guillemaud and Brady method performs better in this case.


# Convert the skull-stripped brain segmentation of the GB-corrected 
# images into a Boolean matrix.
{T1.bet.mask <- niftiarr(T1.bet.biasGB, 1)
  in.mask <- T1.bet.biasGB>0
  T1.bet.mask[!in.mask] <- NA
  writeNIfTI(nim=T1.bet.mask, filename="T1_Brain_Mask")}
# View the original image with the skull-stripped brain tissue overlaid.
{ortho2(T1.biasGB.spline, T1.bet.mask, crosshairs=F, 
        col.y=alpha("#FF0000", 0.3))
  pdf(file="T1_Skull_Stripped.pdf", height=5.5, width=5)
  ortho2(T1.biasGB.spline, T1.bet.mask, crosshairs=F, 
         col.y=alpha("#FF0000", 0.3))
  par(new=T, mfrow=c(1,1), mar=c(5.5, 5.5, 2, 5.5))
  title(main="T1 Skull Stripping Results",
        col.main="white", adj=0.45)
  dev.off()}


# Estimate white and gray matter volumes.
{pve1.GM <- readNIfTI2(file.path(output.path.seg, 
                                 "/GB_Tissue_Segmentation_pve_1.nii.gz"))
  pve2.WM <- readNIfTI2(file.path(output.path.seg, 
                                  "/GB_Tissue_Segmentation_pve_2.nii.gz"))
  total.vol <- prod(voxdim(GB.seg))
  GM.vol <- format(round(sum(pve1.GM)*total.vol/1000, 1), nsmall=1)
  WM.vol <- format(round(sum(pve2.WM)*total.vol/1000, 1), nsmall=1)
  double_ortho(pve1.GM, pve2.WM, crosshairs=F, mfrow=c(1,2))
  par(new=T, mfrow=c(1,1), mar=c(4, 4, 4, 4))
  title(main=paste("GM Volume:", GM.vol, "mL    ", "WM Volume:", 
                   WM.vol, "mL"), col.main="white", adj=0.5)
  pdf(file="temp.pdf", height=3.5, width=5)
  double_ortho(pve1.GM, pve2.WM, crosshairs=F, mfrow=c(1,2))
  par(new=T, mfrow=c(1,1), mar=c(4, 4, 4, 4))
  title(main=paste("GM Volume:", GM.vol, "mL    ", "WM Volume:",
                 WM.vol, "mL"), col.main="white", adj=0.5)
  dev.off()
  pdf_subset('temp.pdf', pages=3, output='Volume_Estimates.pdf')
  unlink("temp.pdf")}


# Register the skull-stripped brain to a reference atlas.
# Read in the MNI atlas template.
{atlas.path <- "~/mni_icbm152_nlin_asym_09b"
  MNI.atlas <- readNIfTI(file.path(atlas.path, 
                         "mni_icbm152_t1_tal_nlin_asym_09b_hires.nii"))}
# Remove skull tissue from the reference atlas so it better aligns with
# our skull-stripped T1 images.
{MNI.bet <- fslbet(infile=MNI.atlas, reorient=T)
  cogMNI <- cog(MNI.bet, ceil=T)
  cogMNI <- paste("-c", paste(cogMNI, collapse=" "))
  MNI.bet <- fslbet(infile=MNI.atlas, opts=cogMNI, reorient=T,
                    outfile=file.path(paste0(atlas.path,
                            "/MNI_T1_Skull_Stripped.nii.gz")))}
# Perform an affine transformation followed by a symmetric normalization 
# (SyN) registration.
{T1.SyNreg.bet <- ants_regwrite(filename=T1.bet.biasGB,
                                template.file=MNI.bet, remove.warp=T,
                                typeofTransform="SyN",
                                outfile=file.path(paste0(output.path,
                                "/T1_SyN_Registered.nii.gz")))}
# View the reference atlas with the SyN-registered T1 projection overlaid.
{ortho2(MNI.bet, T1.SyNreg.bet, col.y=alpha(hotmetal(), 0.6), 
        crosshairs=F, add.orient=T, mar=c(0.5, 0, 0.5, 0))
  pdf(file="T1_MNI_Registered.pdf", height=5.5, width=5)
  ortho2(MNI.bet, T1.SyNreg.bet, col.y=alpha(hotmetal(), 0.6), 
         crosshairs=F)
  par(new=T, mfrow=c(1,1), mar=c(5.5, 5.5, 2, 5.5))
  title(main="T1 Registered to MNI Template", 
        col.main="white", adj=0.45)
  dev.off()}


# Apply a Gaussian smoothing filter.
{T1.smooth.SyNreg <- fslsmooth(T1.SyNreg.bet, sigma=diag(3, 3), 
                               outfile=file.path(paste0(output.path,
                                       "/T1_Smoothed.nii.gz")))
  ortho2(T1.smooth.SyNreg, crosshairs=F)
  pdf(file="T1_Smoothed.pdf", height=5.5, width=5)
  ortho2(T1.smooth.SyNreg, crosshairs=F)
  par(new=T, mfrow=c(1,1), mar=c(5.5, 5.5, 2, 5.5))
  title(main="T1 with Gaussian Smoothing Filter", 
        col.main="white", adj=0.45)
  dev.off()}







