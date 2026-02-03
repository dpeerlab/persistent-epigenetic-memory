#!/usr/bin/env python3

import pandas as pd
import os
from pathlib import Path

def setup_directories():
    """
    Create the required directory structure for MACS3 peak calling
    """
    directories = [
        "jobs",
        "logs",
        "intermediate_outputs",
        "intermediate_outputs/tag",
        "intermediate_outputs/macs3",
        "intermediate_outputs/reports"
    ]

    for directory in directories:
        Path(directory).mkdir(exist_ok=True, parents=True)

    print("Directory structure created successfully!")

def read_template(template_path):
    """
    Read the bash template script

    Args:
        template_path (str): Path to the template bash script

    Returns:
        str: Template content
    """
    try:
        with open(template_path, 'r') as f:
            template_content = f.read()
        return template_content
    except FileNotFoundError:
        print(f"Error: Template file '{template_path}' not found.")
        print("Please make sure the template script exists.")
        return None

def generate_job_scripts(input_table_path, template_path, config):
    """
    Generate individual MACS3 job scripts from template

    Args:
        input_table_path (str): Path to CSV file with condition and replicate columns
        template_path (str): Path to bash template script
        config (dict): Configuration parameters
    """

    # Read input table with better error handling
    try:
        df = pd.read_csv(input_table_path)
    except FileNotFoundError:
        print(f"Error: Input table '{input_table_path}' not found.")
        return False

    # Validate required columns
    if 'condition' not in df.columns or 'replicate' not in df.columns:
        print("Error: Input table must have 'condition' and 'replicate' columns.")
        print("Available columns:", df.columns.tolist())
        return False

    # Read template
    template_content = read_template(template_path)
    if template_content is None:
        return False

    # Generate job scripts
    job_scripts_created = []

    for index, row in df.iterrows():
        condition = row['condition']
        replicate = row['replicate']

        # Create sample name (e.g., D6_Ctrl_rep1)
        sample_name = f"{condition}_{replicate}"

        # Replace placeholders in template
        job_content = template_content.replace("{{BASE_NAME}}", sample_name)
        job_content = job_content.replace("{{LOG_DIR}}", config['log_dir'])
        job_content = job_content.replace("{{TAG_DIR}}", config['tag_dir'])
        job_content = job_content.replace("{{MACS3_DIR}}", config['macs3_dir'])
        
        # Replace MACS3 specific parameters
        job_content = job_content.replace("{{PVAL_THRESH}}", str(config['pval_thresh']))
        job_content = job_content.replace("{{SMOOTH_WINDOW}}", str(config['smooth_window']))
        job_content = job_content.replace("{{GENOME_SIZE}}", str(config['genome_size']))

        # Write job script with s6_ prefix
        job_script_path = Path("jobs") / f"s6_macs3_peaks_{sample_name}.sh"

        with open(job_script_path, 'w') as f:
            f.write(job_content)

        # Make script executable
        os.chmod(job_script_path, 0o755)

        job_scripts_created.append(job_script_path)
        print(f"Created: {job_script_path}")

    return job_scripts_created

def create_submission_script(job_scripts):
    """
    Create a master submission script to submit all MACS3 jobs

    Args:
        job_scripts (list): List of job script paths
    """
    submission_script = Path("jobs") / "submit_all_macs3_jobs.sh"
    
    with open(submission_script, 'w') as f:
        f.write("#!/bin/bash\n")
        f.write("# Master submission script for all MACS3 peak calling jobs\n\n")
        f.write("echo 'Submitting MACS3 peak calling jobs...'\n\n")
        
        for job_script in job_scripts:
            f.write(f"sbatch {job_script}\n")
            f.write(f"echo 'Submitted: {job_script.name}'\n")
            f.write("sleep 0.5  # Small delay between submissions\n\n")
        
        f.write(f"echo 'All {len(job_scripts)} MACS3 jobs submitted!'\n")
    
    # Make submission script executable
    os.chmod(submission_script, 0o755)
    print(f"\nCreated master submission script: {submission_script}")
    print(f"To submit all jobs, run: bash {submission_script}")

def main():
    """
    Main function for S6 MACS3 peak calling job generation
    """
    print("S6 MACS3 Peak Calling Job Generator")
    print("=" * 60)

    # Configuration for MACS3
    config = {
        'tag_dir': 'intermediate_outputs/tag',
        'macs3_dir': 'intermediate_outputs/macs3',
        'log_dir': 'logs',
        # MACS3 parameters
        'pval_thresh': 0.01,
        'smooth_window': 150,
        'genome_size': 2652783500  # mm38 genome size
    }

    # File paths
    input_table = 'sample_table.csv'
    template_script = 'base_scripts/s6_macs3_peaks.sh'

    # Setup directories
    setup_directories()

    # Check if input files exist
    if not os.path.exists(input_table):
        print(f"\nWarning: Input table '{input_table}' not found.")
        return

    if not os.path.exists(template_script):
        print(f"\nWarning: Template script '{template_script}' not found.")
        print("Please place your bash template script 's6_macs3_peaks.sh' in the base_scripts/ directory.")
        print("The template should use placeholders like {{BASE_NAME}}, {{LOG_DIR}}, {{TAG_DIR}}, {{MACS3_DIR}}, etc.")
        
        # Create base_scripts directory if it doesn't exist
        Path("base_scripts").mkdir(exist_ok=True)
        print("\nCreated 'base_scripts' directory. Please add your template script there.")
        return

    # Generate job scripts
    print(f"\nReading input table: {input_table}")
    print(f"Using template: {template_script}")
    print("\nMACS3 Parameters:")
    print(f"  P-value threshold: {config['pval_thresh']}")
    print(f"  Smooth window: {config['smooth_window']}")
    print(f"  Shift size: {-config['smooth_window']//2}")
    print(f"  Genome size: {config['genome_size']}")

    job_scripts = generate_job_scripts(input_table, template_script, config)

    if job_scripts:
        # Create submission script
        create_submission_script(job_scripts)
        
        print(f"\nSuccessfully generated {len(job_scripts)} MACS3 peak calling job scripts!")
        print("\nGenerated scripts will:")
        print("- Call peaks using MACS3 with adjusted TAG files")
        print("- Use nomodel mode with specified shift and extension sizes")
        print("- Generate narrowPeak files")
        print("- Call peak summits")
        print("- Report peak counts and quality metrics")
        
        print("\nNext steps:")
        print("1. Ensure TAG files exist in the tag directory")
        print("2. Review generated job scripts in the 'jobs' directory")
        print("3. Submit all jobs using: bash jobs/submit_all_macs3_jobs.sh")
        print("   Or submit individual jobs using: sbatch jobs/s6_macs3_peaks_<sample_name>.sh")
    else:
        print("Failed to generate job scripts. Please check the error messages above.")

if __name__ == "__main__":
    main()
