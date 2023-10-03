#!/bin/bash
debug=0
#debug doesn't collect system info.

#defaults
cdesc=${HOSTNAME}_$(date +%Y-%M-%d_%H%M%S)
sendresults=N
isaresponse=N
rbdresponse=N
nfsresponse=N
s3response=N
testlist=""
allocdiv=0
ramptime=600
runtime=1800


###### NEED to get NFS and/or S3 IP addresses and bucket name
optcfg () {
    local option=$1
    if [[ ${opts[option]} == Y ]]
    then
        opts[option]=N
    else
        opts[option]=Y
    fi
}


infogather() {
    #Validate environment and general details
    #check if loadgens.lst and osdnodes.lst files are present
    for file in loadgens.lst ; do
        if [ ! -f $file ]; then
            echo "!! You must create the $file file for this to work."
            echo "   The file should contain a list of all the ${file%%s.osd} nodes"
            echo "   with one per line."
            exit
        fi
    done
    #make the results directory
    if [ ! -d results ]; then
        mkdir -p results
    fi

    #gather test parameters
    while true; do
        options=("Description,${opts[0]:-$cdesc}" \
                 "Test NFS,${opts[5]:-$nfsresponse}" \
                 "Test S3,${opts[6]:-$s3response}" \
                 "Upload Results?,${opts[8]:-$sendresults}" \
                 "Start Test")
        clear
        echo "Benchmaster:"
        echo
        echo " --- Test Configuration ---"
        echo
        count=0
        for i in "${options[@]}"; do
            if [[ "${i%%,*}" == "Start Test" ]]; then
                echo
                printf "%3s %-15s\n" "${count})" "${i%%,*}"
            else
                if [[ $count == 0 ]]; then
                    printf "%3s %-25s:   %-8s\n" "${count})" "${i%%,*}" "${i##*,}"
                    echo
                elif [[ $count == 1 ]]; then
                    printf "%3s %-25s:   %-8s\n" "${count})" "${i%%,*}" "${i##*,}"
                else
                    if [[ "${i##*,}" == "Y" ]]; then
                        status=Enabled
                    elif [[ "${i##*,}" == "N" ]]; then
                        status=Disabled
                    else
                        status="${i##*,}"
                    fi
                    printf "%3s %-25s:   %-8s\n" "${count})" "${i%%,*}" "$status"
                fi
            fi
            let count++
        done
        echo
        read -r -p "Select item to enable/disable, or begin test ('A' to abort): " response
        case $response in
                0)
                    # Test description
                    read -r -p "Describe the cluster/test: " opts[0]
                    cdesc=opts[0]
                    ;;
                1)
                    # NFS
                    optcfg $response
                    if [[ ${opts[$response]} == "Y" ]]; then
                        nfsresponse="Y"
                    else
                        nfsresponse="N"
                    fi
                    ;;
                2)
                    # S3
                    echo " *** S3 testing is currently not available. ***"
                    read -s -p "  Press [Enter] to continue... "
                    optcfg $response
                    if [[ ${opts[$response]} == "Y" ]]; then
                        s3response="Y"
                    else
                        s3response="N"
                    fi
                    ;;
                3)
                    # Upload results
                    optcfg $response
                    if [[ ${opts[$response]} == "Y" ]]; then
                        sendresults=1
                    else
                        sendresults=0
                    fi
                    ;;
                4)
                    # Start test
                    break
                    ;;
                A|a)
                    echo "** Test aborted **"
                    exit 1
                    ;;
                *)
                    echo "Invalid option!"
        esac
    done

    # Configure EC testlist and allocdiv for RBD and CephFS
    if [[ $nfsresponse = "Y" ]]; then
        testlist="rep-nfs $testlist"    
    fi

    if [ $debug = 1 ]; then
        echo
        echo "Using configuration parameters:"
        printf "%-15s:   %-8s\n" cdesc $cdesc
        printf "%-15s:   %-8s\n" sendresults $sendresults
        printf "%-15s:   %-80s\n" testlist "$testlist"
        printf "%-15s:   %-8s\n" nfsresponse $nfsresponse
        printf "%-15s:   %-8s\n" s3response $s3response
        echo
    fi

    echo " ----  Building Test Parameters  ----"
    #This function prepares the environment
    #Get a list of the monitor hosts IP addresses.  Needed for CephFS mounting
    }

