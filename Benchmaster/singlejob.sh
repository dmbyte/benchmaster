#!/bin/bash
jobfiles=`ls jobfiles/*.fio`
echo "Here are the available jobfiles"
for j in $jobfiles
do
    echo "  $j"
done
read -r -p "Which jobfile do you wish to run?" jobfile
read -r -p "What is the path to the test file (/dev/rbd0, /mnt/cephfs/test.fil, etc seperate multiples with colons.)? " filename
read -r -p "What size is the test file you want to use in GB? (Numeric portion only) " filesize
read -r -p "What is the time in seconds to allow the job to ramp up?" ramptime
read -r -p "What is the time in seconds for the job to run?" runtime
export filesize=${filesize}G
export fiotarget=$filename
export ramptime=$ramptime
export runtime=$runtime
myjob=${jobfile##*/}
jobname=${i%.*}
if [ ! -d results ];then
    mkdir -p results
fi
if [ ! -d results/$jobname ]; then
    mkdir -p results/$jobname
fi
fio $jobfile 