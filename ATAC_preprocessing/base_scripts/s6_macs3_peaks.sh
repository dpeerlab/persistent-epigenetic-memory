#!/bin/bash
#SBATCH --job-name=s6_macs3_peaks_{{BASE_NAME}}
#SBATCH --output={{LOG_DIR}}/s6_macs3_peaks_{{BASE_NAME}}.out
#SBATCH --error={{LOG_DIR}}/s6_macs3_peaks_{{BASE_NAME}}.err
#SBATCH --partition=cpuqueue
#SBATCH --cpus-per-task=4
#SBATCH --ntasks=1
#SBATCH --mem=80G
#SBATCH --time=4:00:00

# Load conda environment
source /data/peer/sotougl/Software/miniconda3/etc/profile.d/conda.sh
conda activate macs3_env

# Set variables
tagDir="{{TAG_DIR}}"
macs3Dir="{{MACS3_DIR}}"
baseName="{{BASE_NAME}}"

# MACS3 parameters
pval_thresh={{PVAL_THRESH}}
smooth_window={{SMOOTH_WINDOW}}
shiftsize=$((- smooth_window / 2))
genome_size={{GENOME_SIZE}}

echo "Starting MACS3 peak calling for sample: ${baseName}"
echo "Parameters:"
echo "  P-value threshold: ${pval_thresh}"
echo "  Smooth window: ${smooth_window}"
echo "  Shift size: ${shiftsize}"
echo "  Genome size: ${genome_size}"
echo "  Input TAG file: ${tagDir}/${baseName}.adjusted.tag.gz"
echo "  Output directory: ${macs3Dir}"

# Create output directory if it doesn't exist
mkdir -p ${macs3Dir}

# Run MACS3 peak calling
echo "Running MACS3 callpeak..."
macs3 callpeak \
    -t ${tagDir}/${baseName}.adjusted.tag.gz \
    -f BED \
    -n ${baseName} \
    --nomodel \
    --shift ${shiftsize} \
    --extsize ${smooth_window} \
    -g ${genome_size} \
    -p ${pval_thresh} \
    --outdir ${macs3Dir} \
    --keep-dup all \
    --call-summits

# Check if MACS3 completed successfully
if [ $? -eq 0 ]; then
    echo "MACS3 peak calling completed successfully"
    
    # List output files
    echo "Output files generated:"
    ls -lh ${macs3Dir}/${baseName}*
    
    # Count peaks
    if [ -f "${macs3Dir}/${baseName}_peaks.narrowPeak" ]; then
        PEAK_COUNT=$(wc -l < ${macs3Dir}/${baseName}_peaks.narrowPeak)
        echo "Number of peaks called: ${PEAK_COUNT}"
    fi
    
    # Count summits if generated
    if [ -f "${macs3Dir}/${baseName}_summits.bed" ]; then
        SUMMIT_COUNT=$(wc -l < ${macs3Dir}/${baseName}_summits.bed)
        echo "Number of summits identified: ${SUMMIT_COUNT}"
    fi
else
    echo "ERROR: MACS3 peak calling failed for ${baseName}"
    exit 1
fi

echo "MACS3 peak calling pipeline completed for ${baseName}"
