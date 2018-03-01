# benchmaster
Benchmark scripts, config files, etc

# Results Spreadsheet
This sheet makes it relatively easy to consume the output of the benchmaster-extract.sh.  The sheet does have embedded formulas that you may need to adjust to correctly consume and use the output.
In general, use an empty area of the sheet to copy and paste in the results from the benchmaster-extract script.  Highlight the results and go to the data tab in the ribbon.  use text to columns and use the delimited selection, with a comma as the delimiter.  After hitting finish, you will have two colums, 1 with the label and 1 with the output.  Put the output in the appropriate location and the formulas will either sum, or average the output as appropriate.

# Object General:
 Install cosbench (https://github.com/intel-cloud/cosbench/releases) and get it running.
 copy the s3-standard.xml file to the cosbench application directory
 use the cli.sh script to launch workloads
 e.g. ./cli.sh s3-standard.xml
 
 ## s3-standard.xml
 This file contains a set of tests that are comparable to the fio tests with the addition of a 60/40 read/write test.  Runtime is a bit short in the current file at only five minutes and should be adjusted for your purposes.
 
# Block & File General:
 The use of this script is to install fio and all benchmaster scripts on each node.
 initiate a screen session to run the fio script.  
 The best practice is to have all windows open simultaneously and then launch the 
 scripts on one after another as quickly as possible.

## benchmaster-extract.sh
This script parses the output from the benchmaster-fio script and creates data that is easily 
parsed as comma-delimited text by a spreadsheet.

usage:
 benchmaster-extract.sh testname
 
## benchmaster-fio.sh 
usage: 
 benchmaster-fio.sh testname
 e.g. ./benchmaster-fio.sh 2node-cephfs


### Preperation
Each load generation node expects to have 10 devices or files to write to. Each device should be unique per load generator.  They should always be in the format of /dev/rbd0, /dev/dm-0, or /mnt/cephfs/fil0.  The test devices expect to start at 0 and end on 9

### Configuration:

The benchmaster-fio.sh file will execute a number of tests.
 - sequential read and write tests at 8k, 128k, and 1MB
 - random read and write tests at 4k
 The script expects there to be 10 targets of 150G
 
 In the top of the file is a section to edit parameters for the test run.
 
 where=/dev/rbd
  - This is the location of the devices to test.  If the device is a raw device like rbd[0..9] then the location is /dev/rbd.   If the device is a file, then it would be something like /mnt/mountname/file
  
 ramp=300
  - This is the ramp time in seconds allocated to each test where no results will be recorded.  This provides time for the device to warm up and not affect the outcome.
  
 testrun=1800
  - This is the time in seconds that each test will run for.  It should be long enough to ensure that the tests burn through any cache
  
  
 pre=900
  - This is for a pre-conditioning run to happen before the 4k write test.  It helps ensure that the media is operating with plenty of pre-writen sectors and not providing a false result
  due to virgin media.
  
 hosts=2
  - This is unused at current
  
 ioengine=aio
  - This selects one of fio's many io engines.  If using an engine like librbd, then the extra= parameter should be 
  uncommented and properly filled with parameters
  
 #extra="--size=150G"
  - This is used for any extra parameters required.  The default has the parameter required if using a file as the target.
