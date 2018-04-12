#!/bin/bash

#check if loadgens.lst file is present
if [ -f /root/loadgens.lst ];then
        echo "You must create the /root/loadgens.lst file for this to work"
        exit
fi
echo "if your load generation nodes don't resolve by name, CTL-C now and fix it."
pause 5s

echo "First we'll ensure that we have uninhibited access"
pause 3s
#Check if public key is present
if [ ! -f /root/.ssh/id_rsa.pub ];then
        ssh-keygen
fi
#copy public key to loadgens
for m in `cat /root/loadgens.lst`;do ssh-copy-id root@$m;done
echo "if there were any issues above, please CTL-C now and correct them, then re-run the script"
pause 5s
echo "Creating Pool(s)"
#create pools
#create EC pool definition that fits in 4 node (3&1?)
ceph osd pool create 3rep-bench 512 512
#create 10 rbds per host of size 40G
echo "Creating RBDs for testing"
for i in `cat /root/loadgens.lst`;do for j in {0..9};do rbd create 3rep-bench/$i-$j --size=40G;done;done
#map the 10 rbs per host
echo "Mapping the RBDs"
for k in `cat /root/loadgens.lst`;do ssh root@$k 'for l in {0..9};do rbd map 3rep-bench/`hostname`-$l;done';done 
