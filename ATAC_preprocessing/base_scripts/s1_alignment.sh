#!/bin/bash
#SBATCH --job-name=s1_bwa_alignment_{{SAMPLE_NAME}}
#SBATCH --output={{LOG_DIR}}/s1_bwa_alignment_{{SAMPLE_NAME}}.out
#SBATCH --error={{LOG_DIR}}/s1_bwa_alignment_{{SAMPLE_NAME}}.err
#SBATCH --partition=cpuqueue
#SBATCH --cpus-per-task=32
#SBATCH --ntasks=1
#SBATCH --mem=128G
#SBATCH --time=48:00:00

# Set variables
source /data/peer/sotougl/Software/miniconda3/etc/profile.d/conda.sh

name="{{SAMPLE_NAME}}"
ref="{{REF_GENOME}}"
fastqDir="{{FASTQ_DIR}}"
bamDir="{{BAM_DIR}}"
reportsDir="{{REPORTS_DIR}}"
cores=32

# Store variables
echo "Starting: bwa alignment"
conda activate atac_env
bwa mem ${ref} -t 32 -M -T 10 -a ${fastqDir}/${name}_1.fastq.gz ${fastqDir}/${name}_2.fastq.gz > ${bamDir}/${name}.bwa.sam
echo "Finished: bwa alignment"

echo "Starting: BAM file conversion"
samtools view -@ ${cores} -bS ${bamDir}/${name}.bwa.sam > ${bamDir}/${name}.bwa.bam
samtools sort -@ ${cores} ${bamDir}/${name}.bwa.bam -o ${bamDir}/${name}.bwa.sorted.bam
samtools index -@ ${cores} ${bamDir}/${name}.bwa.sorted.bam
echo "Finished: BAM file conversion"

echo "Starting: SAMstats"
samtools sort -@ ${cores} -n ${bamDir}/${name}.bwa.bam -O SAM -o ${bamDir}/${name}.samstat.sorted.sam
SAMstats --sorted_sam_file ${bamDir}/${name}.samstat.sorted.sam --outf ${reportsDir}/${name}.SAMstats.txt
echo "Finished: SAMstats"

MAPQ_THRESH=30
echo "Starting: Filtering"
samtools view -@ ${cores} -F 1804 -f 2 -q ${MAPQ_THRESH} -u ${bamDir}/${name}.bwa.sorted.bam > ${bamDir}/${name}.bwa.tmp.filtered.sorted.bam
samtools sort -@ ${cores} -n ${bamDir}/${name}.bwa.tmp.filtered.sorted.bam -o ${bamDir}/${name}.bwa.tmp.filtered.sorted_name.bam
samtools fixmate -@ ${cores} -r ${bamDir}/${name}.bwa.tmp.filtered.sorted_name.bam ${bamDir}/${name}.bwa.tmp.filtered.sorted_name.fixmate.bam
samtools view -@ ${cores} -F 1804 -f 2 -u ${bamDir}/${name}.bwa.tmp.filtered.sorted_name.fixmate.bam > ${bamDir}/${name}.bwa.tmp.filtered.sorted_name.fixmate.filtered.bam
samtools sort -@ ${cores} ${bamDir}/${name}.bwa.tmp.filtered.sorted_name.fixmate.filtered.bam -o ${bamDir}/${name}.bwa.filtered.sorted.bam
echo "Finished: Filtering"

echo "Starting: Checking"
ORIGINAL_COUNT=$(samtools view -c ${bamDir}/${name}.bwa.bam)
SORTED_COUNT=$(samtools view -c ${bamDir}/${name}.bwa.sorted.bam)
echo "Original BAM: $ORIGINAL_COUNT reads"
echo "Sorted BAM: $SORTED_COUNT reads"

ORIGINAL_COUNT=$(samtools view -c ${bamDir}/${name}.bwa.bam)
SORTED_COUNT=$(samtools view -c ${bamDir}/${name}.samstat.sorted.sam)
echo "Original BAM: $ORIGINAL_COUNT reads"
echo "Sorted BAM: $SORTED_COUNT reads"

ORIGINAL_COUNT=$(samtools view -c ${bamDir}/${name}.bwa.tmp.filtered.sorted.bam)
SORTED_COUNT=$(samtools view -c ${bamDir}/${name}.bwa.tmp.filtered.sorted_name.bam)
echo "Original BAM: $ORIGINAL_COUNT reads"
echo "Sorted BAM: $SORTED_COUNT reads"

ORIGINAL_COUNT=$(samtools view -c ${bamDir}/${name}.bwa.tmp.filtered.sorted_name.fixmate.filtered.bam)
SORTED_COUNT=$(samtools view -c ${bamDir}/${name}.bwa.filtered.sorted.bam)
echo "Original BAM: $ORIGINAL_COUNT reads"
echo "Sorted BAM: $SORTED_COUNT reads"
echo "Finished: Checking"

# Clean up temporary files (commented out for safety)
#rm -f ${bamDir}/${name}.bwa.tmp.filtered.sorted.bam
#rm -f ${bamDir}/${name}.bwa.tmp.filtered.sorted_name.bam
#rm -f ${bamDir}/${name}.bwa.tmp.filtered.sorted_name.fixmate.bam
#rm -f ${bamDir}/${name}.bwa.tmp.filtered.sorted_name.fixmate.filtered.bam


# Clean up original files (commented out for safety)
#rm -f ${bamDir}/${name}.bwa.bam
#rm -f ${bamDir}/${name}.bwa.sorted.bam
#rm -f ${bamDir}/${name}.bwa.sorted.bam.bai

echo "Job completed for sample: ${name}"
