# Cell Ranger WrappeR

Welcome to the Vijay's Lab Cell Ranger wrapper based on R. It makes use of a cluster with Torque and Moab.

It is as easy as just running a line that will take care of assinging a job for each of your samples.


```markdown
cellranger_wrappeR -y /path/to/project/config.yaml -v
```

Then you can go do more fun coding and wait for your jobs to finish. When they do, you simply run the summary function.

```markdown
cellranger_wrappeR -y /path/to/project/config.yaml -s
```

The files you need to prepare are:
1. Sample sheet ('samples' in the YAML file).
2. Feature reference (if you have Feature Barcode data; 'feature_ref' in the YAML file).
3. Aggregation file (essentially the libraries metadata; 'aggregation' in the YAML file).

For more details see our [repository](https://github.com/vijaybioinfo/cellranger_wrappeR) installaion and getting ready instructions.

For more useful stuff, check our [GitHub's account](https://github.com/vijaybioinfo).
