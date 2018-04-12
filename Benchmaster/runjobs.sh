#!/bin/bash
jobfiles=`ls jobfiles/*.fio`
loadgens=`cat loadgens.lst`
if [ ! -d results ];then
    mkdir results
fi

echo -n "Describe the Cluster:  "
read cdesc
echo "**** Cluster Description ****">results/cephinfo.txt
echo $cdesc >>results/cephinfo.txt
echo " ">>results/cephinfo.txt

echo "**** Ceph Status ****">>results/cephinfo.txt
ceph status >>results/cephinfo.txt

read -r -p "Do you want to upload the results? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
        sendresult=1
        ;;
    *)
        sendresult=0
        ;;
esac

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

for i in $jobfiles
do
        i=${i##*/}
	jobname=${i%.*}
	echo "Running job: $jobname"
  	mkdir results/$jobname
        sleep 1s
	commandset=""
	command=""
	for l in $loadgens
	do
		commandset=("--client=$l" )
		command+="$commandset jobfiles/$i "
	done
	fio $command --output-format=normal,json+ --output=results/$jobname/$jobname.benchmark
        echo "Letting system settle for 30s"
        sleep 30s
done

if [ $sendresult == 1 ];then
    shopt -s extglob
    id=`ceph status|grep id|cut -f2 -d":"`
    id="${id##*( )}"
    id="${id%%*( )}"
    shopt -u extglob
    tar -czf $id.tgz results
    python sendit.py $id
fi

