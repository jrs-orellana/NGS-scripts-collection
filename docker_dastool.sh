#!/bin/bash
start_time=$(date +%s)

# Navigate to the base directory
cd "/media/user/project_name"

DIR_MAXBIN2="$PWD/maxbin2_result"
DIR_METABAT="$PWD/metabat2_result"
DIR_CONCOCT="$PWD/concoct_result"
DIR_MEDAKA="$PWD/flye_result"
DASTOOL_RESULT_DIR="$PWD/dastool_result"

THREADS="20"

# Create 'dastool_result' directory if it doesn't exist
mkdir -p $DASTOOL_RESULT_DIR

# Loop over each barcode directory in the DAS Tool results directory
for barcode_dir in $DIR_CONCOCT/barcode*; do
    barcode_name=$(basename $barcode_dir)

    # Define the specific directories for inputs and outputs
    LOCAL_SAMPLE_DATA_DIR="$DASTOOL_RESULT_DIR/$barcode_name/sample_data"
    LOCAL_FASTA_DIR="$DIR_MEDAKA/$barcode_name"  # Assuming this directory contains .fasta files
    LOCAL_OUTPUT_DIR="$DASTOOL_RESULT_DIR/$barcode_name/sample_output"
    mkdir -p "$LOCAL_OUTPUT_DIR"

    # Run DAS Tool using Docker and ensure output goes to the specified directory
    docker run --rm -it \
      -v "$LOCAL_SAMPLE_DATA_DIR:/sample_data" \
      -v "$LOCAL_FASTA_DIR:/fasta" \
      -v "$LOCAL_OUTPUT_DIR:/output" \
      cmks/das_tool \
      DAS_Tool -i /sample_data/maxbin2.contigs2bin.tsv,/sample_data/concoct.contigs2bin.tsv,/sample_data/metabat2.contigs2bin.tsv \
      --labels maxbin,concoct,metabat \
      -c /fasta/assembly.fasta \
      -o /output/DASToolRun1 \
      --write_bins \
      -t $THREADS

    echo "Processed $barcode_name"
done

echo "DASTOOL processed"
end_time=$(date +%s)
execution_time=$(((end_time - start_time) / 60))  # Convert to minutes
echo "The entire process took $execution_time minutes to execute." > "$DASTOOL_RESULT_DIR/time.txt"
