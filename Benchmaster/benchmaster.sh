#!/bin/bash

prepare(){
#This function prepares the environment
monlist=`ceph mon dump|grep ^[0-9]|cut -f2 -d" "|cut -f1 -d":"|paste -s -d ','`
echo $monlist
secretkey=`cat /etc/ceph/ceph.client.admin.keyring |grep key`
shopt -s extglob
secretkey="${secretkey#*=}";
secretkey="${secretkey##*( )}"
secretkey="${secretkey%%*( )}"
shopt -u extglob
#check if loadgens.lst file is present
if [ ! -f /root/loadgens.lst ];then
        echo "You must create the /root/loadgens.lst file for this to work"
        exit
fi
echo "if your load generation nodes don't resolve by name, CTL-C now and fix it."
sleep 5s

echo "First we'll ensure that we have uninhibited access"
sleep 3s
#Check if public key is present
if [ ! -f /root/.ssh/id_rsa.pub ];then
        ssh-keygen
fi
#copy public key to loadgens
for m in `cat /root/loadgens.lst`;do ssh-copy-id -f root@$m;done
echo "if there were any issues above, please CTL-C now and correct them, then re-run the script"
sleep 5s
echo "Creating Pool(s)"
#create pools
#TODO: create EC pool definition that fits in 4 node (3&1?)
ceph osd pool create 3rep-bench 512 512
#create 10 rbds per host of size 40G
echo "Creating RBDs for testing"
for i in `cat /root/loadgens.lst`;do for j in {0..9};do rbd create 3rep-bench/$i-$j --size=40G;done;done
#map the 10 rbs per host
echo "Mapping the RBDs"
for k in `cat /root/loadgens.lst`;do ssh root@$k 'for l in {0..9};do rbd map 3rep-bench/`hostname`-$l;done';done 

#make CephFS pool
#ceph osd pool create cephfs_data 256 256 
#cph osd pool application enable cephfs_data cephfs
#mount cephfs on each node
echo "Mounting cephfs and creating a directory for each loadgen node"
for k in `cat /root/loadgens.lst`
do
	ssh root@$k "mkdir /mnt/cephfs;mount -t ceph $monlist:/ /mnt/cephfs -o name=admin,secret=$secretkey;mkdir /mnt/cephfs/\`hostname\`"
done
}


runjobs(){
#This function runs the jobfiles
jobfiles=`ls jobfiles/*.fio`
loadgens=`cat loadgens.lst`
debug=1
while [[ $rbdresponse != [yYnN] ]];
do
    read -r -p "Do you want to test RBD? [y/N] " rbdresponse
done
while [[ $cephfsresponse != [yYnN] ]];
do
	read -r -p "Do you want to test CephFS? [y/N] " cephfsresponse
done
testlist=""
if [[ $rbdresponse =~ [yY] ]]
then
	testlist="rbd $testlist"
fi
if [[ $cephfsresponse =~ [yY] ]]
then
	testlist="cephfs $testlist"
fi
if [ ! -d results ];then
    mkdir results
fi

echo -n "Describe the Cluster:  "
read cdesc
read -r -p "Do you want to upload the results? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        sendresult=1
        ;;
    *)
        sendresult=0
        ;;
esac
sleep 5s
if [ $debug != 1 ]
then
echo "**** Cluster Description ****">results/cephinfo.txt
echo $cdesc >>results/cephinfo.txt
echo " ">>results/cephinfo.txt

echo "**** Ceph Status ****">>results/cephinfo.txt
ceph status >>results/cephinfo.txt


echo " ">>results/cephinfo.txt
echo "**** OSD Tree ****" >>results/cephinfo.txt
ceph osd tree >>results/cephinfo.txt

echo " ">>results/cephinfo.txt
echo "**** pools ****" >>results/cephinfo.txt
ceph osd lspools >>results/cephinfo.txt

echo " ">>results/cephinfo.txt
echo "**** policy.cfg ****" >>results/cephinfo.txt
cat /srv/pillar/ceph/proposals/policy.cfg >>results/cephinfo.txt

