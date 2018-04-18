#!/bin/bash
debug=1
#debug doesn't collect system info.

infogather(){
allocdiv=0
ramptime=30
runtime=750
#This function sets up the environment
#Start by gathering information

#check if loadgens.lst file is present
if [ ! -f loadgens.lst ];then
        echo "!! You must create the loadgens.lst file for this to work"
        exit
fi

while [[ $rbdresponse != [yYnN] ]];
do
    read -r -p "Do you want to test RBD? [y/N] " rbdresponse
done

while [[ $cephfsresponse != [yYnN] ]];
do
	read -r -p "Do you want to test CephFS? [y/N] " cephfsresponse
done

#while [[ $s3response != [yYnN] ]];
#do
#        read -r -p "Do you want to test S3? [y/N] " s3response
#done


while [[ $isaresponse != [yYnN] ]];
do
	read -r -p "Do you want to use the ISA plugin for Erasure Coding? [y/N] " isaresponse
done

if [[ $isaresponse =~ [yY] ]]
then
	ecplugin="isa"
else
        ecplugin="jerasure"
fi

testlist=""
if [[ $rbdresponse =~ [yY] ]]
then
	testlist="rbd ecrbd $testlist"
        allocdiv=$[allocdiv+5]
        
fi

if [[ $cephfsresponse =~ [yY] ]]
then
	testlist="cephfs eccephfs $testlist"
        allocdiv=$[allocdiv+5]

fi
if [[ "$s3response" =~ [yY] ]]
then
	testlist="s3 $testlist"
        allocdiv=$[allocdiv+2]

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
echo ""
echo ""

#make the results directory
if [ ! -d results ];then
    mkdir results
fi

#This function prepares the environment
#Get a list of the monitor hosts IP addresses.  Needed for CephFS mounting
monlist=`ceph mon dump|grep ^[0-9]|cut -f2 -d" "|cut -f1 -d":"|paste -s -d ','`
#Get the secret key from the ceph.client.admin.keyring file for CephFS mounting
secretkey=`cat /etc/ceph/ceph.client.admin.keyring |grep key`
shopt -s extglob
secretkey="${secretkey#*=}";
secretkey="${secretkey##*( )}"
secretkey="${secretkey%%*( )}"
shopt -u extglob

#Get ceph free space and calculate base allocation unit size (alloc_size)
# given pools for the tests selected.  RBD & CephFS have both EC & Replicated, 
# RGW has one EC 
# Replicated pools get 3 allocation units
# EC pools get 2 allocation units as the EC scheme is k=2,m=2
# RBD images will be (# of allocation units)* alloc_size/nodecount * 10
rawavail=`ceph osd df |grep TOTAL|xargs|cut -f4 -d" "`
rawlen=${#rawavail}
rawunit=${rawavail:(-1)}
rawspace=${rawavail:0:($rawlen-1)}
echo rawspace=$rawspace
echo rawunit=$rawunit

#if rbd & cephfs & s3
if [ $rawunit == "T" ];then
    spacemultiplier=1000
elif [ $rawunit == "G" ];then
    spacemultiplier=1
elif [ $rawunit == "P" ];then
    spacemultiplier=1000000
fi

loadgencnt=`cat loadgens.lst|xargs|awk -F" " '{print NF}'`
allocunit=$[(rawspace * spacemultiplier)/allocdiv]
if [ $allocunit -gt $[1500*loadgencnt] ];then
    allocunit=$[1500*loadgencnt]
fi
echo allocunit=$allocunit
rbdimgsize=$[allocunit/(loadgencnt*10)]
fsize=`echo "scale=0; $rbdimgsize * .9" | bc`
filesize=${fsize%.*}




}

prepare(){
#check name resolution for loadgens
for m in `cat loadgens.lst`
do
    if ! host $m &>/dev/null;then
        echo "!! Host $m does not resolve to an IP.  Please fix and re-run"
        exit
    fi
done

echo "** First we'll ensure that we have uninhibited access"
#Check if public key is present
if [ ! -f ~/.ssh/id_rsa.pub ];then
        echo "** Need to generate rsa keypair for this host"
        ssh-keygen -N "" -f ~/.ssh/id_rsa
fi

#copy public key to loadgens

for m in `cat loadgens.lst`
do
    echo "** Now copying public key to $m."
    echo "   You'll be prompted for the root password on that host."
    ssh-copy-id -oStrictHostKeyChecking=no -f ~/.ssh/id_rsa.pub root@$m &>/dev/null
done

for m in `cat loadgens.lst`
do 
    ssh root@$m 'exit'
    if [ $? -ne 0 ]
    then
        echo "SSH to $m seems not to be working.  Please correct and re-run"
        echo "the script."
        exit
    fi
done
} 
prepare() {
echo "** Ensuring fio is installed"
if [ ! `command -v fio` ];then echo "** Installing fio on $HOSTNAME";zypper -q in -y fio &>/dev/null;fi
for m in `cat loadgens.lst`
do
    ssh root@$m 'if [ ! `command -v fio` ];then echo "** Installing fio on $HOSTNAME";zypper -q in -y fio &>/dev/null;fi'
done

echo "** Copying /etc/ceph directory to test nodes"
for m in `cat loadgens.lst`
do
    ssh root@$m 'mkdir -p /etc/ceph'
    scp -r /etc/ceph/* root@$m:/etc/ceph/
done
echo ""


echo "** Creating Pool(s)"

#create pools
#TODO: create EC pool definition that fits in 4 node (3&1?)
#TODO: look at size of ceph and create pools and images of appropriate size (no more than 150GB per image)
#      and set environment variables for filesize used in .fio files

#create a pool of size 3 for initial benchmarks
ceph osd pool create 3rep-bench 512 512

#create 10 rbds per host of the size set in rbdimgesize
echo "Creating RBDs for testing"
for i in `cat loadgens.lst`;do for j in {0..9};do rbd create 3rep-bench/$i-$j --size=${rbdimgsize}G;done;done

#map the 10 replicated rbds per host
echo "Mapping the Replicated RBDs"
for k in `cat loadgens.lst`;do ssh root@$k 'for l in {0..9};do rbd map 3rep-bench/`hostname`-$l;done';done 

#make EC RBD pool and mount it
ceph osd erasure-code-profile set ecbench plugin=$ecplugin k=3 m=1
ceph osd pool create ecrbdbench 128 128 erasure ecbench
ceph osd pool set ecrbdbench allow_ec_overwrites true
ceph osd pool application enable ecrbdbench rbd

#create rbd images for ecrbd
for i in `cat loadgens.lst`;do for j in {0..9};do rbd create --size=${rbdimgsize}G --data-pool ecrbdbench 3rep-bench/ec$i-$j;done;done

#map the 10 ec rbds per host
echo "Mapping the EC RBDs"
for k in `cat loadgens.lst`;do ssh root@$k 'for l in {0..9};do rbd map 3rep-bench/ec`hostname`-$l;done';done 

#create EC CephFS pool and mount it
ceph osd pool create eccephfsbench 128 128 erasure ecbench
ceph osd pool set eccephfsbench allow_ec_overwrites true
ceph osd pool application enable eccephfsbench cephfs
ceph fs add_data_pool cephfs eccephfsbench

#mount cephfs on each node
echo "Mounting cephfs and creating a directory for each loadgen node"
for k in `cat loadgens.lst`
do
	ssh root@$k "mkdir /mnt/cephfs;mount -t ceph $monlist:/ /mnt/cephfs -o name=admin,secret=$secretkey;mkdir /mnt/cephfs/\`hostname\`"
        ssh root@$k "mkdir -p /mnt/cephfs/ec;setfattr -n ceph.dir.layout -v eccephfsbench /mnt/cephfs/ec;mkdir /mnt/cephfs/ec/\`hostname\`"
done

}


runjobs(){

#This function runs the jobfiles
jobfiles=`ls jobfiles/*.fio`
loadgens=`cat loadgens.lst`


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
	if [ $test == "ecrbd" ]
	then
		fiotarget="/dev/rbd10:/dev/rbd11:/dev/rbd12:/dev/rbd13:/dev/rbd14:/dev/rbd15:/dev/rbd16:/dev/rbd17:/dev/rbd18:/dev/rbd19"
	fi
	if [ $test == "cephfs" ]
	then
		fiotarget='/mnt/cephfs/${HOSTNAME}/0.fil:/mnt/cephfs/${HOSTNAME}/1.fil:/mnt/cephfs/${HOSTNAME}/2.fil:/mnt/cephfs/${HOSTNAME}/3.fil:/mnt/cephfs/${HOSTNAME}/4.fil:/mnt/cephfs/${HOSTNAME}/5.fil:/mnt/cephfs/${HOSTNAME}/6.fil:/mnt/cephfs/${HOSTNAME}/7.fil:/mnt/cephfs/${HOSTNAME}/8.fil:/mnt/cephfs/${HOSTNAME}/9.fil'
	fi

	if [ $test == "eccephfs" ]
	then
		fiotarget='/mnt/cephfs/ec/${HOSTNAME}/0.fil:/mnt/cephfs/ec/${HOSTNAME}/1.fil:/mnt/cephfs/ec/${HOSTNAME}/2.fil:/mnt/cephfs/ec/${HOSTNAME}/3.fil:/mnt/cephfs/ec/${HOSTNAME}/4.fil:/mnt/cephfs/ec/${HOSTNAME}/5.fil:/mnt/cephfs/ec/${HOSTNAME}/6.fil:/mnt/cephfs/ec/${HOSTNAME}/7.fil:/mnt/cephfs/ec/${HOSTNAME}/8.fil:/mnt/cephfs/ec/${HOSTNAME}/9.fil'
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
			ssh root@$l "screen -r \"fioserver\" -X stuff $\"export curjob=$curjob;export ramptime=$ramptime;export runtime=$runtime;export filesize=${filesize}G;export fiotarget=$fiotarget;export curjob=$curjob;fio --server\n\""
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
for i in `cat loadgens.lst`;do ssh root@$i 'for j in `ls /dev/rbd*`;do rbd unmap $j;done;rm -rf /mnt/cephfs/ec/*;rm -rf /mnt/cephfs/`hostname`;umount /mnt/cephfs;rm -rf /mnt/cephfs';done
ceph tell mon.* injectargs --mon-allow-pool-delete=true  &>/dev/null
ceph osd pool delete 3rep-bench 3rep-bench --yes-i-really-really-mean-it  &>/dev/null
ceph osd pool delete ecrbdbench ecrbdbench --yes-i-really-really-mean-it  &>/dev/null
ceph fs rm_data_pool cephfs eccephfsbench
ceph osd pool delete eccephfsbench eccephfsbench --yes-i-really-really-mean-it  &>/dev/null
ceph tell mon.* injectargs --mon-allow-pool-delete=false  &>/dev/null
ceph osd erasure-code-profile rm ecbench
for k in `cat loadgens.lst`
do
        ssh root@$k 'killall fio &>/dev/null;killall screen &>/dev/null'
done
}

usage() {
    echo "Usage: $0 [prepare | clean]"
    echo "The script accepts up to 1 parameter to specify a single stage be run"
    echo "No parameters on the command line will result in all stages running"
    echo ""
    echo "   prepare copies ssh keys to the test nodes, creates pools, mounts rbds, mounts cephfs"
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
            "infogather")
                infogather
                RETVAL=1
            ;;
            *)
                usage
                RETVAL=1
            ;;
        esac
else
    infogather
    prepare
    runjobs
    cleanup
fi
exit $RETVAL

