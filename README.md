## Cell Ranger wrapper

All the information goes into the configuration file (YAML format). There is an example with comments
regarding the format of the files.

There are two main R scripts that prepare the Cell Ranger routines count and vdj.

The files you need to prepare are:
1. Sample sheet
	- Can be avoided if your samples have consistent names you can use to select them from a mkfastq or bcl2fastq.
2. Feature reference (if you have Feature Barcode data).
	- You can give a sheet per sample or add a column 'library_pattern' with patterns that can be found in the libraries that contain the set of barcodes (see fbarcodes.csv).
3. Aggregation file (essentially the libraries metadata)
	- You will need to add a column for each aggregation you would like to perform. This needs to be
	  prefixed with 'aggr.' and for each library you wish to include state so with the value '1'.

NOTE: It still needs to integrate the mkfastq step. This is because you often have mixed data in addition to 10x and
using mkfastq would duplicate a lot of data given that you demultiplex the 10x libraries alone.
Also, once you bcl2fastq you never mkfastq again.

### Install
Clone this repository
```
git clone https://github.com/vijaybioinfo/cellranger_wrappeR.git
cd cellrangeR_wrapper
```

Make sure your config template is pointing to where you have the pipeline.
This will also add the run.sh script as an alias.
```
sh locate_pipeline.sh
```

### Run the pipeline
After you've added the necessary information to the YAML file you can call the pipeline
```
cellranger_wrappeR -y /path/to/project/config.yaml
```
