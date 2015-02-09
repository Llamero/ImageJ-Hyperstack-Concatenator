//Ask user to choose the input and output directories
directory = getDirectory("Choose input directory");
fileList = getFileList(directory);
outputDirectory = getDirectory("Choose output directory");

//Count the maximum number of positions and slices in dataset
run("Bio-Formats Macro Extensions");

newPosition = 0;
newSlice = 0;
maxPosition = 0;
maxSlice = 0;

for (i=0; i<fileList.length; i++) {
	file = directory + fileList[i];
	Ext.setId(file);
	Ext.getSeriesCount(newPosition);
	Ext.getSizeZ(newSlice);

	//Save the largest number of slices within the dataset
	if (newSlice>maxSlice) {
		maxSlice = newSlice;
	}

	//Check to make sure that all files have the same number of positions
	if (newPosition != maxPosition) {
		if (i < 1) {
			maxPosition = newPosition;
		}
		
		else {
			exit("The files in this dataset do not contain the same number of positions!");
		}
	}
}


//Ask user how many positions there are in each file
nPositions = getNumber("How many positions are in this dataset?", maxPosition); 

//Ask user how many experiments they woud like merged 
nExperiment= getNumber("How many experiments need to be merged?", fileList.length); 

//Ask user how many slices need to be added to stack
Slices = getNumber("How many slices do you want in each stack?", maxSlice); 

//Activate batch mode for speed
setBatchMode(true);

//Normalize Autofluor and GFP channel, remove autofluor, save result

//Open all 10 positions from set of lif files, one set of identical opsitions at a time
for(a=1; a<nPositions+1; a++) {	
	//Open the same position series from each lif file as a hyperstack
	for (i=0; i<nExperiment; i++) {
		file = directory + fileList[i];
		run("Bio-Formats Importer", "open=file color_mode=Default view=Hyperstack stack_order=XYCZT series_"+d2s(a,0)); 
		
		//Get name of opened stack
		title = getTitle();
		getDimensions(width, height, channels, slices, frames);

		//Check if it is a two channel image, abort if not
		if (channels != 2) {
		  exit("2-channel image required");
		}

		//Split channels and record names of each new image stack
		run("Split Channels");
		c1Title = "C1-" + title;
		c2Title = "C2-" + title; 

		//Measure mean intensity of each channel and normalize channel 1 (autofluor) to channel 2 (GFP)
		selectWindow(c1Title);
		Stack.getStatistics(count1, mean1, min1, max1, std1);
		selectWindow(c2Title);
		Stack.getStatistics(count2, mean2, min2, max2, std2);
		selectWindow(c1Title);
		c1Normalization = mean2/mean1;
		run("Multiply...", "value=c1Normalization stack");

		//Substract c1 (normalized autofluor) from c2 (GFP) to get a GFP only stack
		imageCalculator("Subtract create stack", c2Title, c1Title);

		//Close individual channel stack windows (* is wildcard)
		close("C*");

		//Run 1x1x1 median filter to despeckle image and reduce shot noise
		run("Median 3D...", "x=1 y=1 z=1");

		//Normalize stack intensity and convert to 8 bit
		run("Enhance Contrast...", "saturated=0.001 normalize process_all use");
		run("8-bit");

		//Save stack with experiment and position identifier
		saveAs("Tiff", outputDirectory + "Position " + a + " Experiment " + i);
		close();
	}
}

//Remove blank time points, add necessary slices (to keep dimensions identical), concatenate stacks and align stacks

//Turn off batch mode so that 3D alignment tool doesn't max out RAM and crash
setBatchMode(false);

//Open all 10 positions from first macro, one position at a time
for(a=1; a<nPositions+1; a++) {	
	for(b=0; b<nExperiment; b++){
		//Open the specified position series from specified experiment
		open(outputDirectory + "Position " + a + " Experiment " + b + ".tif");
			
		/* split timepoints */
		// remember the original hyperstack
		id = getImageID();
			 
		// we need to know only how many frames there are
		getDimensions(dummy, dummy, dummy, dummy, nFrames);
			 
		// for each frame...
		for (frame = 1; frame <= nFrames; frame++) {
			// select the frame
			selectImage(id);
			Stack.setPosition(1, 1, frame);
			
			// extract one frame
			run("Reduce Dimensionality...", "channels slices keep");

			//Measure intensity of time point, if max intensity = 0 (blank) then delete
			Stack.getStatistics(count, mean, min, max, std);
			if(max==0){
				close();
			}
			
     		//If stack has too few slices add extra slices onto end
			setSlice(nSlices);
			for(c=nSlices; c<Slices; c++){
				run("Add Slice");
			}

			//If stack has too many slices, delete end slices
			for(d=nSlices; d>Slices; d--){
				run("Delete Slice");
			}

							
		}
		// close the original hyperstack
		selectImage(id);
		close();	

	}
	//Concatenate timepoints into one hyperstack
	run("Concatenate...", "all_open title=[Concatenated Stacks] open");
	
	//Align 3D stacks across timepoints
	run("Correct 3D drift", "channel=1");

	//Close original concatenated stack
	close("C*");

	//Save and close new stack
	saveAs("Tiff", outputDirectory + "Position " + a);
	close("*");

}

setBatchMode(true);

//Create max intensity projection time series
for(a=1; a<nPositions+1; a++) {	
	open(outputDirectory + "Position " + a + ".tif");
	run("Z Project...", "projection=[Max Intensity] all");
	
	//Close original file
	close("P*");

	//Save and close new stack
	saveAs("Tiff", outputDirectory + "Max Projection Position " + a);
	close();
	
}

setBatchMode(false);