prepare() {
    #check name resolution for loadgens
    for m in `cat loadgens.lst`; do
        if ! host $m &>/dev/null; then
            echo "!! Host $m does not resolve to an IP.  Please fix and re-run"
            exit
        fi
    done

    echo "** First we'll ensure that we have uninhibited access"
    #Check if public key is present
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
            echo "** Need to generate rsa keypair for this host"
            ssh-keygen -N "" -f ~/.ssh/id_rsa
    fi

    #copy public key to loadgens
    for m in `cat loadgens.lst`; do
        echo "** Now copying public key to $m."
        echo "   You may be prompted for the root password on that host."
        ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root@$m &>/dev/null
    done

    for m in `cat loadgens.lst`; do
        ssh root@$m 'exit'
        if [ $? -ne 0 ]
        then
            echo "SSH to $m seems not to be working.  Please correct and re-run"
            echo "the script."
            exit
        fi
    done

    echo "** Ensuring fio and screen are installed on all nodes"
    #Ensure bc and fio are installed on admin node
    if [ !`command -v bc` ]; then
        echo "** Installing bc on $HOSTNAME"; zypper -q in -y bc &>/dev/null
    fi
    if [ ! `command -v fio` ]; then
        echo "** Installing fio on $HOSTNAME"; zypper -q in -y fio &>/dev/null
    fi
    #Perform work on all test nodes
    for m in `cat loadgens.lst`; do
        ssh root@$m 'if [ ! `command -v fio` ];then echo "** Installing fio on $HOSTNAME";zypper -q in -y fio &>/dev/null;fi'
        ssh root@$m 'if [ ! `command -v screen` ];then echo "** Installing screen on $HOSTNAME";zypper -q in -y screen &>/dev/null;fi'
    done
    echo

    
    if [[ $nfsresponse =~ [yY] ]]; then
        #delete the existing CephFS
        #mount nfs on each node
        echo "Mounting nfs and creating a directory for each loadgen node"
        for k in `cat loadgens.lst`; do
            ssh root@$k "mkdir -p /mnt/nfs;sleep 1s;mount $nfsip:/$bucketname /mnt/nfs;sleep 1s;mkdir -p /mnt/nfs/$k"
            echo Bind mount the per loadgen cephfs path to a universal path
            ssh root@$k "mkdir -p /mnt/benchmaster; sleep 1s;mount --bind /mnt/nfs/$k /mnt/benchmaster"
        done
    fi
}

runjobs() {
    #This function runs the jobfiles
    jobfiles="jobfiles/prepit.prep "`ls jobfiles/*.fio`
    loadgens=`cat loadgens.lst`

    if [ $debug != 1 ]; then
        echo "**** Test Description ****">results/benchinfo.txt
        echo "clusterdescription:"$cdesc >>results/benchinfo.txt
        echo " ">>results/benchinfo.txt

    fi
    for  test in $testlist; do
        case $test in
        rep-rbd)
            export fiotarget="/dev/rbd0:/dev/rbd1:/dev/rbd2:/dev/rbd3:/dev/rbd4:/dev/rbd5:/dev/rbd6:/dev/rbd7:/dev/rbd8:/dev/rbd9"
            export size=100%
            ;;
        ec-rbd)
            export fiotarget="/dev/rbd10:/dev/rbd11:/dev/rbd12:/dev/rbd13:/dev/rbd14:/dev/rbd15:/dev/rbd16:/dev/rbd17:/dev/rbd18:/dev/rbd19"
            export size=100%
            ;;
        rep-nfs)
            export fiotarget='/mnt/benchmaster/0.fil:/mnt/benchmaster/1.fil:/mnt/benchmaster/2.fil:/mnt/benchmaster/3.fil:/mnt/benchmaster/4.fil:/mnt/benchmaster/5.fil:/mnt/benchmaster/6.fil:/mnt/benchmaster/7.fil:/mnt/benchmaster/8.fil:/mnt/benchmaster/9.fil'
            export size=$(($filesize * 10))G
            ;;
        esac

        for i in $jobfiles; do
            skiplist=`head -1 $i|grep skip`
            if ! [[ " $skiplist " =~ " $test " ]]; then
                i=${i##*/}
                jobname=${i%.*}
                export curjob=$test-$jobname
                echo "*** Running job: $curjob ***"
                mkdir -p results/$curjob
                sleep 1s
                commandset=""
                command=""
                for l in $loadgens; do
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
        #read -r -p "press enter to proceed to next job" garbage
        done
    done


    if [ "$sendresults" == 1 ]; then
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
    # Remove RBD and CephFS devices
    for i in `cat loadgens.lst`; do
        ssh root@$i 'umount -R /mnt/benchmaster;rm -rf /mnt/nfs/ec/*;rm -rf /mnt/nfs/$i;umount /mnt/nfs;rm -rf /mnt/nfs /mnt/benchmaster'
    done 
    # Kill all fio and screen processes
    for k in `cat loadgens.lst`; do
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

