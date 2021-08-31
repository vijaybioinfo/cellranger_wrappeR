#!/bin/R

library(optparse)
library(yaml)
library(crayon)

optlist <- list(
  make_option(
    opt_str = c("-y", "--yaml"), type = "character", default = "config_project.yaml",
    help = "Configuration file."
  ),
  make_option(
    opt_str = c("-s", "--submit"), type = "logical", default = FALSE,
    help = "Submit jobs."
  ),
  make_option(
    opt_str = c("-v", "--verbose"), type = "logical", default = TRUE,
    help = "Verbose."
  )
)
optparse <- OptionParser(option_list = optlist)
opt <- parse_args(optparse)

## Functions ## ----------------------------------------------------------------
dirnamen <- function(x, n = 1){
  for(i in 1:n) x <- dirname(x)
  return(x)
}
running_jobs <- function(){
  system("qstat -fu ${USER} | grep -E 'Job_Name|Job Id|job_state' | sed 's/Id: /Id_/g; s/ = /: /g; s/.herman.*/:/g' > ~/.tmp")
  jobs_yaml = yaml::read_yaml("~/.tmp")
  jobs_yaml <- jobs_yaml[sapply(jobs_yaml, function(x) x[['job_state']] ) != "C"]
  jobs_df <- data.frame(
    id = gsub(".*Id_", "", names(jobs_yaml)),
    Name = sapply(jobs_yaml, function(x) x[["Job_Name"]] ),
    stringsAsFactors = FALSE
  ); rownames(jobs_df) <- NULL
  jobs_df
}

## Reading files ## ------------------------------------------------------------
config_file = read_yaml(opt$yaml)

dir.create(config_file$output_dir, showWarnings = FALSE)
setwd(config_file$output_dir)
dir.create("scripts", showWarnings = FALSE)
if(opt$verbose){
  cat(cyan("-------------------------------------\n"))
  cat(red$bold("------------ Demultiplexing cells\n"))
  cat("Configuration:")
  str(config_file[!names(config_file) %in% "job"])
  cat("Working at:", getwd(), "\n")
  system("ls -loh")
  cat("\n")
}

if(opt$verbose) cat("Getting job template\n")
template_pbs_con <- file(description = config_file$job$template, open = "r")
template_pbs <- readLines(con = template_pbs_con)
close(template_pbs_con)

# Get sample sheet
if(opt$verbose) cat("Samples from: ")
sample_patterns <- if(file.exists(config_file$samples)){
  if(opt$verbose) cat("sheet\n")
  sshet <- read.csv(config_file$samples, stringsAsFactors = FALSE)
  data_begin <- which(apply(X = sshet, MARGIN = 1, FUN = function(x) any(grepl("\\[Data", x)) ))
  if(length(data_begin) > 0) colnames(sshet) <- sshet[data_begin + 1, ]
  samples <- if(!is.null(sshet$Sample_Name)) sshet$Sample_Name else sshet$Sample_ID
  if(length(data_begin) > 0) samples <- samples[-c(1:data_begin)]
  paste0(samples, collapse = "|")
}else{
  if(opt$verbose) cat("pattern\n")
  config_file$samples
}

# Setting FASTQ directory
fastqs_dir <- if(!is.null(config_file$fastqs_dir)) unlist(config_file$fastqs_dir) else "./"
fastqs_dir <- gsub(",", " ", fastqs_dir)

# Getting samples
command <- paste("find", fastqs_dir, "-maxdepth 3 -name *fastq*")
if(opt$verbose) cat(command, sep = "\n")
# all_samples <- system(command, intern = TRUE)
all_samples <- unlist(sapply(command, function(x) system(x, intern = TRUE) ), use.names = FALSE)
all_samples <- all_samples[!grepl("Undetermined_", all_samples)]
if(!is.null(config_file$exclude)) all_samples <- all_samples[!grepl(config_file$exclude[[1]], all_samples)]
all_samples <- samples <- grep(sample_patterns, all_samples, value = TRUE)
for(lib_type in c("TCR", "CITE", "Gex")){
  samples <- gsub(
    pattern = paste0("(.*", lib_type, ").*"),
    replacement = "\\1",
    # ignore.case = TRUE, # this shouldn't be necessary
    x = basename(samples)
  )
}
samples <- unique(samples)

