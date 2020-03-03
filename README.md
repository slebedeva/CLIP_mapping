# CLIP_mapping

This is the pipeline I use to quickly map CLIP data. Modified from rnaroids pipeline (Neel Mukherjee) with tips from Philipp Boss (author of omniCLIP).

This pipeline is desinged to work with SUN Grid engine. (Or can be run locally on a machine with at least 80G memory).

This pipeline maps single end CLIP data to hg19. If the sequencing is paired-end (as in eCLIP), it will only take read1.

This pipeline uses snakemake (Köster 2012, https://academic.oup.com/bioinformatics/article/28/19/2520/290322). `Snakefile` is the main pipeline file. Config file `config_clippipe.yaml` lists variables that Snakefile needs (genome, annotation, adapter sequences, number of threads). Config file `cluster_config.json` regulates memory and other requirements when submitting jobs to the cluster. The bash script `snakecharmer.sh` is used to submit snakemake job to the cluster.


### Preparation

###### Get the genome and annotation from Gencode and unzip it

```
wget ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_19/GRCh37.p13.genome.fa.gz
wget ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_19/gencode.v19.annotation.gtf.gz
```

###### Install miniconda and install the environment

Download the respective file from miniconda depending on your system (https://docs.conda.io/en/latest/miniconda.html).
Follow installation instructions.

For example, for Linux, do:

```
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
eval "$($HOME/miniconda3/bin/conda shell.bash hook)"
## create environment for CLIP mapping
conda create --name CLIP_mapping --file CLIP_mapping_conda_env.txt
conda activate CLIP_mapping
```

###### Get CLIP data

I use a small fastq fetching script for files from NCBI SRA, especially handy if there are many CLIP files from different RBPs. 
Make a sample sheet that looks like:
```
RBP1	SRR100{1..3}
RBP2	SRR100{4..5}
```
Run the script:
```
bash fetchFastq.sh example_sample_sheet
```
It should create directories "RBP1", "RBP2" etc. and put fastq files inside. In the example case, there should be 1 directory "ELAVL1" with 3 fastq files.

Note: I use --split-files by default to be able to always use the same script whether it is single end, paired end or has barcode read. Snakemake will always take read 1, and search for input files which look like *_1.fastq.gz. To use own fastq files, please add _1 to the file base name.

### Run the pipeline

To check that everything OK, try snakemake dry run:
```
snakemake -nrp
```
It should give you wildcards for sample names, all rules that will be executed and output files.
Then run the pipeline:

- on a cluster `qsub snakecharmer.sh` or `bash snakecharmer.sh`
- without cluster `bash snakecharmer.sh` or `snakemake`

If you are on the cluster, you might change "account" in cluster_config.json to your email address: you will get an email when the job is done, or aborted.

If you are not on the cluster, keep in mind that it may need quite some memory. Segemehl index for hg19 requires at least 64G and alignment usually takes ~75G.

###### Changing parameters

For small RNAs, mapping parameters could be a source of debate :-) Depending on library quality, one might want to make them more strict or more relaxed. This pipeline is trying to be very universal and find a compromise between many variants of CLIP data. Several things can be adjusted:
- cutadapt -m 18 : this removes all reads shorter than 18nt, because it is progressively more difficult to map shorter reads. If one still might want to try and include those, change this number to 16, for example. 
- I try to include all possible small RNA adapters used. Of course, if you know exact adapter sequences for the sample (not always easy to find out in GEO!) you might want to add them to cutadapt rule, if they are not listed yet in the config file.
- Deduplication: since I assume an old CLIP without UMIs, I do simple read collapsing. If one has UMIs, it is better to use UMI-tools(https://github.com/CGATOxford/UMI-tools) to deduplicate reads.
- Mapping: I use segemehl (Hoffmann 2009, PMID: 19750212) because it especially well captures deletions which can be used as diagnostic events (Kassuhn 2016, PMID:26776207). segemehl parameters -M -D and -S
	- -S regulates split alignments. It can be removed if you presume the RBP doesn't bind pre-mRNAs since it makes bam files much larger in size. -S option generated three additional segemehl output files (which for now cannot be redirected to output directory): trns.txt, sngl.bed, mult.bed
	- -D 2 : allows mismatches in seeds, especially helpful with 4SU and 6SG based CLIP if we expect >1 T>C or G>A conversions next to each other
	- -M 1 : controls the number of multiple hits. I only take unique hits, but up to -M 3 may give you additional usable reads

###### Calling peaks (not included in the pipeline)

This pipeline is optimized to be followed by the omniCLIP peak caller (Drewe-Boss 2018, https://github.com/philippdre/omniCLIP) which needs at least 2 replicates of CLIP and an input/background sample to call peaks against. I prefer to use RNA-seq data in the same cell line as background (1 replicate is enough).
