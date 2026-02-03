#!/bin/bash
#SBATCH --job-name=s4_bedpe_tag_{{BASE_NAME}}
#SBATCH --output={{LOG_DIR}}/s4_bedpe_tag_{{BASE_NAME}}.out
#SBATCH --error={{LOG_DIR}}/s4_bedpe_tag_{{BASE_NAME}}.err
#SBATCH --partition=cpuqueue
#SBATCH --cpus-per-task=16
#SBATCH --ntasks=1
#SBATCH --mem=64G
#SBATCH --time=8:00:00

# Set variables
source /data/peer/sotougl/Software/miniconda3/etc/profile.d/conda.sh
bamDir="{{BAM_DIR}}"
bedDir="{{BED_DIR}}"
tagDir="{{TAG_DIR}}"
fragDir="{{FRAG_DIR}}"
baseName="{{BASE_NAME}}"
cores=16

echo "Starting S4 bedpe and tag generation pipeline for sample: ${baseName}"

echo "Step 1: Sorting BAM file by name"
conda activate atac_env
samtools sort -n -@ ${cores} ${bamDir}/${baseName}.bwa.clean.bam -o ${bamDir}/${baseName}.bwa.clean.name_sorted.bam
echo "Finished: BAM sorting by name"

echo "Step 2: Converting BAM to BEDPE format"
bedtools bamtobed -bedpe -mate1 -i ${bamDir}/${baseName}.bwa.clean.name_sorted.bam | gzip -nc > ${bedDir}/${baseName}.bedpe.gz
echo "Finished: BEDPE generation"

echo "Step 3: Generating TAG file from BEDPE"
zcat ${bedDir}/${baseName}.bedpe.gz | awk 'BEGIN{OFS="\t"}{printf "%s\t%s\t%s\tN\t1000\t%s\n%s\t%s\t%s\tN\t1000\t%s\n",$1,$2,$3,$9,$4,$5,$6,$10}' | \
gzip -nc > ${tagDir}/${baseName}.tag.gz
echo "Finished: TAG file generation"

echo "Step 4: Generating adjusted TAG file"
zcat ${bedDir}/${baseName}.bedpe.gz | \
awk 'BEGIN{OFS="\t"}{printf "%s\t%s\t%s\tN\t1000\t%s\n%s\t%s\t%s\tN\t1000\t%s\n",$1,$2,$3,$9,$4,$5,$6,$10}' | \
awk -F $'\t' 'BEGIN {OFS = FS}{ if ($6 == "+") {$2 = $2 + 4} else if ($6 == "-") {$3 = $3 - 5} print $0}' | \
gzip -nc > ${tagDir}/${baseName}.adjusted.tag.gz
echo "Finished: Adjusted TAG file generation"

echo "Step 5: Generating Fragments file"
zcat ${bedDir}/${baseName}.bedpe.gz | awk -v sample="${baseName}" -v value="1" '{
    chromosome = $1
    start = $2 < $3 ? ($2 < $5 ? ($2 < $6 ? $2 : $6) : ($5 < $6 ? $5 : $6)) : ($3 < $5 ? ($3 < $6 ? $3 : $6) : ($5 < $6 ? $5 : $6))
    end = $2 > $3 ? ($2 > $5 ? ($2 > $6 ? $2 : $6) : ($5 > $6 ? $5 : $6)) : ($3 > $5 ? ($3 > $6 ? $3 : $6) : ($5 > $6 ? $5 : $6))
    print chromosome "\t" start "\t" end "\t" sample "\t" value
}' | gzip > ${fragDir}/${baseName}.Fragments.tsv.gz
echo "Finished: Fragments file generation"

echo "Step 6: Quality check - counting records"
BEDPE_COUNT=$(zcat ${bedDir}/${baseName}.bedpe.gz | wc -l)
TAG_COUNT=$(zcat ${tagDir}/${baseName}.tag.gz | wc -l)
ADJUSTED_TAG_COUNT=$(zcat ${tagDir}/${baseName}.adjusted.tag.gz | wc -l)
FRAGMENTS_COUNT=$(zcat ${fragDir}/${baseName}.Fragments.tsv.gz | wc -l)

echo "Quality check results for ${baseName}:"
echo "BEDPE records: $BEDPE_COUNT"
echo "TAG records: $TAG_COUNT"
echo "Adjusted TAG records: $ADJUSTED_TAG_COUNT"
echo "Fragments records: $FRAGMENTS_COUNT"
