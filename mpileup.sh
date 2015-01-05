#!/bin/bash
#SBATCH -J test_mpil
#SBATCH -o mpileup_test.o%j
#SBATCH -A iPlant-Collabs
#SBATCH -p normal
#SBATCH -t 4:00:00
#SBATCH -N 1
#SBATCH -n 4

date

## TACC-specific module commands
module unload samtools
module load python
module load launcher

## Variable for input control in SBATCH go here
input=


# SPLIT_COUNT / 4 = number of records per BWA job
SPLIT_COUNT=4000000
# 8 GB
SORT_RAM=8589934592

tar xzf bin.tgz
PATH=$PATH:`pwd`/bin/


qBAM=${input}
qBAMind=${inputIND}
ref=${reference}
output=${output}
numThreads=4


#Make temporary folders for splitting
mkdir input
mkdir temp

## Perform local realignment around indels
## First run RealignmentTargetCreator; this need only be done once
java -Xmx4g -jar ${GATK} \
-T RealignerTargetCreator \
-R ${ref} \
-nt ${numThreads} \
-o ./output.intervals \
${known}

## Cache BAM header for later and split BAM into many sam files.
samtools view -H $qBAM >> bamheader.txt
samtools view $qBAM | split -l $SPLIT_COUNT --numeric-suffixes - input/query

## Add header back to sams and recompress to use with GATK
## Use LaunChair to run in parallel.
for i in ./input/query*
do
  echo "cat bamheader.txt ./input/${i} | samtools view -Sb - > ./input/reheader_${i}.bam" >> jobfile.txt
done

python ./bin/LaunChair/launcher.py -i jobfile.txt

rm -rf paramlist.aln

## Generate paramlist for launcher
# samtools mpileup -A -C50 -E -S -u -f $ref ${i} | \
# bcftools view -cvgb - > ${temp}${region}.raw2.bcf 2> ${temp}${region}.raw2.bcf.log
# ${BCFTOOLS}bcftools view ${temp}${region}.raw2.bcf | ${vcfutils} varFilter -D800 - > ${results}${region}.realigned.flt.vcf

echo "Launcher...."
date
export TACC_LAUNCHER_SCHED=dynamic
EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher
$TACC_LAUNCHER_DIR/paramrun $EXECUTABLE paramlist.aln
date
echo "..Done"


## Merge BAM files back together
echo "Merging sorted BAMs"
OWD=$PWD
cd temp

BAMS=`ls *.sorted.bam`
# Merge and sort
samtools merge ${OWD}/${OUTPUT}.bam ${BAMS} && samtools index ${OWD}/${OUTPUT}.bam
cd $OWD

date
