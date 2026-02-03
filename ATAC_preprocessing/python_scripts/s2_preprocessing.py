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
        job_content = template_content.replace("{{SAMPLE_NAME}}", sample_name)
        job_content = job_content.replace("{{LOG_DIR}}", config['log_dir'])
        job_content = job_content.replace("{{BAM_DIR}}", config['bam_dir'])
        job_content = job_content.replace("{{REPORTS_DIR}}", config['reports_dir'])
        
        # Write job script with s2_ prefix
        job_script_path = Path("jobs") / f"s2_preprocessing_{sample_name}.sh"
        
        with open(job_script_path, 'w') as f:
            f.write(job_content)
        
        # Make script executable
        os.chmod(job_script_path, 0o755)
        
        job_scripts_created.append(job_script_path)
        print(f"Created: {job_script_path}")
    
    return job_scripts_created

def main():
    """
    Main function for S2 processing job generation
    """
    print("S2 Processing Job Generator")
    print("=" * 40)
    
    # Configuration
    config = {
        'bam_dir': 'intermediate_outputs/bam',
        'reports_dir': 'intermediate_outputs/reports',
        'log_dir': 'logs'
    }
    
    # File paths
    input_table = 'sample_table.csv'
    template_script = 'base_scripts/s2_preprocessing.sh'
    
    # Setup directories
    setup_directories()
    
    # Check if input files exist
    if not os.path.exists(input_table):
        print(f"\nWarning: Input table '{input_table}' not found.")
        print(f"\nPlease create your input table as '{input_table}' with the format shown in the example.")
        return
    
    if not os.path.exists(template_script):
        print(f"\nWarning: Template script '{template_script}' not found.")
        print("Please place your bash template script 's2_preprocessing.sh' in the base_scripts/ directory.")
        print("The template should use placeholders like {{SAMPLE_NAME}}, {{LOG_DIR}}, etc.")
        return
    
    # Generate job scripts
    print(f"\nReading input table: {input_table}")
    print(f"Using template: {template_script}")
    
    job_scripts = generate_job_scripts(input_table, template_script, config)
    
    if job_scripts:
        # Create submission script
        print(f"\nSuccessfully generated {len(job_scripts)} S2 processing job scripts!")
    else:
        print("Failed to generate job scripts. Please check the error messages above.")

if __name__ == "__main__":
    main()
