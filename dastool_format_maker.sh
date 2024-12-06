#!/bin/bash

# Activate the Conda environment for DAS Tool
source $(conda info --base)/etc/profile.d/conda.sh
conda activate dastool

# Navigate to the base directory
cd "/media/user/project"

DIR_MAXBIN2="$PWD/maxbin2_result"
DIR_METABAT="$PWD/metabat2_result"
DIR_CONCOCT="$PWD/concoct_result"

THREADS="20"

# Create 'dastool_result' directory if it doesn't exist
mkdir -p dastool_result

# Iterate over each barcode directory for the results in 'maxbin2_result'
for barcode_dir in $DIR_MAXBIN2/barcode*; do
    barcode_name=$(basename $barcode_dir)
    
    # Create directory structure for this barcode in dastool_result
    sample_data="dastool_result/$barcode_name/sample_data"
    mkdir -p $sample_data

    # Convert fasta bins to contigs2bin format
    Fasta_to_Contig2Bin.sh -i $barcode_dir -e fasta > $sample_data/maxbin2.contigs2bin.tsv
    echo "Processed $barcode_name in maxbin2_result"
done

# Process metabat2 results
for barcode_dir in $DIR_METABAT/barcode*; do
    barcode_name=$(basename $barcode_dir)
    
    sample_data="dastool_result/$barcode_name/sample_data"
    mkdir -p $sample_data
    
    # Convert fasta bins to contigs2bin format
    Fasta_to_Contig2Bin.sh -i $barcode_dir/*/ -e fa > $sample_data/metabat2.contigs2bin.tsv
    echo "Processed $barcode_name in metabat2_result"
done

# Process concoct results
for barcode_dir in $DIR_CONCOCT/barcode*; do
    barcode_name=$(basename $barcode_dir)
    
    sample_data="dastool_result/$barcode_name/sample_data"
    mkdir -p $sample_data

    # Convert CSV output to TSV format for concoct
    perl -pe "s/,/\tconcoct./g;" $DIR_CONCOCT/$barcode_name/concoct_output/clustering_gt1000.csv > $sample_data/concoct.contigs2bin.tsv
    
done

# Preprocess concoct contig2bin files
for file in dastool_result/*/sample_data/concoct.contigs2bin.tsv; do
    sed -i '1d' "$file"
    sed -i 's/\.concoct_part_[0-9]*\t/\t/' "$file"
    echo "Processed $barcode_name in concoct_result"
done

# # Final processing step for each barcode
# for barcode_dir in dastool_result/barcode*; do
#     barcode_name=$(basename $barcode_dir)
    
#     sample_output="dastool_result/$barcode_name/sample_output"
#     mkdir -p $sample_output

#     # Run DAS Tool
#     DAS_Tool -i dastool_result/$barcode_name/sample_data/maxbin2.contigs2bin.tsv,dastool_result/$barcode_name/sample_data/concoct.contigs2bin.tsv,dastool_result/$barcode_name/sample_data/metabat2.contigs2bin.tsv \
#     --labels maxbin,concoct,metabat \
#     -c medaka_result/$barcode_name/*.fasta \
#     -o $sample_output/DASToolRun1 \
#     --write_bins \
#     -t $THREADS
    
#     echo "Processed $barcode_name in DAS Tool"
# done

conda deactivate
echo "DASTOOL processing completed"
