#!/usr/bin/R

################################
# Single Cell CSV construction #
################################

# Summarising all count metrics: give path(s) (separated by SPACES) to the
# folder(s) with the counts outputs, or path(s) to the aggregation_csv.csv file(s)

options(warn = -1, stringsAsFactors = FALSE)
library(optparse)
library(crayon)

optlist <- list(
  make_option(
    opt_str = c("-i", "--input"), type = "character",
    help = "Folder with Cell Ranger's count/vdj outputs."
  ),
  make_option(
    opt_str = c("-p", "--pattern"), type = "character",
    help = "Pattern for libraries to summarise."
  ),
  make_option(
    opt_str = c("-e", "--exclude"), type = "character",
    help = "Pattern for libraries to exclude."
  ),
  make_option(
    opt_str = c("-o", "--outdir"), type = "character",
    help = "Out put directory."
  )
)
optparse <- OptionParser(option_list = optlist)
opt <- parse_args(optparse)

# Functions #
cat(cyan("\n*** Vijay Lab - LJI\n"))
cat(cyan("-------------------------------------\n"))
cat(red$bold("Summarising Cell Ranger results\n"))
suppressPackageStartupMessages({
  library(ggplot2)
  library(cowplot)
}); theme_set(theme_bw())
plot_qcs_bars <- function(df){
  p <- ggplot(df, aes(x = Library, y = value)) +
    geom_bar(stat = "identity") +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    geom_text(aes(label=value), vjust=-0.3)
  p
}
getarg <- function(x, pattern){
  trans <- system(paste0('grep -EC1 "Transcriptome|D.J Reference" ', x, '/outs/web_summary.html'), intern = TRUE)
  trans <- gsub(".* <|<|>|td|\\/", "", trans[grep("tome|ence<", trans)+1])
  trans <- trans[grep("^[A-z].*[0-9]$", trans)]
  chemy <- system(paste0('grep -C1 mistry ', x, '/outs/web_summary.html'), intern = TRUE)
  chemy <- gsub(".* <|<|>|td|\\/", "", chemy[grep("mistry<", chemy)+1])
  if(length(chemy) > 0 && length(trans) > 0){
    return(c(paste0('emistry=', chemy), paste0('tome=', trans)))
  }
  tfile <- readLines(paste0(x, '/outs/web_summary.html'))
  y <- gsub(pattern, '\\1', tfile[grep(pattern, tfile)])
  y <- sub(paste0(".*(", paste0(strsplit(gsub('[[:punct:]]| ', '', y), '')[[1]], collapse = ".*"), ").*"), '\\1', y)
  y <- strsplit(gsub('\", \"', '=', y), '\"\\], \\[\"')[[1]]
}

# order vector following a reference order
this_order <- function(x, ref){
  y <- unique(x)
  order_all <- c(ref[ref %in% y], y[!y %in% ref])
  cat(paste0(order_all, collapse = ", "), "\n")
  y <- c()
  for(i in order_all) y <- c(y, which(x %in% i))
  return(y)
}
finished_file <- function(x, size = 3620){ file.exists(x) && isTRUE(file.size(x) > size) }
hierarchy <- c("Single Cell 5' PE", "Single Cell 3' v3", "Single Cell 3' v2 or 5'", "Single Cell V(D)J")

if(grepl(" |\\n", opt$input)){
  cat("Several locations\n")
  opt$input <- unlist(strsplit(opt$input, " |\\n"))
}; opt$input <- unique(opt$input)

