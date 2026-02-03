#!/bin/bash
#SBATCH --job-name=s3_cleaning_{{SAMPLE_NAME}}
#SBATCH --output={{LOG_DIR}}/s3_cleaning_{{SAMPLE_NAME}}.out
#SBATCH --error={{LOG_DIR}}/s3_cleaning_{{SAMPLE_NAME}}.err
#SBATCH --partition=cpuqueue
#SBATCH --cpus-per-task=16
#SBATCH --ntasks=1
#SBATCH --mem=128G
#SBATCH --time=12:00:00

# Set variables
source /data/peer/sotougl/Software/miniconda3/etc/profile.d/conda.sh

name="{{SAMPLE_NAME}}"
bamDir="{{BAM_DIR}}"
cores=32
blacklist="{{BLACKLIST_PATH}}"

echo "Starting S3 cleaning pipeline for sample: ${name}"

# Activate samtools environment
conda activate atac_env

echo "Step 1: Extracting chromosomes of interest"
samtools view -@ ${cores} -b ${bamDir}/${name}.bwa.old_clean.bam chr{1..19} chrX -o ${bamDir}/${name}.bwa.clean_chromosomes.bam
echo "Finished: Extracting chromosomes"

echo "Step 2: Removing reads in blacklist regions"
bedtools intersect -v -abam ${bamDir}/${name}.bwa.clean_chromosomes.bam -b ${blacklist} > ${bamDir}/${name}.bwa.tmp.bam
echo "Finished: Blacklist filtering"

echo "Step 3: Sorting by read name"
samtools sort -n -@ ${cores} -o ${bamDir}/${name}.bwa.clean.sortedByName.bam ${bamDir}/${name}.bwa.tmp.bam
echo "Finished: Sorting by name"

echo "Step 4: Running samtools fixmate"
samtools fixmate -m ${bamDir}/${name}.bwa.clean.sortedByName.bam ${bamDir}/${name}.bwa.clean.fixmate.bam
echo "Finished: Fixmate"

echo "Step 5: Sorting by genomic coordinates"
samtools sort -@ ${cores} -o ${bamDir}/${name}.bwa.clean.fixmate.sortedByCoord.bam ${bamDir}/${name}.bwa.clean.fixmate.bam
echo "Finished: Sorting by coordinates"

echo "Step 6: Filtering unwanted reads"
samtools view -@ ${cores} -b -F 1804 -f 2 ${bamDir}/${name}.bwa.clean.fixmate.sortedByCoord.bam > ${bamDir}/${name}.bwa.clean.bam
echo "Finished: Final filtering"

echo "Step 7: Indexing final clean BAM"
samtools index -@ ${cores} ${bamDir}/${name}.bwa.clean.bam
echo "Finished: Indexing"

echo "Step 8: Quality check - counting reads"
ORIGINAL_COUNT=$(samtools view -@ ${cores} -c ${bamDir}/${name}.bwa.old_clean.bam)
CHROMOSOMES_COUNT=$(samtools view -@ ${cores} -c ${bamDir}/${name}.bwa.clean_chromosomes.bam)
BLACKLIST_COUNT=$(samtools view -@ ${cores} -c ${bamDir}/${name}.bwa.tmp.bam)
FINAL_COUNT=$(samtools view -@ ${cores} -c ${bamDir}/${name}.bwa.clean.bam)

echo "Quality check results for ${name}:"
echo "Original BAM reads: $ORIGINAL_COUNT"
echo "After chromosome filtering: $CHROMOSOMES_COUNT"
echo "After blacklist filtering: $BLACKLIST_COUNT"
echo "Final clean BAM reads: $FINAL_COUNT"

# Calculate percentages
if [ $ORIGINAL_COUNT -gt 0 ]; then
    RETENTION_PERCENT=$(echo "scale=2; $FINAL_COUNT * 100 / $ORIGINAL_COUNT" | bc)
    echo "Read retention: ${RETENTION_PERCENT}%"
fi

echo "S3 cleaning completed for sample: ${name}"
