#!/bin/R

# Example: /home/ciro/scripts/cellranger/config_project.yaml

library(optparse)

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
defargs <- parse_args(optparse)

## Functions ## ----------------------------------------------------------------
suppressPackageStartupMessages({
  library(yaml)
  library(crayon)
})
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
config_file = read_yaml(defargs$yaml)

setwd(config_file$output_dir)
if(defargs$verbose){
  cat(cyan("\n************ Vijay Lab - LJI\n"))
  cat(cyan("-------------------------------------\n"))
  cat(red$bold("------------ Aggregations\n"))
  str(config_file[!names(config_file) %in% "job"])
  cat("Working at:", getwd(), "\n")
  system("ls -loh")
  cat("\n")
}#; quit()

# Aggregations table
aggr_df <- read.csv(config_file$aggregation, stringsAsFactors = FALSE, row.names = 1)
aggregations <- grep("^aggr", colnames(aggr_df), value = TRUE)
aggr_df <- aggr_df[!apply(aggr_df[, aggregations, drop = FALSE], 1, function(x) all(is.na(x)) ), , drop = FALSE]

# Getting job template
template_pbs_con <- file(description = config_file$job$template, open = "r")
template_pbs <- readLines(con = template_pbs_con)
close(template_pbs_con)

# Getting samples
all_samples <- gsub("count_", "count/", list.files(path = 'scripts', pattern = "count.*sh$"))
all_samples <- unique(c(
  list.files(path = 'count', pattern = "Gex", full.name = TRUE),
  gsub(pattern = "\\.sh", replacement = "", x = all_samples),
  gsub("count_", "", grep("^count_", running_jobs()$Name, value = TRUE))
))
samples <- paste0(getwd(), "/", all_samples, "/outs/molecule_info.h5")
# samples <- samples[file.exists(samples)]
# samples <- samples[grepl(paste0(rownames(aggr_df), collapse = "|"), samples)]
names(samples) <- basename(dirnamen(samples, 2))
samples <- samples[names(samples) %in% rownames(aggr_df)]

if(defargs$verbose) cat("Processing", length(samples), "samples\n")
if(defargs$verbose) cat("Aggregations", length(aggregations), "\n\n")
if(defargs$verbose) cat("--------------------------------------\n")
for(my_aggregation in aggregations){
  aggregation_name <- gsub("^aggr.", "", my_aggregation)
  if(defargs$verbose) cat(aggregation_name)
  if(dir.exists(paste0(getwd(), "/aggr/", aggregation_name, "/outs"))){
    if(defargs$verbose) cat(" - done\n"); next
  }

  # Getting name(s)
  samples_pattern <- paste0(rownames(aggr_df[which(aggr_df[, my_aggregation] == 1), ]), "$")
  samples_pattern <- paste0(samples_pattern, collapse = "|")
  selected_samples <- samples[grepl(samples_pattern, names(samples))]
  if(defargs$verbose) cat("\n +", length(selected_samples), "samples\n")

  # Determining routine type
  routine <- routine_pbs_fname <- "aggr"
  libraries_file <- paste0(getwd(), "/scripts/aggregation_", aggregation_name, ".csv")
  libraries_df <- data.frame(
    library_id = names(selected_samples),
    molecule_h5 = unname(selected_samples)
  )
  write.table(libraries_df, file = libraries_file, quote = FALSE, row.names = FALSE, sep = ",")

  # Parameters
  params <- paste0(
    config_file$cellranger,
    " ", routine,
    " --id=", aggregation_name,
    " --csv=", libraries_file,
    " --normalize=mapped",
    " --localcores=", config_file$job$ppn[[routine_pbs_fname]],
    " --localmem=", gsub("gb", "", config_file$job$mem[[routine_pbs_fname]], ignore.case = TRUE),
    " --disable-ui"
  )

  # Output directory
  output_dir <- paste0(getwd(), "/", routine)
  if(!dir.exists(output_dir)) dir.create(output_dir)

  pbs <- gsub("\\{username\\}", Sys.info()[["user"]], template_pbs)
  pbs <- gsub("\\{sampleid\\}", aggregation_name, pbs)
  pbs <- gsub("\\{routine_pbs\\}", routine_pbs_fname, pbs)
  pbs <- gsub("\\{outpath\\}", output_dir, pbs)
  pbs <- gsub("\\{routine_params\\}", params, pbs)
  for(i in names(config_file$job)){
    job_parm <- config_file$job[[i]]
    job_parm <- if(routine_pbs_fname %in% names(job_parm)) job_parm[[routine_pbs_fname]] else job_parm[[1]]
    pbs <- gsub(paste0("\\{", i, "\\}"), job_parm, pbs)
  }

  running <- try(running_jobs(), silent = TRUE)
  if(class(running) == "try-error") running <- list(Name = "none")
  if(any(grepl(paste0(routine_pbs_fname, "_", aggregation_name, "$"), running$Name))){
    if(defargs$verbose) cat(" - running\n"); next
  }

  pbs_file <- paste0(getwd(), "/scripts/", routine_pbs_fname, "_", aggregation_name, ".sh")
  writeLines(text = pbs, con = pbs_file)
  if(any(c(config_file$job$submit, defargs$submit))){
    depend <- if(isTRUE(config_file$job$depend %in% running$id)) paste0("-W depend=afterok:", config_file$job$depend)
    depend_routine <- paste0(c(depend, running[grepl(samples_pattern, running$Name), ]$id), collapse = ":")
    if(is.null(depend) && depend_routine != "") depend_routine <- paste0("-W depend=afterok:", depend_routine)
    pbs_command <- paste("qsub", depend_routine, pbs_file)
    if(defargs$verbose) cat("\n", pbs_command, "\n"); system(pbs_command)
    void <- suppressWarnings(file.remove(gsub("sh", "out.txt", pbs_file)))
  }
  if(defargs$verbose) cat("\n")
}
if(defargs$verbose) cat("--------------------------------------\n")
if(defargs$verbose) cat("PBS files at:", paste0(getwd(), "/scripts/"), "\n")
