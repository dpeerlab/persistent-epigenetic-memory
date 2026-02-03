#!/bin/bash
#SBATCH --job-name=s2_preprocessing_{{SAMPLE_NAME}}
#SBATCH --output={{LOG_DIR}}/s2_preprocessing_{{SAMPLE_NAME}}.out
#SBATCH --error={{LOG_DIR}}/s2_preprocessing_{{SAMPLE_NAME}}.err
#SBATCH --partition=cpuqueue
#SBATCH --cpus-per-task=32
#SBATCH --ntasks=1
#SBATCH --mem=128G
#SBATCH --time=24:00:00

# Set variables
source /data/peer/sotougl/Software/miniconda3/etc/profile.d/conda.sh

name="{{SAMPLE_NAME}}"
bamDir="{{BAM_DIR}}"
reportsDir="{{REPORTS_DIR}}"
cores=32

# Store variables
echo "Starting: Adding groups with Picard"
conda activate atac_env
picard AddOrReplaceReadGroups \
    I=${bamDir}/${name}.bwa.filtered.sorted.bam \
    O=${bamDir}/${name}.bwa.filtered.sorted.RG.bam \
    RGID=Sample_${name} \
    RGLB=lib1 \
    RGPL=illumina \
    RGPU=unit1 \
    RGSM=${name} \
    RGCN=center1 \
    RGDS=description \
    RGDT=2025-01-01
echo "Finished: Adding groups with Picard"

echo "Starting: Marking duplicates with Picard"
picard MarkDuplicates \
    I=${bamDir}/${name}.bwa.filtered.sorted.RG.bam \
    O=${bamDir}/${name}.bwa.filtered.sorted.dupmark.bam \
    METRICS_FILE=${reportsDir}/${name}.PICARD.dup.qc \
    VALIDATION_STRINGENCY=LENIENT \
    ASSUME_SORTED=true \
    REMOVE_DUPLICATES=false
echo "Finished: Marking duplicates with Picard"

echo "Starting: Removing duplicates"
samtools view -@ ${cores} -F 1804 -f 2 -b ${bamDir}/${name}.bwa.filtered.sorted.dupmark.bam > ${bamDir}/${name}.bwa.old_clean.bam
samtools index -@ ${cores} ${bamDir}/${name}.bwa.old_clean.bam
echo "Finished: Removing duplicates"

echo "Starting: SAMstats"
samtools sort -n -@ ${cores} ${bamDir}/${name}.bwa.old_clean.bam -O SAM -o ${bamDir}/${name}.samstat2.sorted.sam
SAMstats --sorted_sam_file ${bamDir}/${name}.samstat2.sorted.sam --outf ${reportsDir}/${name}.flagstat.qc
echo "Finished: SAMstats"

# =============================
# Compute library complexity
# =============================
# Sort by name
# convert to bedPE and obtain fragment coordinates
# sort by position and strand
# Obtain unique count statistics
# TotalReadPairs [tab] DistinctReadPairs [tab] OneReadPair [tab] TwoReadPairs [tab] NRF=Distinct/Total [tab] PBC1=OnePair/Distinct [tab] PBC2=OnePair/TwoPair
echo "Starting: Library complexity"
samtools sort -n -@ ${cores} ${bamDir}/${name}.bwa.filtered.sorted.dupmark.bam -o ${bamDir}/${name}.bwa.filtered.sorted.dupmark.srt.tmp.bam
bedtools bamtobed -bedpe -i ${bamDir}/${name}.bwa.filtered.sorted.dupmark.srt.tmp.bam | \
awk 'BEGIN{OFS="\t"}{print $1,$2,$4,$6,$9,$10}' | \
grep -v 'chrM' \
| sort | uniq -c | \
awk 'BEGIN{mt=0;m0=0;m1=0;m2=0} ($1==1){m1=m1+1} ($1==2){m2=m2+1} {m0=m0+1} {mt=mt+$1} END{printf "%d\t%d\t%d\t%d\t%f\t%f\t%f\n",mt,m0,m1,m2,m0/mt,m1/m0,m1/m2}' > ${reportsDir}/${name}.pbc.qc
echo "Finished: Library complexity"

echo "Starting: Checking"
ORIGINAL_COUNT=$(samtools view -@ ${cores} -c ${bamDir}/${name}.bwa.old_clean.bam)
SORTED_COUNT=$(samtools view -@ ${cores} -c ${bamDir}/${name}.samstat2.sorted.sam)
echo "Original BAM: $ORIGINAL_COUNT reads"
echo "Sorted BAM: $SORTED_COUNT reads"

ORIGINAL_COUNT=$(samtools view -@ ${cores} -c ${bamDir}/${name}.bwa.filtered.sorted.dupmark.bam)
SORTED_COUNT=$(samtools view -@ ${cores} -c ${bamDir}/${name}.bwa.filtered.sorted.dupmark.srt.tmp.bam)
echo "Original BAM: $ORIGINAL_COUNT reads"
echo "Sorted BAM: $SORTED_COUNT reads"
echo "Finished: Checking"

echo "Job completed for sample: ${name}"
