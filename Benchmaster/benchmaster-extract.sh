#!/bin/bash
for i in `ls $1/*.out`
do
	notpre=1
	unset IFS
	file=$i
	#echo FILENAME=$file
        IFS="." 
        dropperiod=${i%.*}
	droppath=${dropperiod##*/}
	#echo $droppath
        fieldcount=`echo $droppath | awk -F"-" '{print NF}'`
	IFS="-"
        while IFS='-' read -ra fieldvals; do
		writeper=${fieldvals[$((fieldcount-1))]}
		if [ $writeper == "pre" ]
		then
			notpre=0
		else
			blocksize=${fieldvals[$((fieldcount-4))]}
			iotype=${fieldvals[$((fieldcount-7))]}
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
		latencyraw=`head $file |grep -v slat |grep -v clat|grep -v rbd|grep lat|cut -f1,3 -d","`
		#echo $latencyraw
		latencyunit=`echo $latencyraw|cut -f2 -d" "|cut -f1 -d":"`
		latencymetric=`echo $latencyraw|cut -f3 -d"="`
		iopsraw=`head $file|grep IOPS|cut -f2 -d"="|cut -f1 -d","`
		bwraw=`grep "bw=" $file|cut -f2 -d"="|cut -f1 -d","`
		bwref1=${bwraw%(*}
		if [[ $bwref1 == *"KiB"* ]]
		then
			divis=1000
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
