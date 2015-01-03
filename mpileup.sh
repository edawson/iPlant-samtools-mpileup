input="mybam.bam"
ref="ref.fa"

if [ -n ${region} ]
then REGION="-r ${region}"
fi

tar xvzf bin.tgz
