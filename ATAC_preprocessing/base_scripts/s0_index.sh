#!/bin/bash
#SBATCH --job-name=s0_bwa_index
#SBATCH --output=/data/peer/sotougl/review_2025/ATAC_2025/logs/s0_bwa_index.out
#SBATCH --error=/data/peer/sotougl/review_2025/ATAC_2025/logs/s0_bwa_index.err
#SBATCH --partition=cpuqueue
#SBATCH --cpus-per-task=32
#SBATCH --ntasks=1
#SBATCH --mem=128G
#SBATCH --time=48:00:00

source /data/peer/sotougl/Software/miniconda3/etc/profile.d/conda.sh

conda activate atac_env

mkdir -p /data/peer/sotougl/review_2025/ATAC_2025/index

bwa index -p /data/peer/sotougl/review_2025/ATAC_2025/index/mm10 -a bwtsw /data/peer/sotougl/review_2025/ATAC_2025/genomes/GRCm38.primary_assembly.genome.fa 
