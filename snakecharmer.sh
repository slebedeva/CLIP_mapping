#!/bin/bash

## run this script on a qrsh session, not on the head node
## this will submit cluster qsub jobs and monitor them
## You can also qsub snakecharmer.sh to get logs from this

#$ -cwd
#$ -V
#$ -j yes
#$ -o logs/
#$ -N "snake"
#$ -l data 

mkdir -p logs && ##need access to /data to create this dir

## activate conda environment
eval "$($HOME/miniconda3/bin/conda shell.bash hook)" &&
conda activate CLIP_mapping &&

echo "############################### START PIPELINE #############################"
echo $(date)

snakemake --unlock && ##necessary because a lot of killed snakes

snakemake --jobs 12 --cluster-config cluster_config.json --cluster "qsub -cwd -V -j yes -o {cluster.err} -m {cluster.m} -M {cluster.account} -pe smp {cluster.n} -l h_vmem={cluster.h_vmem} -l h_rt={cluster.time} -N {cluster.name} -l data" --snakefile Snakefile --latency-wait 600 --rerun-incomplete --configfile config_clippipe.yaml

exit 0
