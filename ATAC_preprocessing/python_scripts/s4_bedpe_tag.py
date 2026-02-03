#!/usr/bin/env python3

import pandas as pd
import os
from pathlib import Path

def setup_directories():
    """
    Create the required directory structure
    """
    directories = [
        "raw_data",
        "jobs",
        "logs",
        "intermediate_outputs",
        "intermediate_outputs/bam",
        "intermediate_outputs/bed",
        "intermediate_outputs/tag",
        "intermediate_outputs/fragments",
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
    Generate individual job scripts from template

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
        job_content = job_content.replace("{{BAM_DIR}}", config['bam_dir'])
        job_content = job_content.replace("{{BED_DIR}}", config['bed_dir'])
        job_content = job_content.replace("{{TAG_DIR}}", config['tag_dir'])
        job_content = job_content.replace("{{FRAG_DIR}}", config['frag_dir'])

        # Write job script with s4_ prefix
        job_script_path = Path("jobs") / f"s4_bedpe_tag_{sample_name}.sh"

        with open(job_script_path, 'w') as f:
            f.write(job_content)

        # Make script executable
        os.chmod(job_script_path, 0o755)

        job_scripts_created.append(job_script_path)
        print(f"Created: {job_script_path}")

    return job_scripts_created

def main():
    """
    Main function for S4 BEDPE, TAG and Fragments processing job generation
    """
    print("S4 BEDPE, TAG and Fragments Processing Job Generator")
    print("=" * 60)

    # Configuration
    config = {
        'bam_dir': 'intermediate_outputs/bam',
        'bed_dir': 'intermediate_outputs/bed',
        'tag_dir': 'intermediate_outputs/tag',
        'frag_dir': 'intermediate_outputs/fragments',
        'log_dir': 'logs'
    }

    # File paths
    input_table = 'sample_table.csv'
    template_script = 'base_scripts/s4_bedpe_tag.sh'

    # Setup directories
    setup_directories()

    # Check if input files exist
    if not os.path.exists(input_table):
        print(f"\nWarning: Input table '{input_table}' not found.")
        print(f"\nPlease create your input table as '{input_table}' with the format shown in the example.")
        return

    if not os.path.exists(template_script):
        print(f"\nWarning: Template script '{template_script}' not found.")
        print("Please place your bash template script 's4_bedpe_tag.sh' in the base_scripts/ directory.")
        print("The template should use placeholders like {{BASE_NAME}}, {{LOG_DIR}}, {{BED_DIR}}, {{TAG_DIR}}, {{FRAG_DIR}}, etc.")
        return

    # Generate job scripts
    print(f"\nReading input table: {input_table}")
    print(f"Using template: {template_script}")

    job_scripts = generate_job_scripts(input_table, template_script, config)

    if job_scripts:
        # Create submission script
        print(f"\nSuccessfully generated {len(job_scripts)} S4 BEDPE, TAG and Fragments processing job scripts!")
        print("\nGenerated scripts will:")
        print("- Sort BAM files by name")
        print("- Convert BAM to BEDPE format")
        print("- Generate TAG files from BEDPE")
        print("- Create adjusted TAG files")
        print("- Generate Fragments files")
        print("- Perform quality checks")
    else:
        print("Failed to generate job scripts. Please check the error messages above.")

if __name__ == "__main__":
    main()
