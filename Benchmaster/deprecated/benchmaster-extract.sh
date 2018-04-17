#!/bin/bash
for i in `ls $1/*.out`
do
	notpre=1
	unset IFS
	file=$i
        IFS="." 
	#cleanup filename for field count
        dropperiod=${i%.*}
	droppath=${dropperiod##*/}
        fieldcount=`echo $droppath | awk -F"-" '{print NF}'`
	echo "fieldcount: $fieldcount"
	IFS="-"
        while IFS='-' read -ra fieldvals; do
		writeper=${fieldvals[$((fieldcount-1))]}
		#Make sure this isn't a pre-conditioning run
		if [ $writeper == "pre" ]
		then
			notpre=0
		else
			#Get blocksize and iotype from the filename
			blocksize=${fieldvals[$((fieldcount-4))]}
			iotype=${fieldvals[0]}
			if [ $writeper -eq 100 ]
			then
				rw=Read
			else
				rw=Write
			fi
			testrun="$iotype $blocksize $rw"
		fi
        	done <<<"$droppath"
	if [ $notpre -eq 1 ]
	then
		unset IFS
		#get latency info from the lat: line of output
		latencyraw=`head $file |grep -v slat |grep -v clat|grep -v rbd|grep lat|cut -f1,3 -d","`
		# what units are in use by the latency measurement? usec or msec?
		latencyunit=`echo $latencyraw|cut -f2 -d" "|cut -f1 -d":"`
		latencymetric=`echo $latencyraw|cut -f3 -d"="`
		# Get IOPS from the output
		# TODO: cleanup with output is appended with k
		iopsraw=`head $file|grep IOPS|cut -f2 -d"="|cut -f1 -d","`
		#Get bandwidth from the output
		bwraw=`grep "bw=" $file|cut -f2 -d"="|cut -f1 -d","`
		#Convert all BW to MiB
		bwref1=${bwraw%(*}
		if [[ $bwref1 == *"KiB"* ]]
		then
			divis=1024
		else
			divis=1
		fi 
		bwref2=${bwref1:0:${#bwref1}-6}
		bwref3=$(bc <<<"scale=2 ; $bwref2 / $divis")
		echo \"$testrun BW \(MiB/s\)\",\"$bwref3\"
		echo \"$testrun IOPS\",\"$iopsraw\"
		if [[ $latencyunit == *"usec"* ]]
		then
			latencyfinal=$(bc<<< "scale=2 ; $latencymetric / 1000")
		else
			latencyfinal=$latencymetric
		fi
		echo \"$testrun Latency \(ms\)\",\"$latencyfinal\" 
	fi
done