if(opt$verbose) cat("Processing", length(samples), "samples\n\n")
# if(opt$verbose && length(samples) < 200) cat(all_samples, sep = "\n")
if(opt$verbose) cat("--------------------------------------\n")
for(my_sample in samples){
  if(opt$verbose) cat(my_sample)
  re_run <- isTRUE(any(grepl("^f$|force", c(config_file$job$submit, opt$submit))))
  if(any(dir.exists(paste0(getwd(), "/", c("count", "vdj"),"/", my_sample, "/outs"))) && !re_run){
    if(opt$verbose) cat(green$bold(" - done\n")); next
  }

  # Getting fastqs location and name(s)
  selected_samples <- grep(my_sample, all_samples, value = TRUE)
  fastqs <- unique(dirnamen(selected_samples, 2)) # can it be just config_file$fastqs_dir?
  project_name <- unique(basename(dirnamen(selected_samples, 2)))
  if(any(project_name %in% basename(fastqs_dir))) project_name <- unique(basename(dirname(selected_samples)))
  if(length(project_name) > 1){
    # It takes all of them anyway? At least when prefix is the same and folders are _A,_B,_C or/and not
    # grep fastq.gz ~/ad_hoc/fungal_allergy/raw/cellranger/count/001_FgAl03_FLU_H_8D_Gex/_finalstate | sed 's/.*: //g' | sort -u
    cat("\nMore than one project name:", project_name, "\n")
  }
  sample_path <- unique(dirname(selected_samples))

  # Determining routine type
  routine <- routine_pbs_fname <- "count"
  transcriptome = "transcriptome"
  libraries_file <- paste0(getwd(), "/scripts/libraries_", my_sample, ".csv")
  feature_ref <- config_file$feature_ref[[my_sample]]
  if(grepl("TCR", my_sample)){
    routine <- routine_pbs_fname <- "vdj"
    transcriptome = "reference" # remove from libraries to nosecondary
    params_subs <- c("--libraries.*--reference", "--reference")
  }else if(grepl("Gex", my_sample)){ # remove libraries and feature-ref
    params_subs <- c("--libraries.*--nosecondary", "--nosecondary")
  }else if(grepl("CITE", my_sample)){
    routine_pbs_fname <- "fbarcode" # create libraries CSV
    params_subs <- c("--sample.*--libraries", "--libraries") # remove sample, project, and fastqs

    libraries_df <- c(
      "fastqs,sample,library_type",
      paste0(sample_path, ",", my_sample, ",Antibody Capture")
    )
    write.table(libraries_df, col.names = FALSE, file = libraries_file, quote = FALSE, row.names = FALSE, sep = ",")

    if(is.null(feature_ref)) feature_ref <- config_file$feature_ref$main
    if(is.null(feature_ref)) feature_ref <- "no_file"
    feature_ref_df <- if(file.exists(feature_ref)) read.csv(feature_ref) else stop("Referance doesn't exists: ", feature_ref)
    if(!is.null(feature_ref_df$library_pattern)){
      mypatterns <- levels(feature_ref_df$library_pattern)
      is_mypattern <- sapply(mypatterns, function(x) grepl(x, my_sample) )
      if(opt$verbose) cat("\nFound pattern(s) in ref:", paste0(mypatterns[which(is_mypattern)], collapse = ", "))
      feature_ref_df <- feature_ref_df[feature_ref_df$library_pattern %in% mypatterns[which(is_mypattern)], ]
    }
    feature_ref <- gsub("libraries_", "feature_ref_", libraries_file)
    feature_ref_df <- feature_ref_df[, !colnames(feature_ref_df) %in% "library_pattern"]
    if(opt$verbose) cat("\nExtracting", nrow(feature_ref_df), "hashtags")
    write.table(feature_ref_df, file = feature_ref, quote = FALSE, row.names = FALSE, sep = ",")
  }

  # Parameters
  params <- paste0(
    config_file$cellranger,
    " ", routine,
    " --id=", my_sample,
    " --sample=", paste0(my_sample, collapse = ","),
    " --project=", project_name,
    " --fastqs=", paste0(fastqs, collapse = ","),
    " --libraries=", libraries_file,
    " --feature-ref=", feature_ref,
    " --nosecondary",
    " --", transcriptome, "=", config_file$transcriptome[[routine]],
    " --localcores=", config_file$job$ppn[[routine_pbs_fname]],
    " --localmem=", gsub("gb", "", config_file$job$mem[[routine_pbs_fname]], ignore.case = TRUE),
    " --disable-ui"
  )
  params <- gsub(params_subs[1], params_subs[2], params)

  # Output directory
  output_dir <- paste0(getwd(), "/", routine)
  if(!dir.exists(output_dir)) dir.create(output_dir)

  pbs <- gsub("\\{username\\}", Sys.info()[["user"]], template_pbs)
  pbs <- gsub("\\{sampleid\\}", my_sample, pbs)
  pbs <- gsub("\\{routine_pbs\\}", routine_pbs_fname, pbs)
  pbs <- gsub("\\{outpath\\}", output_dir, pbs)

  params <- unlist(strsplit(params, "--")) # multiline
  heads <- c(" ", rep("   --", length(params)-1)); tails <- c(rep("\\", length(params)-1), "")
  params <- paste0(heads, params, tails)
  pbs <- append(pbs, params[-1], after = grep("\\{routine_params\\}", pbs))
  tvar <- grep("\\{routine_params\\}", pbs); pbs[tvar] <- params[1]
  # pbs <- gsub("\\{routine_params\\}", params[1], pbs)
  # print(pbs[(tvar-4):(tvar+length(params)+4)])

  for(i in names(config_file$job)){
    job_parm <- config_file$job[[i]]
    job_parm <- if(routine_pbs_fname %in% names(job_parm)) job_parm[[routine_pbs_fname]] else job_parm[[1]]
    pbs <- gsub(paste0("\\{", i, "\\}"), job_parm, pbs)
  }
  pbs <- gsub("# \\{extra_actions\\}", "rm -r SC_*_CS", pbs)

  running <- try(running_jobs(), silent = TRUE)
  do_we_submit <- any(c(opt$submit, re_run))
  job_name <- paste0(routine_pbs_fname, "_", my_sample, "$")
  if(any(grepl(job_name, running$Name)) && isFALSE(do_we_submit)){
    if(opt$verbose) cat(" - running\n"); next
  }

  pbs_file <- paste0(getwd(), "/scripts/", routine_pbs_fname, "_", my_sample, ".sh")
  if(opt$verbose) cat(" - creating job file"); # Somehow it's slow
  writeLines(text = pbs, con = pbs_file); # file(open = "w"); close() didn't help
  # write(x = pbs, file = pbs_file)

  if(isTRUE(any(c(config_file$job$submit, do_we_submit)))){
    depend <- if(isTRUE(config_file$job$depend %in% running$id)) paste0("-W depend=afterok:", config_file$job$depend)
    pbs_command <- paste("qsub", depend, pbs_file)
    if(opt$verbose) cat("\n", pbs_command, "\n"); system(pbs_command)
    void <- suppressWarnings(file.remove(gsub("sh", "out.txt", pbs_file)))
  }
  if(opt$verbose) cat("\n")
}
if(opt$verbose) cat("--------------------------------------\n")
if(opt$verbose) cat("PBS files at:", paste0(getwd(), "/scripts/"), "\n")
