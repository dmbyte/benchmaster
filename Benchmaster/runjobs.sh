#!/bin/bash
jobfiles=`ls jobfiles`
loadgens=`cat loadgens.lst`
for i in $jobfiles
do
	jobname=${i%.*}
	echo "Running job: $jobname"
        mkdir results
	mkdir results/$jobname
        sleep 1s
	commandset=""
	command=""
	for l in $loadgens
	do
		commandset=("--client=$l" )
		command+="$commandset jobfiles/$i "
	done
	fio $command --output-format=normal,json+ --output=jobfiles/$jobname/$jobname.benchmark
        echo "Letting system settle for 30s"
        sleep 30s
done
ceph status >results/cephinfo.txt
ceph osd tree >>results/cephinfo.txt