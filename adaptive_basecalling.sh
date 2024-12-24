#!/bin/bash

# Script to perform basecalling with Dorado using 2 GPUs

# Define the different models
# Define the different models to optimize basecalling for specific use cases:
# - The HAC model ("High Accuracy") provides higher precision in basecalling, suitable for applications requiring maximum accuracy.
# - The SUP model ("Super Accuracy") offers even greater precision but requires more computational resources, making it ideal for critical analyses or small datasets.

model_hac="/home/user/project_name/models/dna_r10.4.1_e8.2_400bps_hac@v5.0.0"
model_super="/home/user/project_name/models/dna_r10.4.1_e8.2_400bps_sup@v5.0.0"

# Pod5 files
pod5files="/home/user/project_name/AS_OD/"

# Output directories
output_hac="/home/user/project_name/basecalling_AS/hac"
output_super="/home/user/project_name/basecalling_AS/super"

# CSV file for adaptive sampling
csv_file="/home/user/project_name/adaptive_sampling.csv"

THREADS = 30
# Function to perform basecalling, demultiplexing, and trimming
run_basecaller() {
    local model=$1
    local output=$2
    local model_name=$3

    echo "Starting basecalling for model: $model_name"
    start_time=$(date +%s)  # Start time

    # Step 1: Basecalling with Dorado specifying the kit
    dorado basecaller --device cuda:0,1 --models-directory "/home/user/project_name/models" --output-dir $output $model $pod5files --kit-name SQK-KITNAME
        
    end_time=$(date +%s)  # End time for basecalling
    duration=$((end_time - start_time))
    echo "Basecalling with model $model_name completed in $duration seconds."

    # Save runtime in a .txt file in the output folder
    echo "Runtime for model $model_name: $duration seconds" > "$output/time_$model_name.txt"

    # Step 2: Demultiplexing with Dorado
    echo "Starting demultiplexing for model: $model_name"
    dorado demux --output-dir "$output/demux" --no-classify $output/calls_*.bam -t $THREADS

    # Step 3: Rename barcodes
    echo "Renaming barcodes for demultiplexed files: $model_name"
    for barcode_file in $output/demux/*.bam; do
        barcode_name=$(basename "$barcode_file" | sed 's/.*\(barcode[0-9]\{2,3\}\).*/\1/')
        mv "$barcode_file" "$output/demux/${barcode_name}.bam" 
    done
    echo "Renaming completed for model $model_name"

    # Step 3.1: Remove BAM files smaller than 2MB
    echo "Removing BAM files smaller than 2MB for model: $model_name"
    find "$output/demux/" -name "*.bam" -size -2M -delete

    # Step 4: Filter BAMs by channels
    echo "Filtering BAMs by channels for model: $model_name"
    mkdir -p "$output/demux/AS"
    mkdir -p "$output/demux/STANDARD"

    for bam_file in $output/demux/*.bam; do
        echo "Processing file $bam_file"

        # Filter channels 1 to 2000
        samtools view -h "$bam_file" | \
        awk 'BEGIN {OFS="\t"} /^@/ {print; next} {
            ch = -1;
            for(i=12; i<=NF; i++) {
                if($i ~ /^ch:i:/) {
                    split($i, a, ":");
                    ch = a[3];
                    break;
                }
            }
            if(ch >= 1 && ch <= 2000) print
        }' | \
        samtools view -b -o "$output/demux/AS/$(basename "${bam_file%.bam}.bam")" -

        # Filter channels 2001 to 4000
        samtools view -h "$bam_file" | \
        awk 'BEGIN {OFS="\t"} /^@/ {print; next} {
            ch = -1;
            for(i=12; i<=NF; i++) {
                if($i ~ /^ch:i:/) {
                    split($i, a, ":");
                    ch = a[3];
                    break;
                }
            }
            if(ch >= 2001 && ch <= 4000) print
        }' | \
        samtools view -b -o "$output/demux/STANDARD/$(basename "${bam_file%.bam}.bam")" -
    done

    echo "Channel filtering completed for model $model_name"

    # Step 5: Filter reads by decision using the CSV file
    echo "Step 5: Filtering reads by decision for model $model_name"

    # Define variables
    demux_dir="$output/demux/AS"

    # Process the CSV file to extract read_ids
    echo "Extracting read_ids from CSV file..."
    awk -F',' 'NR>1 {if ($7 == "unblock") print $5}' "$csv_file" > "$output/unblock_read_ids.txt"
    awk -F',' 'NR>1 {if ($7 == "stop_receiving") print $5}' "$csv_file" > "$output/stop_receiving_read_ids.txt"

    # Create output directories
    echo "Creating output directories..."
    mkdir -p "$demux_dir/unblock"
    mkdir -p "$demux_dir/stop_receiving"

    # Filter reads for each barcode
    echo "Filtering reads by decision..."
    for bam_file in "$demux_dir/"*.bam; do
        echo "Processing $bam_file"
        barcode_name=$(basename "${bam_file%.bam}")

        # Filter reads with 'unblock' decision
        samtools view -b -N "$output/unblock_read_ids.txt" "$bam_file" -o "$demux_dir/unblock/${barcode_name}.bam"

        # Filter reads with 'stop_receiving' decision
        samtools view -b -N "$output/stop_receiving_read_ids.txt" "$bam_file" -o "$demux_dir/stop_receiving/${barcode_name}.bam"
    done

    # Clean up intermediate files
    echo "Cleaning up intermediate files..."
    rm -r "$output/unblock_read_ids.txt" "$output/stop_receiving_read_ids.txt"
    rm -r "$output/demux/"*.bam

    echo "Filtering by decision completed for model $model_name"

    # Final cleanup: keep only the required directories
    rm -r "$output/tmp" "$output/demux/STANDARD"
    echo "All intermediate files removed for model $model_name"
}

# Execute Dorado with the models and calculate runtime for each
#run_basecaller $model_hac $output_hac "HAC"
run_basecaller $model_super $output_super "SUPER"
