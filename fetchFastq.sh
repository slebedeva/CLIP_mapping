#!/bin/bash

mkdir -p logs

#$-cwd #start from current directory
##$ -l m_mem_free=10G
##$-l h_rt=12:0:0 #runtime
#$-V #export all the environmental variables into the context of the job
#$-j yes #merge the stderr with the stdout
#$-o logs/ #stdout, job log
##$-m beas # send email beginning, end, and suspension
##$-M $USER@$HOSTNAME
#$-pe smp 1
#$-l os=centos7,data
#$-N 'fetchFq'


## run like: bash thisscript.sh mysamplesheet (name \t SRR...)

mysamplesheet=$1

mkdir -p raw_data

eval "$($HOME/miniconda3/bin/conda shell.bash hook)"

conda activate CLIP_mapping


while read f1 f2
do
	myname=$f1
	myfastq=$(eval echo $f2)
	fastq-dump --split-files --gzip --outdir "raw_data/$myname" $myfastq

done <"$mysamplesheet"


exit 0