cat("Path(s):\n", paste0(opt$input, collapse = "\n"), "\n", sep = "")
if(all(file.exists(opt$input))){
  opt$input <- ifelse(!grepl("\\/$", opt$input) & dir.exists(opt$input), paste0(opt$input, "/"), opt$input)
  libs <- unlist(lapply(opt$input, function(x){
    if(dir.exists(x)){
      libs <- gsub("/+", "/", list.dirs(x, recursive = FALSE))
    }else{
      libs <- dirname(dirname(read.csv(x, stringsAsFactors = FALSE)[, 2]))
    }
  }))
  libs <- libs[file.exists(paste0(libs, '/outs/metrics_summary.csv'))]
  if(!is.null(opt$pattern)) libs <- libs[grepl(opt$pattern, libs)]
  if(!is.null(opt$exclude)) libs <- libs[!grepl(opt$exclude, libs)]
  sumtabf <- if(is.null(opt$outdir)) paste0(tail(dirname(libs[dir.exists(libs)]), 1), '/') else opt$outdir
  cat("Summary output at:", sumtabf, "\n")
  cat("Binding", length(libs), "metrics\n")
  metsums <- try(lapply(libs, function(lib){
    fname <- paste0(lib, '/outs/metrics_summary.csv')
    versions <- getarg(x = lib, pattern = '.*Sample Description(.*)Pipeline Version.*')
    chemy <- sub(" {1,}$", "", sub(".*=", "", versions[grep('mistry', versions)]))
    trans <- sub(" {1,}$", "", sub(".*=", "", versions[grep('ome|rence', versions)]))
    if(length(trans) == 0) trans <- "NA"; if(length(chemy) == 0) chemy <- "NA"
    # cat(paste("Binding", chemy, trans, file.exists(fname), "\n"))
    y <- cbind(Library = basename(lib), Chemistry = chemy, Reference = trans, read.csv(fname, check.names = FALSE))
    colnames(y) <- gsub("^ {1,}", "", gsub("Antibody:", "", colnames(y), ignore.case = TRUE))
    return(y)
  })); if(class(metsums) == 'try-error'){ print(libs); stop('failed') }
  chems <- unlist(sapply(metsums, function(x) x[2] ), use.name = FALSE)
  hierarchy <- unique(c(hierarchy, unique(chems)))
  metsums <- metsums[this_order(x = chems, ref = hierarchy)]
  chems <- chems[this_order(x = chems, ref = hierarchy)]
  cat("Chemistries:", paste0(unique(chems), collapse = ", "), "\n")
  lchems <- c(list(unique(chems)), unique(chems))
  if(all(sapply(lchems, length) == 1)) lchems <- list(unique(chems))
  for(chem in lchems){
    chname <- if(length(chem) ==1) gsub("\\(|\\)| |\\'", "", chem) else "all"
    sumtabft <- paste0(sumtabf, "", chname, "_libraries_summary.csv")
    cat(" -", basename(sumtabft), "\n")
    sumtab <- data.frame(data.table::rbindlist(metsums[chems %in% chem], fill = TRUE), check.names = FALSE)
    cnames <- if(hierarchy[1] %in% chem) colnames(metsums[[which(chems %in% hierarchy[1])[1]]]) else colnames(sumtab)
    sumtab <- sumtab[, cnames]
    tsumtab <- sumtab[, head(colnames(sumtab), 6)]; cat("Cleaning:\n")
    colnames(tsumtab) <- gsub(" {2,}", " ", gsub("per Cell|per Cells|Estimated", "", colnames(tsumtab))); cat("Names, ")
    colnames(tsumtab) <- gsub(" $", "", colnames(tsumtab)); cat("Spaces, ")
    colnames(tsumtab) <- gsub("Number of", "#", colnames(tsumtab)); cat("Num, ")
    colnames(tsumtab) <- gsub("Reads", "RDS", colnames(tsumtab)); cat("Reads, ")
    colnames(tsumtab) <- gsub("Genes", "GNS", colnames(tsumtab)); cat("Genes, ")
    colnames(tsumtab) <- gsub("Chemistry", "CHEM", colnames(tsumtab)); cat("and Chemistry\n")
    tsumtab[, 2] <- gsub("single cell ", "", tsumtab[, 2], ignore.case = TRUE)
    print(tsumtab)
    write.csv(sumtab, file = sumtabft, row.names = FALSE)

    core_cnames <- c(
      "Estimated Number of Cells", "Mean Reads per Cell",
      "Median Genes per Cell", "Number of Reads", "Median UMI Counts per Cell"
    )
    if(nrow(sumtab) > 1){
      cat("Creating plots\n")
      # source('/mnt/BioHome/ciro/scripts/functions/handy_functions.R')
      sumtab <- sumtab[, colSums(sapply(sumtab, is.na)) == 0]
      if(sum(colnames(sumtab) %in% core_cnames) >= 2){
        cat("Grid\n")
        ddf <- sumtab; colnames(ddf) <- make.names(colnames(ddf))
        cnames <- colnames(ddf)[colnames(sumtab) %in% core_cnames]#colnames(ddf)[c(4:7, 24)]
        ddf <- data.frame(apply(X = ddf[, cnames], MARGIN = 2, FUN = function(x) as.numeric(gsub(",", "", x)) ))
        hto_pairs <- gtools::combinations(length(cnames), r = 2, v = cnames, set = TRUE, repeats.allowed = FALSE)
        p <- list()
        for(i in head(1:nrow(hto_pairs), 10)){
          p[[i]] <- ggplot(ddf, aes_string(x = hto_pairs[i, 1], hto_pairs[i, 2]), colour = cnames[3]) +
            geom_point(size = 2) + labs(x = gsub("\\.", " ", hto_pairs[i, 1]), y = gsub("\\.", " ", hto_pairs[i, 2])) +
            theme_minimal() + theme(legend.position = "none")
        }
        pdf(sub("\\.csv$", "_grid.pdf", sumtabft), width = 12, height = 12)
        print(cowplot::plot_grid(plotlist = p))
        dev.off()
      }
      # sumtab[is.na(sumtab)] <- 0
      sumtab2plot <- data.table::melt(sumtab, id.vars = "Library")
      sumtab2plot$value <- as.numeric(gsub("%|,", "", sumtab2plot$value))
      sumtab2plot <- sumtab2plot[!is.na(sumtab2plot$value), ]
      #sumtab2plot$variable <- sapply(sumtab2plot$variable, newlines, ln = 3, sepchar = ' ')
      sumtab2plot$variable <- as.character(sumtab2plot$variable)
      head(sumtab2plot, nrow(sumtab))

      thisgrid <- c(1, 1)
      fname <- sub("\\.csv$", ".pdf", sumtabft)
      if(!finished_file(fname) || TRUE){
        cat("Plotting\n")
        # print(plot_qcs_bars(sumtab2plot))
        cplotting <- unique(sumtab2plot$variable); cplotting <- cplotting[!grepl("Q30|Barcodes", cplotting)]
        if(length(cplotting) == 0) cplotting <- unique(sumtab2plot$variable)
        pdf(fname, width = 10 * thisgrid[1], height = 10 * thisgrid[2])
        tvar <- lapply(cplotting, function(x){
          cat(x); mytab2plot <- sumtab2plot[sumtab2plot$variable == x, ]
          if(all(is.na(mytab2plot[, "value"]))){ cat("\n"); return(NULL) }else{ cat(" - p\n") }
          try(print(plot_qcs_bars(mytab2plot) + labs(x = NULL, y = NULL, subtitle = x)), silent = TRUE)
        })
        graphics.off(); cat("\n")
      }
    }
  }
}else{
  cat("The summary wasn't performed.\nNo valid path:", opt$input, "\n")
}
