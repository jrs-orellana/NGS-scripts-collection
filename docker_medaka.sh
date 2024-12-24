#!/bin/bash

# Exit immediately if any command exits with a non-zero status
set -e

# Record the start time of the script
start_time=$(date +%s)

# Define the working directory
WORK_DIR="/media/user/project"  # Adjust this path if necessary

# Navigate to the working directory or exit with an error if it fails
cd "$WORK_DIR" || { echo "ERROR: Failed to change to the working directory $WORK_DIR"; exit 1; }

# Unset the GROUP variable to avoid conflicts with previously set values
unset GROUP

# Define the list of groups to process (e.g., directories for data)
GROUP_LIST=("batch_001" "batch_002" "batch_003")

# Function to process a single barcode
process_barcode() {
    local group="$1"            # The group being processed
    local barcode_dir="$2"      # The specific barcode directory
    local barcode_name          # Extract the barcode name from the directory
    barcode_name=$(basename "$barcode_dir")

    # Define paths for input FASTQ file, Flye output, and Medaka output
    local fastq_file="$barcode_dir/${barcode_name}.fastq.gz"
    local flye_output_dir="$FLYE_RESULT_DIR/$barcode_name"
    local medaka_output_dir="$MEDAKA_RESULT_DIR/$barcode_name"
    local assembly_file="$flye_output_dir/assembly.fasta"

    # Create necessary directories for Flye and Medaka outputs
    mkdir -p "$flye_output_dir" "$medaka_output_dir"

    # Check if the FASTQ file exists; skip processing if it does not
    if [ ! -f "$fastq_file" ]; then
        echo "WARNING: The FASTQ file $fastq_file does not exist. Skipping $barcode_name."
        return
    fi

    # Check if the assembly file exists; skip processing if it does not
    if [ ! -f "$assembly_file" ]; then
        echo "WARNING: The assembly file does not exist for $barcode_name. Skipping."
        return
    fi

    # Run Medaka to generate consensus sequences
    echo "Running Medaka for $barcode_name in $group..."
    sudo docker run --rm --gpus all \
        -v "$barcode_dir:/input" \
        -v "$flye_output_dir:/assembly" \
        -v "$medaka_output_dir:/output" \
        ontresearch/medaka:latest medaka_consensus \
        -i "/input/${barcode_name}.fastq.gz" \
        -d "/assembly/assembly.fasta" \
        -o "/output/" \
        -m r1041_e82_400bps_hac_v4.2.0 \
        -b 100

    # Check the exit status of the Medaka command
    if [ $? -ne 0 ]; then
        echo "ERROR: Medaka failed for $barcode_name."
    else
        echo "Medaka completed successfully for $barcode_name."
    fi
}

# Iterate over each group in the list
for GROUP in "${GROUP_LIST[@]}"; do
    echo "Processing group: $GROUP"
    
    # Define directories for this group
    BASE_DIR="$WORK_DIR/$GROUP"
    FASTQ_DIR="$BASE_DIR/fastq_concat"         # Directory containing FASTQ files
    FLYE_RESULT_DIR="$BASE_DIR/flye_result"    # Directory for Flye output
    MEDAKA_RESULT_DIR="$BASE_DIR/medaka_result"  # Directory for Medaka output

    # Create the Medaka results directory if it does not exist
    mkdir -p "$MEDAKA_RESULT_DIR"

    # Process each barcode directory within the FASTQ directory
    for BARCODE_DIR in "$FASTQ_DIR"/*; do
        # Check if the current item is a directory
        if [ -d "$BARCODE_DIR" ]; then
            process_barcode "$GROUP" "$BARCODE_DIR"  # Call the barcode processing function
        else
            echo "WARNING: $BARCODE_DIR is not a directory. Skipping."
        fi
    done
done

# Record the end time of the script
end_time=$(date +%s)

# Calculate and display the total execution time
total_time=$((end_time - start_time))
minutes=$((total_time / 60))
seconds=$((total_time % 60))

echo "The entire process took $minutes minutes and $seconds seconds to execute." | tee "$WORK_DIR/time.txt"
