# ImageJ-Hyperstack-Concatenator
Put all the XYZT files into a single directory with no other files, and the macro reads the number of files, slices, and positions, then does a bunch of automated cleaning including:

Normalizing the autofluor channel intensity to the GFP channel and subtracting from the GFP channel,

Applies a 1x1x1 median filter to reduce shot noise

Rescaling the contrast of each stack so the intensity remains constant and contrast is optimal, then downsampling to 8 bit

Removing any blank time points (sometimes lif files include a blank time point at the end if stopped early)

Adds or subtracts slices to make sure every stack has the same dimensions, then concatenates the timepoints.

Performs a 3D alignment of the stacks

Then after saving the ligned stacks it also creates a MIP of each stack for quick checking of the data.


The macro is also heavily commented, so you should be able to adjust it to your needs
