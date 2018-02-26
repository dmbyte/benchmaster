testname=$1
echo $testname
where=/dev/rbd
ramp=300
testrun=1800
pre=900
#ramp=300
#testrun=600
#pre=300
hosts=2
ioengine=aio
#extra="--size=150G"
mkdir $testname
fio --filename=${where}0:${where}1:${where}2:${where}3:${where}4:${where}5:${where}6:${where}7:${where}8:${where}9 --direct=1 --rw=rw --time_based --refill_buffers --norandommap --randrepeat=0 --ioengine=$ioengine $extra --bs=1024k --rwmixread=0  --iodepth=16 --numjobs=10  --runtime=$testrun --ramp_time=$ramp --group_reporting --name=seq-suse_$hosts-$HOSTNAME-1024k-10-16-0 --output=$testname/seq-suse_$hosts-$HOSTNAME-1024k-10-16-0.out
echo "letting system settle for 300s"
sleep 300s
fio --filename=${where}0:${where}1:${where}2:${where}3:${where}4:${where}5:${where}6:${where}7:${where}8:${where}9 --direct=1 --rw=rw --time_based --refill_buffers --norandommap --randrepeat=0 --ioengine=$ioengine $extra --bs=1024k --rwmixread=100  --iodepth=16 --numjobs=10  --runtime=$testrun --ramp_time=$ramp --group_reporting --name=seq-suse_$hosts-$HOSTNAME-1024k-10-16-100 --output=$testname/seq-suse_$hosts-$HOSTNAME-1024k-10-16-100.out
echo "letting system settle for 300s"
sleep 300s

fio --filename=${where}0:${where}1:${where}2:${where}3:${where}4:${where}5:${where}6:${where}7:${where}8:${where}9 --direct=1 --rw=rw --time_based --refill_buffers --norandommap --randrepeat=0 --ioengine=$ioengine $extra --bs=128k --rwmixread=0  --iodepth=16 --numjobs=10  --runtime=$testrun --ramp_time=$ramp --group_reporting --name=seq-suse_$hosts-$HOSTNAME-128k-10-16-0 --output=$testname/seq-suse_$hosts-$HOSTNAME-128k-10-16-0.out
echo "letting system settle for 300s"
sleep 300s
fio --filename=${where}0:${where}1:${where}2:${where}3:${where}4:${where}5:${where}6:${where}7:${where}8:${where}9 --direct=1 --rw=rw --time_based --refill_buffers --norandommap --randrepeat=0 --ioengine=$ioengine $extra --bs=128k --rwmixread=100  --iodepth=16 --numjobs=10  --runtime=$testrun --ramp_time=$ramp --group_reporting --name=seq-suse_$hosts-$HOSTNAME-128k-10-16-100 --output=$testname/seq-suse_$hosts-$HOSTNAME-128k-10-16-100.out
echo "letting system settle for 300s"
sleep 300s

fio --filename=${where}0:${where}1:${where}2:${where}3:${where}4:${where}5:${where}6:${where}7:${where}8:${where}9 --direct=1 --rw=rw --time_based --refill_buffers --norandommap --randrepeat=0 --ioengine=$ioengine $extra --bs=8k --rwmixread=0  --iodepth=16 --numjobs=10  --runtime=$testrun --ramp_time=$ramp --group_reporting --name=seq-suse_$hosts-$HOSTNAME-8k-10-16-0 --output=$testname/seq-suse_$hosts-$HOSTNAME-8k-10-16-0.out
echo "letting system settle for 300s"
sleep 300s
fio --filename=${where}0:${where}1:${where}2:${where}3:${where}4:${where}5:${where}6:${where}7:${where}8:${where}9 --direct=1 --rw=rw --time_based --refill_buffers --norandommap --randrepeat=0 --ioengine=$ioengine $extra --bs=8k --rwmixread=100  --iodepth=16 --numjobs=10  --runtime=$testrun --ramp_time=$ramp --group_reporting --name=seq-suse_$hosts-$HOSTNAME-8k-10-16-100 --output=$testname/seq-suse_$hosts-$HOSTNAME-8k-10-16-100.out
echo "letting system settle for 300s"
sleep 300s


fio --filename=${where}0:${where}1:${where}2:${where}3:${where}4:${where}5:${where}6:${where}7:${where}8:${where}9 --direct=1 --rw=randrw --time_based --refill_buffers --norandommap --randrepeat=0 --ioengine=$ioengine $extra --bs=4k --rwmixread=0  --iodepth=16 --numjobs=10  --runtime=$pre --group_reporting --name=rand-suse_$hosts-$HOSTNAME-4k-10-16-0 --output=$testname/rand-suse_$hosts-$HOSTNAME-4k-10-16-pre.out
sleep 300s
fio --filename=${where}0:${where}1:${where}2:${where}3:${where}4:${where}5:${where}6:${where}7:${where}8:${where}9 --direct=1 --rw=randrw --time_based --refill_buffers --norandommap --randrepeat=0 --ioengine=$ioengine $extra --bs=4k --rwmixread=0  --iodepth=16 --numjobs=10  --runtime=$testrun --ramp_time=$ramp --group_reporting --name=rand-suse_$hosts-$HOSTNAME-4k-10-16-0 --output=$testname/rand-suse_$hosts-$HOSTNAME-4k-10-16-0.out
sleep 300s
fio --filename=${where}0:${where}1:${where}2:${where}3:${where}4:${where}5:${where}6:${where}7:${where}8:${where}9 --direct=1 --rw=randrw --time_based --refill_buffers --norandommap --randrepeat=0 --ioengine=$ioengine $extra --bs=4k --rwmixread=100  --iodepth=16 --numjobs=10  --runtime=$testrun --ramp_time=$ramp --group_reporting --name=rand-suse_$hosts-$HOSTNAME-8k-10-16-100 --output=$testname/rand-suse_$hosts-$HOSTNAME-4k-10-16-100.out
