# benchmaster
Benchmark scripts, config files, etc

The script runs the jobs specified in the jobfiles directory.  It begins by ensuring all infrastructure is configured including installing fio, setting up ssh keys, and running fio --server in screen sessions on the load generation nodes.

It is recommended that benchmaster be run on the salt-master/SES admin node

****WARNING**** The run time for a full suite of tests will range from 2 - 6 days depending on the size and speed of the OSDs as the cluster must pre-poulate the test images with uncompressible, random data

### Preparation
Every node should have access to package repositories
The script expects to have 2 files placed in benchmaster/Benchmaster
 - loadgens.lst: This will contain resolvable hostnames of the load generation nodes. These should have a fresh install of SLES
  
### Configuration:
There are two parameters you can edit in the top of the file.  These control test run time.  They are defaulted to values that should help ensure that the cache is overrun and that actual performance maximums are achieved.  
 ramptime=600
  - This is the ramp time in seconds allocated to each test where no results will be recorded.  This provides time for the device to warm up and not affect the outcome.
  
 runtime=1800
  - This is the time in seconds that each test will run for.  It should be long enough to ensure that the tests burn through any cache
  
# Object General:
Object testing has been enabled with a few test profiles in the jobfiles/s3/ directory. bs>512M are not currently supported by fio

 # Viewing results:
 viewresult.sh will call the corresponding python file and distill the relevant information from the results/{whatever-your-test-is}.benchmark into human readable information. A future version will generate a .csv of the tests and relevant metrics for further use.

 In scripts there exists bmchart.py. this script is still in need of conversion to Python3 syntax, but will generate graphs of the rests when run against the /results directory.
