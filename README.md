# benchmaster
Benchmark scripts, config files, etc

The script runs the jobs specified in the jobfiles directory.  It begins by ensuring all infrastructure is configured including installing fio, setting up ssh keys, and running fio --server in screen sessions on the load generation nodes.

It is recommended that benchmaster be run on the salt-master/SES admin node

****WARNING**** The run time for a full suite of tests will range from 2 - 6 days depending on the size and speed of the OSDs as the cluster must pre-poulate the test images with uncompressible, random data

### Preperation
The script expects to have 3 files placed in benchmaster/Benchmaster
 - loadgens.lst: This will contain resolvable hostnames of the load generation nodes. These should have a fresh install of SLES
 - cluster.lst: a list of all cluster nodes
 - osds.lst: a list of all OSD nodes in the cluster

### Configuration:
There are two parameters you can edit in the top of the file.  These control test run time.  They are defaulted to values that should help ensure that the cache is overrun and that actual performance maximums are achieved.  
 ramptime=600
  - This is the ramp time in seconds allocated to each test where no results will be recorded.  This provides time for the device to warm up and not affect the outcome.
  
 runtime=1800
  - This is the time in seconds that each test will run for.  It should be long enough to ensure that the tests burn through any cache
  
# Object General:
Object is not yet integrated into the framework, but a beta test file is present for use.  Please feel free to open issues against it if you have input.

 Install cosbench (https://github.com/intel-cloud/cosbench/releases) and get it running.
 copy the s3-standard.xml file to the cosbench application directory
 use the cli.sh script to launch workloads
 e.g. ./cli.sh s3-standard.xml
 
 ## s3-standard.xml
 This file is located in Benchmaster/jobfiles contains a set of tests that are comparable to the fio tests with the addition of a 60/40 read/write test.  Runtime is a bit short in the current file at only five minutes and should be adjusted for your purposes.  
 
