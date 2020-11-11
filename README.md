## Cell Ranger wrapper

All the information goes into the configuration file (YAML format). There is an example (config.yaml) with comments regarding the files' format.

There are two main R scripts:
- _demultiplexing_cells.R_, sets and runs the Cell Ranger routines count and vdj for each sample in 'fastqs_dir' (and as indicated in 'samples').
- _aggregate.R_, according to 'aggregation'.

The files you need to prepare are:
1. Sample sheet ('samples' in the YAML file).
	- Can be avoided if your samples have consistent names you can use to select them from a mkfastq/bcl2fastq output. In this case, you can only specify, for example, CD4 and this will process all the samples having "CD4" in the name. Otherwise, you can give the whole Illumina Experiment Manager (IEM) sample sheet.
2. Feature reference [if you have Feature Barcode data] ('feature_ref' in the YAML file).
	- You can give a sheet per sample or add a column 'library_pattern' with patterns (see regex) that can be found in the libraries that contain the set of barcodes (see fbarcodes.csv). For example, a set of barcodes that were used in libraries containing the patterns "PATTERN1|PATTERN2" in their names; where **|** means PATTERN1 **or** PATTERN2.
3. Aggregation file (essentially the libraries metadata; 'aggregation' in the YAML file).
	- You will need to add a column for each aggregation you would like to perform. This needs to be prefixed with 'aggr.' and for each library you wish to include state so with the value '1' (see metadata_library.csv).
	
NOTES:
1. It still needs to integrate the mkfastq step. This is because you often have mixed data in addition to 10x and
using mkfastq would duplicate a lot of data given that you demultiplex the 10x libraries alone.
Also, _once you bcl2fastq you never mkfastq again_.
2. The pipeline relies on the samples having the follwing patterns in their name:
	- **Gex**: to use Cell Ranger's "count" routine.
	- **TCR**: to use Cell Ranger's "vdj" routine.
	- **CITE**: to use Cell Ranger's "count" routine and identify it as Feature Barcode.
3. We assume we have a scratch folder with /mnt/beegfs as its path. However, you can change that in routine_template.sh (WORKDIR=).

### Install
Clone this repository (your ~/bin folder is a good place).
```
git clone https://github.com/vijaybioinfo/cellranger_wrappeR.git
cd cellranger_wrappeR
```

Make sure your config template is pointing to where you have the pipeline.
This will also add the run.sh script as an alias.
```
sh ./locate_pipeline.sh
```

### Run the pipeline
After you've added the necessary information to the YAML file you can call the pipeline.
```
cellranger_wrappeR -y /path/to/project/config.yaml
cellranger_wrappeR -y /path/to/project/config.yaml -s # to just run the summary
```