echo " ">>results/cephinfo.txt
echo "**** OSD Info ****" >>results/cephinfo.txt
for j in `cat osdnodes.lst`; do ssh root@$j 'echo "******** HOSTNAME ******";hostname;echo "**********************";echo "******** hwinfo ******";hwinfo --short;echo "******** lsblk ******";lsblk -o name,partlabel,fstype,mountpoint,size,vendor,model,tran,rota' >>results/cephinfo.txt;done
fi
for  test in $testlist
do
	if [ $test == "rbd" ]
	then
		fiotarget="/dev/rbd0:/dev/rbd1:/dev/rbd2:/dev/rbd3:/dev/rbd4:/dev/rbd5:/dev/rbd6:/dev/rbd7:/dev/rbd8:/dev/rbd9"
	fi
	if [ $test == "cephfs" ]
	then
		fiotarget='/mnt/cephfs/${HOSTNAME}/0.fil:/mnt/cephfs/${HOSTNAME}/1.fil:/mnt/cephfs/${HOSTNAME}/2.fil:/mnt/cephfs/${HOSTNAME}/3.fil:/mnt/cephfs/${HOSTNAME}/4.fil:/mnt/cephfs/${HOSTNAME}/5.fil:/mnt/cephfs/${HOSTNAME}/6.fil:/mnt/cephfs/${HOSTNAME}/7.fil:/mnt/cephfs/${HOSTNAME}/8.fil:/mnt/cephfs/${HOSTNAME}/9.fil'
	fi
	for i in $jobfiles
	do
        	i=${i##*/}
		jobname=${i%.*}
		export curjob=$test-$jobname
		echo "*** Running job: $curjob ***"
	  	mkdir results/$curjob
	        sleep 1s
		commandset=""
		command=""
		for l in $loadgens
		do
			#start fio server on each loadgen
			#echo "Killing any running fio on $l and starting fio servers in screen session"
        		ssh root@$l 'killall -9 fio &>/dev/null;killall -9 screen &>/dev/null;sleep 1s;screen -wipe &>/dev/null;screen -S "fioserver" -d -m'
			ssh root@$l "screen -r \"fioserver\" -X stuff $\"export fiotarget=$fiotarget;export curjob=$curjob;fio --server\n\""
			sleep 1s
			commandset=("--client=$l" )
			command+="$commandset jobfiles/$i "
		done
		fio $command --output-format=normal,json+ --output=results/$test-$jobname/$test-$jobname.benchmark
	        echo "Letting system settle for 30s"
	        sleep 30s
	done
done

if [ "$sendresult" == 1 ];then
    shopt -s extglob
    id=`ceph status|grep id|cut -f2 -d":"`
    id="${id##*( )}"
    id="${id%%*( )}"
    shopt -u extglob
    tar -czf $id.tgz results
    python sendit.py $id.tgz
fi
}

#cleanup section
cleanup() {
for i in `cat loadgens.lst`;do ssh root@$i 'for j in `ls /dev/rbd*`;do rbd unmap $j;done;rm -rf /mnt/cephfs/`hostname`;umount /mnt/cephfs;rm -rf /mnt/cephfs';done
ceph tell mon.* injectargs --mon-allow-pool-delete=true  &>/dev/null
ceph osd pool delete 3rep-bench 3rep-bench --yes-i-really-really-mean-it  &>/dev/null
#ceph osd pool delete cephfs_data cephfs_data --yes-i-really-really-mean-it  &>/dev/null
ceph tell mon.* injectargs --mon-allow-pool-delete=false  &>/dev/null
for k in `cat /root/loadgens.lst`
do
        ssh root@$k 'killall fio &>/dev/null;killall screen &>/dev/null'
done
}

usage() {
    echo "Usage: $0 [prepare | dojobs | clean]"
    echo "The script accepts up to 1 parameter to specify a single stage be run"
    echo "No parameters on the command line will result in all stages running"
    echo ""
    echo "   prepare copies ssh keys to the test nodes, creates pools, mounts rbds, mounts cephfs"
    echo ""
    echo "   runjobs will increment over all the .fio files in the jobfiles subdirectory"
    echo ""
    echo "   cleanup tears down the environment"
    exit 1
}

if [ $# -gt 1 ]; then
    usage
fi
if [ $# -eq 1 ]; then
        case "$1" in
            "prepare")
                prepare
                RETVAL=1
            ;;
            "dojobs")
                runjobs
                RETVAL=1
            ;;
            "clean")
                cleanup
                RETVAL=1
            ;;
            *)
                usage
                RETVAL=1
            ;;
        esac
else
    prepare
    runjobs
    cleanup
fi
exit $RETVAL

