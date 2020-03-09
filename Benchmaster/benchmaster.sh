#!/bin/bash
debug=0
#debug doesn't collect system info.

infogather() {
    allocdiv=0
    ramptime=600
    runtime=1800

    #Validate environment and general details
    #check if loadgens.lst and osdnodes.lst files are present
    for file in loadgens.lst osdnodes.lst; do
        if [ ! -f $file ];then
            echo "!! You must create the $file file for this to work."
            echo "   The file should contain a list of all the ${file%%s.osd} nodes"
            echo "   with one per line."
            exit
        fi
    done
    #make the results directory
    if [ ! -d results ];then
        mkdir -p results
    fi
    #get description and prompt for upload
    echo " ----  Starting Benchmaster  ----"
    echo -n "Describe the cluster/test:  "
    read cdesc
    read -r -p "Do you want to upload the results? (Y/[N]) " response
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

    #Determine tests to be run
    echo " ----  Select Tests  ----"
    testlist=""
    # Check EC test first
    read -r -p "Do you want to test Erasure Coding (Y/[N]) " testecresponse
    case $testecresponse in
        Y|y)
            testecresponse="Y"
            read -r -p "Do you want to use the ISA plugin for Erasure Coding (Y/[N]) " isaresponse
            case $isaresponse in
                Y|y)
                    isaresponse="Y"
                    ecplugin="isa"
                    ;;
                *)
                    isaresponse="N"
                    ecplugin="jerasure"
                    ;;
            esac
            ;;
        *)
            testecresponse="N"
            isaresponse="N"
            ;;
    esac
    read -r -p "Do you want to test RBD? (Y/[N]) " rbdresponse
    case $rbdresponse in
        Y|y)
                rbdresponse="Y"
                if [[ $testecresponse = "Y" ]]; then
                    testlist="rep-rbd ec-rbd $testlist"
                    allocdiv=$[allocdiv+5]
                else
                    testlist="rep-rbd $testlist"
                    allocdiv=$[allocdiv+3]
                fi
                ;;
        *)
               rbdresponse="N"
                ;;
    esac
    read -r -p "Do you want to test CephFS (Y/[N]) " cephfsresponse
    case $cephfsresponse in
        Y|y)
               cephfsresponse="Y"
                if [[ $testecresponse = "Y" ]]; then
                    testlist="rep-cephfs ec-cephfs $testlist"
                    allocdiv=$[allocdiv+5]
                else
                    testlist="rep-cephfs $testlist"
                    allocdiv=$[allocdiv+3]
                fi
                ;;
        *)
               cephfsresponse="N"
                ;;
    esac
    #read -r -p "Do you want to test S3 (Y/[N]) " s3response
    #case $s3sresponse in
    #    Y|y)
    #           s3sresponse="Y"
    #       testlist="s3 $testlist"
    #           allocdiv=$[allocdiv+3]
    #           ;;
    #    *)
    #           s3sresponse="Y"
    #           ;;
    #esac
    echo

    #Gather test information
    echo " ----  Build Test Parameters  ----"
    #Determine the number of device classes
    dclasslist=`ceph osd crush class ls -f json|tr -d '[]"'`
    dclasses=${dclasslist//,/ }
    howmany() { echo $#; }
    classcount=`howmany $dclasses`
    ctemp=1
    for i in $dclasses
    do
        echo "$ctemp: $i"
        dlist[$ctemp]=$i
        let "ctemp=ctemp+1"
    done
    inputs=`seq 1 $classcount|xargs`
    while [[ $deviceclassresponse != [$inputs] ]];
    do
        read -r -p "Pick the class of device to test against [1 - $classcount]" deviceclassresponse
    done
    # echo "selected device is ${dlist[$deviceclassresponse]}"

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
    # allocdiv represents the number of allocation units the required tests will
    # need. It is basically the divisor for usable space from the raw space.
    #e.g. rbd on ec and replication needs 5 units.
    # RBD images will be (# of allocation units)* alloc_size/nodecount * 10
    #rawavail=`ceph osd df -f json | jq .summary.total_kb_avail`
    rawavail=0
    mydclass=${dlist[$deviceclassresponse]}
    for i in `ceph osd df -f json | jq '.nodes[] |select (.device_class == "'$mydclass'")'|jq '.kb_avail'`
    do
        rawavail=$((rawavail + $i))
    done
    echo rawavail=$rawavail
    rawlen=${#rawavail}
    rawspace=${rawavail}
    echo rawspace=$rawspace
    echo rawunit=mb
    echo allocdiv=$allocdiv
    loadgencnt=`cat loadgens.lst|xargs|awk -F" " '{print NF}'`
    allocunit=$((rawspace / 1024 / 1024 / loadgencnt ))
    echo firstallocunit=$allocunit
    if [ $allocunit -gt $[1500 * $allocdiv] ];then
        allocunit=$[1500 * $allocdiv]
    fi
    echo allocunit=$allocunit GB
    rbdimgsize=`echo "scale=0; $allocunit/($allocdiv*10)* .7"|bc`
    rbdimgsize=${rbdimgsize%.*}
    #rbdimgsize=$[allocunit/(allocdiv*10)]
    echo rbdimgsize=$rbdimgsize GB
    fsize=$rbdimgsize
    filesize=${fsize%.*}
    echo fsize=$fsize GB
    echo " ----  Finished Gathering Information  ----"
    echo
}

prepare() {
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
        ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root@$m &>/dev/null
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

    echo "** Ensuring ceph-common is installed"
    for m in `cat loadgens.lst`
    do
        ssh root@$m 'if [ ! `command -v rbd` ];then echo "** Installing ceph-common on $HOSTNAME";zypper -q in -y ceph-common &>/dev/null;fi'
    done

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
    countdevinclass=`ceph osd tree |grep $mydclass|wc -l`
    testpower=0
    powertwo=0
    until [ "$powertwo" -ge $((countdevinclass*50)) ];do
        powertwo=$((2**testpower))
        testpower=$((testpower+1))
    done
    powertwo=$((powertwo/2))
    echo "DETERMINED PG Count to be $powertwo"

    # These are needed whether EC/or otherwise
    ceph osd crush rule create-replicated $mydclass default host $mydclass
    ceph osd pool create 3rep-bench $powertwo $powertwo replicated $mydclass
    ceph osd pool application enable 3rep-bench rbd
    ceph osd erasure-code-profile set ecbench plugin=$ecplugin k=3 m=1 crush-device-class=$mydclass

    if [[ $rbdresponse =~ [yY] ]]
    then
        #create a pool of size 3 for initial benchmarks
        ceph osd crush rule create-replicated $mydclass default host $mydclass
        ceph osd pool create 3rep-bench $powertwo $powertwo replicated $mydclass
        ceph osd pool application enable 3rep-bench rbd
        echo settling the system for 30 seconds
        sleep 30s
        #create 10 rbds per host of the size set in rbdimgesize
        echo "Creating RBDs for testing"
        for i in `cat loadgens.lst`
        do
            for j in {0..9}
            do
                echo "rbd create 3rep-bench/$i-$j --size=${rbdimgsize}G"
                rbd create 3rep-bench/$i-$j --size=${rbdimgsize}G
            done
        done

        #map the 10 replicated rbds per host
        echo "Mapping the Replicated RBDs"
        for k in `cat loadgens.lst`;do ssh root@$k "for l in {0..9};do rbd map 3rep-bench/$k-\$l;done";done

        if [[ $testecresponse =~ [yY] ]]
        then
            #make EC RBD pool and mount it
            ceph osd erasure-code-profile set ecbench plugin=$ecplugin k=3 m=1 crush-device-class=$mydclass
            ceph osd pool create ecrbdbench $((powertwo/2)) $((powertwo/2)) erasure ecbench
            ceph osd pool set ecrbdbench allow_ec_overwrites true
            ceph osd pool application enable ecrbdbench rbd

            #create rbd images for ecrbd
            for i in `cat loadgens.lst`;do for j in {0..9};do rbd create --size=${rbdimgsize}G --data-pool ecrbdbench 3rep-bench/ec$i-$j;done;done
            sleep 10s

            #map the 10 ec rbds per host
            echo "Mapping the EC RBDs"
            for k in `cat loadgens.lst`;do ssh root@$k "for l in {0..9};do rbd map 3rep-bench/ec$k-\$l;done";done
            #need to initialize the complete RBD size that is provisioned to fix bad read results
        fi
    fi

    if [[ $cephfsresponse =~ [yY] ]]
    then
        #delete the existing CephFS
        salt -I roles:mds cmd.run 'systemctl stop ceph-mds.target'
        for i in `seq 0 20`;
        do
            ceph mds fail $i
        done
        ceph fs rm cephfs --yes-i-really-mean-it
        ceph tell mon.* injectargs --mon-allow-pool-delete=true
        ceph osd pool rm cephfs_data cephfs_data --yes-i-really-really-mean-it
        ceph osd pool rm cephfs_metadata cephfs_metadata --yes-i-really-really-mean-it
        salt -I roles:mds cmd.run 'systemctl start ceph-mds.target'

        #create new CephFS
        ceph osd pool create cephfs_data $powertwo $powertwo replicated $mydclass
        ceph osd pool create cephfs_metadata $((powertwo/4)) $((powertwo/4)) replicated $mydclass
        ceph fs new cephfs cephfs_metadata cephfs_data
    ### ADDED for replica testing
        sleep 30s
        ceph osd pool set cephfs_data size 3
        ceph osd pool set cephfs_metadata size 3
        sleep 60s
    ####
        sleep 1s
        salt -I roles:mds cmd.run 'systemctl stop ceph-mds.target'
        sleep 3s
        salt -I roles:mds cmd.run 'systemctl reset-failed ceph-mds@`hostname`'
        sleep 3s
        salt -I roles:mds cmd.run 'systemctl start ceph-mds.target'
        echo -n Waiting while MDS creates metadata
        while [ `ceph mds stat|grep creating|wc -l` -gt 0 ];do echo -n ".";sleep 2s;done
        echo ""
            echo "Making Sure MDS are started"
        while [ `ceph mds stat|grep "cephfs-0"|wc -l` -gt 0 ];
        do
        echo -n '.'
            salt -I roles:mds cmd.run 'systemctl reset-failed ceph-mds@`hostname`'
            sleep 3s
            salt -I roles:mds cmd.run 'systemctl start ceph-mds.target'
        sleep 10s
        done
        echo "settling for 15s"
        sleep 15s
        echo ""
        if [[ $testecresponse =~ [yY] ]]
        then
            #create EC CephFS pool and mount it
            ceph osd pool create eccephfsbench $((powertwo/2)) $((powertwo/2)) erasure ecbench
            ceph osd pool set eccephfsbench allow_ec_overwrites true
            ceph osd pool application enable eccephfsbench cephfs
            ceph fs add_data_pool cephfs eccephfsbench
            echo "System settling for 30s";sleep 30s
            salt -I roles:mds cmd.run 'systemctl reset-failed ceph-mds@$HOSTNAME'
            salt -I roles:mds cmd.run ' systemctl start ceph-mds@$HOSTNAME'
            #TODO: make sure ceph MDS are running.  do systemctl status ceph-mds@$HOSTNAME and look for "systemctl reset-failed"
            #if found, issue command after the third set of quotes on the line
            #sample line
            # To force a start use "systemctl reset-failed ceph-mds@sr630-2.service" followed by "systemctl start ceph-mds@sr630-2.service" again.
            sleep 5s
        fi
        #mount cephfs on each node
        echo "Mounting cephfs and creating a directory for each loadgen node"
        for k in `cat loadgens.lst`
        do
            ssh root@$k "mkdir -p /mnt/cephfs;sleep 1s;mount -t ceph $monlist:/ /mnt/cephfs -o name=admin,secret=$secretkey;sleep 1s;mkdir -p /mnt/cephfs/$k"
            echo Bind mount the per loadgen cephfs path to a universal path
            ssh root@$k "mkdir -p /mnt/benchmaster; sleep 1s;mount --bind /mnt/cephfs/$k /mnt/benchmaster"
            if [[ $testecresponse =~ [yY] ]]
            then
                ssh root@$k "mkdir -p /mnt/cephfs/ec;setfattr -n ceph.dir.layout.pool -v eccephfsbench /mnt/cephfs/ec;mkdir -p /mnt/cephfs/ec/$k"
                # Bind mount the per loadgen cephfs path to a universal path
                ssh root@$k "mkdir -p /mnt/benchmaster/ec; mount --bind /mnt/cephfs/ec/$k /mnt/benchmaster/ec"
            fi
        done
    fi
}

runjobs() {
    #This function runs the jobfiles
    jobfiles="jobfiles/prepit.prep "`ls jobfiles/*.fio`
    loadgens=`cat loadgens.lst`

    if [ $debug != 1 ]
    then
    echo "**** Cluster Description ****">results/cephinfo.txt
    echo "clusterdescription:"$cdesc >>results/cephinfo.txt
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
        case $test in
        rep-rbd)
            export fiotarget="/dev/rbd0:/dev/rbd1:/dev/rbd2:/dev/rbd3:/dev/rbd4:/dev/rbd5:/dev/rbd6:/dev/rbd7:/dev/rbd8:/dev/rbd9"
            export size=100%
            ;;
        ec-rbd)
            export fiotarget="/dev/rbd10:/dev/rbd11:/dev/rbd12:/dev/rbd13:/dev/rbd14:/dev/rbd15:/dev/rbd16:/dev/rbd17:/dev/rbd18:/dev/rbd19"
            export size=100%
            ;;
        rep-cephfs)
            export fiotarget='/mnt/benchmaster/0.fil:/mnt/benchmaster/1.fil:/mnt/benchmaster/2.fil:/mnt/benchmaster/3.fil:/mnt/benchmaster/4.fil:/mnt/benchmaster/5.fil:/mnt/benchmaster/6.fil:/mnt/benchmaster/7.fil:/mnt/benchmaster/8.fil:/mnt/benchmaster/9.fil'
            export size=$(($filesize * 10))G
            ;;
        ec-cephfs)
            export fiotarget='/mnt/benchmaster/ec/0.fil:/mnt/benchmaster/ec/1.fil:/mnt/benchmaster/ec/2.fil:/mnt/benchmaster/ec/3.fil:/mnt/benchmaster/ec/4.fil:/mnt/benchmaster/ec/5.fil:/mnt/benchmaster/ec/6.fil:/mnt/benchmaster/ec/7.fil:/mnt/benchmaster/ec/8.fil:/mnt/benchmaster/ec/9.fil'
            export size=$(($filesize * 10))G
            ;;
        esac

        for i in $jobfiles
        do
                skiplist=`head -1 $i|grep skip`
                if ! [[ " $skiplist " =~ " $test " ]];then
                i=${i##*/}
            jobname=${i%.*}
            export curjob=$test-$jobname
            echo "*** Running job: $curjob ***"
            mkdir -p results/$curjob
                sleep 1s
            commandset=""
            command=""
            for l in $loadgens
            do
                #start fio server on each loadgen
                #echo "Killing any running fio on $l and starting fio servers in screen session"
                    ssh root@$l 'killall -9 fio &>/dev/null;killall -9 screen &>/dev/null;sleep 1s;screen -wipe &>/dev/null;screen -S "fioserver" -d -m'
                ssh root@$l 'sync; echo 3 > /proc/sys/vm/drop_caches'
                ssh root@$l "screen -r \"fioserver\" -X stuff $\"export curjob=$curjob;export ramptime=$ramptime;export runtime=$runtime;export size=$size;export filesize=${filesize}G;export fiotarget=$fiotarget;export curjob=$curjob;fio --server\n\""
                sleep 1s
                commandset=("--client=$l" )
                command+="$commandset jobfiles/$i "
            done
            curjob=$curjob ramptime=$ramptime runtime=$runtime size=$size filesize=${filesize}G fiotarget=$fiotarget curjob=$curjob \
                fio --eta=never --output-format=normal,json+ --output=results/$test-$jobname/$test-$jobname.benchmark $command
                echo "Letting system settle for 30s"
                sleep 30s
                fi
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
    for i in `cat loadgens.lst`;do ssh root@$i 'for j in `ls /dev/rbd*`;do rbd unmap $j;done;umount -R /mnt/benchmaster;rm -rf /mnt/cephfs/ec/*;rm -rf /mnt/cephfs/$i;umount /mnt/cephfs;rm -rf /mnt/cephfs /mnt/benchmaster';done
    salt '*' cmd.run 'systemctl stop ceph-mds.target'
    for i in `seq 0 20`;
    do
        ceph mds fail $i
    done
    ceph tell mon.* injectargs --mon-allow-pool-delete=true
    ceph fs rm cephfs --yes-i-really-mean-it
    ceph fs rm_data_pool cephfs eccephfsbench
    ceph osd pool delete eccephfsbench eccephfsbench --yes-i-really-really-mean-it  &>/dev/null
    ceph osd pool rm cephfs_data cephfs_data --yes-i-really-really-mean-it
    ceph osd pool rm cephfs_metadata cephfs_metadata --yes-i-really-really-mean-it
    salt '*' cmd.run 'systemctl start ceph-mds.target'

    ceph tell mon.* injectargs --mon-allow-pool-delete=true  &>/dev/null
    ceph osd pool delete 3rep-bench 3rep-bench --yes-i-really-really-mean-it  &>/dev/null
    ceph osd pool delete ecrbdbench ecrbdbench --yes-i-really-really-mean-it  &>/dev/null
    ceph tell mon.* injectargs --mon-allow-pool-delete=false  &>/dev/null
    ceph osd erasure-code-profile rm ecbench
    ceph osd crush rule rm ecrbdbench
    ceph osd crush rule rm eccephfsbench
    ceph osd crush rule rm ssd
    ceph osd crush rule rm hdd

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

#main
if [ $# -gt 1 ]; then
    usage
fi
if [ $# -eq 1 ]; then
    case "$1" in
        "prepare")
                infogather
                prepare
                RETVAL=1
                ;;
        "dojobs")
                infogather
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
    #cleanup
fi
exit $RETVAL

