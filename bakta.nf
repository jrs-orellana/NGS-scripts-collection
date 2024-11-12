#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.medakaDir = "/home/user/project/results/medaka" 
params.bakta = "/media/user/databases/bakta" 

process Bakta {
    conda '/home/user/anaconda3/envs/bakta'
    publishDir '/home/user/project/results/bakta'
    cpus 10
    maxForks 3

    input:
    tuple val(barcode), path(query_file)

    output:
    path "$barcode"

    script:
    """
    mkdir -p ${barcode}
    bakta --db $params.bakta --output $barcode -t $task.cpus --force "${query_file}"
    """
}

workflow {
    channel_fastq = Channel
        .fromPath("$params.medakaDir/barcode*/consensus.fasta")
        .map { file -> 
            def barcode = file.getParent().getName() // Extract the barcode from the parent directory
            tuple(barcode, file)
        }

    //channel_fastq.view()
    // Uncomment the line below to run the process
    Bakta(channel_fastq)
}
