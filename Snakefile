shell.executable("/bin/bash")
from os import path
from glob import glob
import sys

""" Snakemake pipeline for CLIP data. Original from Neel Mukherjee """ 

configfile: "config_clippipe.yaml"

FA=config["FA"]
GTF=config["GTF"]
SEGE_IDX=config["SEGE_IDX"]

THREE_PRIME_ADAPTER_SEQUENCE=config["THREE_PRIME_ADAPTER_SEQUENCE"]
FIVE_PRIME_ADAPTER_SEQUENCE=config["FIVE_PRIME_ADAPTER_SEQUENCE"]
ICLIP_ADAPTER=config["ICLIP_ADAPTER"]
HITSCLIP_3ADAPTER=config["HITSCLIP_3ADAPTER"]
HITSCLIP_5ADAPTER=config["HITSCLIP_5ADAPTER"]
KIT_5ADAPTER=config["KIT_5ADAPTER"]
NINETEEN_NUCLEOTIDE_MARKER_SEQUENCE=config["NINETEEN_NUCLEOTIDE_MARKER_SEQUENCE"]
TWENTY_FOUR_NUCLEOTIDE_MARKER_SEQUENCE=config["TWENTY_FOUR_NUCLEOTIDE_MARKER_SEQUENCE"]
SPECIAL_AD_1=config["SPECIAL_AD_1"]
SPECIAL_AD_2=config["SPECIAL_AD_2"]
SPECIAL_AD_3=config["SPECIAL_AD_3"]

THREADS = config["THR"] 


## extract sample names 
SAMPLE, = glob_wildcards("raw_data/{sample}_1.fastq.gz")

rule all:
  input:
    expand("{sample}_sege.sorted.bam", sample=SAMPLE),

rule cutadapt:
    input:
      fastq="raw_data/{sample}_1.fastq.gz",
    output:
      fastq="{sample}_trim.fastq.gz",
    shell:
      """
     cutadapt -a {THREE_PRIME_ADAPTER_SEQUENCE} -g {FIVE_PRIME_ADAPTER_SEQUENCE}  \
                -b {NINETEEN_NUCLEOTIDE_MARKER_SEQUENCE} -b {TWENTY_FOUR_NUCLEOTIDE_MARKER_SEQUENCE}  \
                -b {KIT_5ADAPTER} -b {ICLIP_ADAPTER} -b {HITSCLIP_3ADAPTER} -b {HITSCLIP_5ADAPTER}  \
                -b {SPECIAL_AD_1} -b {SPECIAL_AD_2} -b {SPECIAL_AD_3}  \
                -j {THREADS} -n 2 -m 18 -o {output.fastq} {input.fastq} 
      """


rule collapse_reads:
    input:
      fastq="{sample}_trim.fastq.gz",
    output:
      fastq="{sample}_trim_collapsed.fastq.gz",
    shell:
      """
      zcat {input.fastq} | fastx_collapser | gzip > {output.fastq}
      """


rule segemehl_idx:
    input:
      fasta=FA,
    output:
      sege_idx=SEGE_IDX,
    shell:
      """
      segemehl.x -x {output.sege_idx} -d {input.fasta}
      """


rule segemehl:
    input:
      fastq="{sample}_trim_collapsed.fastq.gz",
      sege_idx="hg19.segemehl.idx",
    output:
      sam="{sample}_sege.sam",
    shell:
      """
      segemehl.x -S -D 2 -M 1 --briefcigar -t 4 -i {input.sege_idx} -d {FA} -q {input.fastq}  > {output.sam}
      """


rule sam2bam:
    input:
      sam="{sample}_sege.sam",
    output:
      bam="{sample}_sege.sorted.bam",
      bai = "{sample}_sege.sorted.bam.bai",
    params:
      tmp="{sample}_sege.bam",
    shell:
      """
      samtools view -b {input.sam} > {params.tmp} &&
      samtools sort {params.tmp} -o {output.bam} &&
      samtools index {output.bam}
      """


