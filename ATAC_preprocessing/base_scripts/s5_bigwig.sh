#!/bin/bash
#SBATCH --job-name=s5_bigwig_{{BASE_NAME}}
#SBATCH --output={{LOG_DIR}}/s5_bigwig_{{BASE_NAME}}.out
#SBATCH --error={{LOG_DIR}}/s5_bigwig_{{BASE_NAME}}.err
#SBATCH --partition=cpuqueue
#SBATCH --cpus-per-task=8
#SBATCH --ntasks=1
#SBATCH --mem=32G
#SBATCH --time=4:00:00

# Set variables
source /data/peer/sotougl/Software/miniconda3/etc/profile.d/conda.sh
bamDir="{{BAM_DIR}}"
bigwigDir="{{BIGWIG_DIR}}"
baseName="{{BASE_NAME}}"
minimum_fragment_size=10
maximum_fragment_size=600

echo "Starting S5 BigWig generation pipeline for sample: ${baseName}"

# Activate R environment
conda activate archr_env

echo "Step 1: Creating temporary R script"
# Create temporary R script
cat > temp_bigwig_${baseName}.R << 'EOF'
args <- commandArgs(trailingOnly = TRUE)
bamDir <- args[1]
bigwigDir <- args[2]
fileName <- args[3]
minimum_fragment_size <- as.numeric(args[4])
maximum_fragment_size <- as.numeric(args[5])

library(GenomicAlignments)
library(GenomicRanges)
library(Rsamtools)
library(rtracklayer)

bamFile <- paste0(bamDir, '/', fileName, '.bwa.clean.bam')

cat("Reading BAM file:", bamFile, "\n")

## Read Bam file
param <- ScanBamParam(what = "qname")
bam.gr <- readGAlignmentPairs(bamFile, param=param)
bam.gr <- granges(bam.gr)
widths <- width(bam.gr)

cat("Total fragments before filtering:", length(bam.gr), "\n")

## Filter by fragment size
keep <- (widths >= minimum_fragment_size) & (widths <= maximum_fragment_size)
bam.gr <- bam.gr[keep]

cat("Fragments after size filtering (", minimum_fragment_size, "-", maximum_fragment_size, "bp):", length(bam.gr), "\n")

## Adjust +4 -5 to both strands
start(bam.gr) <- start(bam.gr) + 4
end(bam.gr) <- end(bam.gr) - 5

## Get only coverage of insert sizes (5' and 3' cut sites)
cat("Generating cut sites BigWig...\n")
bw_name <- paste0(bigwigDir, '/', fileName, '_cutsites.bw')
bam.cov <- coverage(c(resize(bam.gr, 1, 'start'), resize(bam.gr, 1, 'end')))
rtracklayer::export(object = bam.cov, con = bw_name, format = "BigWig")
cat("Created:", bw_name, "\n")

## Get whole coverage
cat("Generating fragments BigWig...\n")
bw_name <- paste0(bigwigDir, '/', fileName, '.bw')
bam.cov <- coverage(bam.gr)
rtracklayer::export(object = bam.cov, con = bw_name, format = "BigWig")
cat("Created:", bw_name, "\n")

## Normalized coverage
cat("Generating normalized BigWig...\n")
total_reads_normalization <- function(gr){
  total_reads <- length(gr)
  gr.cov <- coverage(gr) / total_reads * 1000000
  gr.cov
}
bw_name <- paste0(bigwigDir, '/', fileName, '_normalized.bw')
gr.cov <- total_reads_normalization(bam.gr)
rtracklayer::export(object = gr.cov, con = bw_name, format = "BigWig")
cat("Created:", bw_name, "\n")

cat("BigWig generation completed successfully!\n")
EOF

echo "Step 2: Running R script to generate BigWig files"
Rscript temp_bigwig_${baseName}.R ${bamDir} ${bigwigDir} ${baseName} ${minimum_fragment_size} ${maximum_fragment_size}

echo "Step 3: Cleaning up temporary files"
rm temp_bigwig_${baseName}.R

echo "Step 4: Quality check - verifying BigWig files"
CUTSITES_BW="${bigwigDir}/${baseName}_cutsites.bw"
FRAGMENTS_BW="${bigwigDir}/${baseName}.bw"
NORMALIZED_BW="${bigwigDir}/${baseName}_normalized.bw"

if [ -f "$CUTSITES_BW" ]; then
    CUTSITES_SIZE=$(du -h "$CUTSITES_BW" | cut -f1)
    echo "Cut sites BigWig created: $CUTSITES_BW (size: $CUTSITES_SIZE)"
else
    echo "ERROR: Cut sites BigWig not created!"
fi

if [ -f "$FRAGMENTS_BW" ]; then
    FRAGMENTS_SIZE=$(du -h "$FRAGMENTS_BW" | cut -f1)
    echo "Fragments BigWig created: $FRAGMENTS_BW (size: $FRAGMENTS_SIZE)"
else
    echo "ERROR: Fragments BigWig not created!"
fi

if [ -f "$NORMALIZED_BW" ]; then
    NORMALIZED_SIZE=$(du -h "$NORMALIZED_BW" | cut -f1)
    echo "Normalized BigWig created: $NORMALIZED_BW (size: $NORMALIZED_SIZE)"
else
    echo "ERROR: Normalized BigWig not created!"
fi

echo "S5 BigWig generation pipeline completed for sample: ${baseName}"
