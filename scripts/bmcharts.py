#!/usr/bin/python
from operator import itemgetter
import matplotlib
import json
import sys
import os
#set graph colors
readbar = "#02A49C"
writebar = "#A7A9AC"
hline = "#0007B0"

if len(sys.argv) != 2:
    print ('USAGE: bmcharts.py <path to benchmaster results>')
    sys.exit(1)


protocols = ['rbd', 'cephfs', 'nfs', 's3']
iopattern = ['seqwrite', 'seqread', 'randwrite', 'randread',
             'mixed', 'backup', 'recovery', 'kvm', 'oltp-log', 'oltp-data', 'S3_seqwrite']
clivar1 = sys.argv[1]


def search_files(directory, extension='benchmark'):
    mylist = []
    extension = extension.lower()
    for dirpath, dirnames, files in os.walk(directory):
        for name in files:
            if extension and name.lower().endswith(extension):
                mylist.append(os.path.join(dirpath, name))
    return mylist


results = []
filelist = search_files(clivar1)
for thisproto in protocols:
    for iopat in iopattern:
        # print ("Proto = %s     IOPAT= %s" %(thisproto, iopat))
        for thisfile in filelist:
            thisresult = []
            myjson = ''
            xlabels = ''
            yvalues = ''
            tempfileinfo = thisfile.split("/")
            testname = tempfileinfo[len(tempfileinfo)-1]
            if thisproto in testname and iopat in testname:
                # print ('testname '+testname)
                with open(thisfile, 'r') as f:
                    jsonstart = False
                    for line in f:
                        if jsonstart == False:
                            if line[0:1] == '{':
                                jsonstart = True
                                myjson = myjson+line
                        else:
                            myjson = myjson+line
                fiodata = json.loads(myjson)
                testnodecount = len(fiodata['client_stats'])-1
                rwsetting = fiodata['client_stats'][0]['job options']['rw']
                readpercentage = fiodata['client_stats'][0]['job options']['rwmixread']
                maxiodepth = fiodata['client_stats'][0]['job options']['iodepth']
                jobspernode = fiodata['client_stats'][0]['job options']['numjobs']
                bs = fiodata['client_stats'][0]['job options']['bs']
                if bs == '64M':
                    bso = 65536
                elif bs == '4M':
                    bso = 4096
                elif bs == '1M':
                    bso = 1024
                elif bs == '64k':
                    bso = 64
                elif bs == '32k':
                    bso = 32
                elif bs == '8k':
                    bso = 8
                elif bs == '4k':
                    bso = 4
                elif bs == '512M':
                    bso = 524288
                elif bs == '128M':
                    bso = 131072
                else:
                    bso = 0

                if testname[0:2] == 'ec':
                    protection = 'EC 6+3'
                elif testname[0:3] == 'rep':
                    protection = "3x Rep"

                if 'latency_target' in fiodata['client_stats'][0]['job options']:
                    lattarget = fiodata['client_stats'][0]['job options']['latency_target']
                    latwindow = fiodata['client_stats'][0]['job options']['latency_window']
                    latpercentage = fiodata['client_stats'][0]['job options']['latency_percentile']
                else:
                    lattarget = 0
                    latwindow = 0
                    latpercentage = 0
                for x in range(0, len(fiodata['client_stats'])):
                    # Since fio v2.99 time resolution changed to nanosecond, json output key name changed from 'lat' 
                    lat_key = 'lat_ns' if 'lat_ns' in fiodata['client_stats'][x]['write'] else 'lat'
                    if lat_key == 'lat_ns':
                        latdiv = 1000000
                    else:
                        latdiv = 1000
                    if x == len(fiodata['client_stats'])-1:
                        writebw = fiodata['client_stats'][x]['write']['bw']/1024
                        writeiops = fiodata['client_stats'][x]['write']['iops']
                        writeavglat = fiodata['client_stats'][x]['write'][lat_key]['mean']/latdiv
                        writemaxlat = fiodata['client_stats'][x]['write'][lat_key]['max']/latdiv
                        readbw = fiodata['client_stats'][x]['read']['bw']/1024
                        readiops = fiodata['client_stats'][x]['read']['iops']
                        readavglat = fiodata['client_stats'][x]['read'][lat_key]['mean']/latdiv
                        readmaxlat = fiodata['client_stats'][x]['read'][lat_key]['max']/latdiv
                        # print ('"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s")
                        thisresult = [protection, thisproto, bso, iopat, rwsetting, readpercentage, maxiodepth, jobsp, latwindow, latpercentage, writebw, writeiops, writeavglat, writemaxlat, readbw, readiops, results.append(thisresult)
# print ('total results: %s' %(len(results)))
# from sets import Set
myset.clear()
for x in results:
        myset.add(x[1]+x[3])
print ('myset: %s' %(myset))


# time to make some graphs
# need to cycle through the myset list and pull out all metrics from results that meet the protocol and pattern, sort
matplotlib.use('Agg')
for filter in myset:
    import matplotlib.pyplot as plt
    from matplotlib.font_manager import FontProperties
    plt.figure()
    fig, ax1 = plt.subplots()
    fig.set_size_inches(9, 6)
    barheight = []
    tick_label = []
    graphlines = []
    gc = 1
    graphlist = []
    latpoints = []
    trows = []
    for rline in results:
        if filter == rline[1]+rline[3]:
	        graphlist.append(rline)
    sortgraph = graphlist.sort(key=itemgetter(2))
    for sline in graphlist:
        print (sline)
        myrow = []
        colors = []
	# print ('barheight: %s' %(int(sline[15])))
	if sline[5] != "100":
    		barheight.append(int(sline[11]))
		graphlines.append(gc)
	        tick_label.append(str(sline[2]) + 'KiB\n' + 'Write\n'+sline[0])
        	latpoints.append(int(sline[13]))
	        gc = gc+1
	        colors.append(readbar)
    	if sline[5] != "0":
	  	barheight.append(int(sline[15]))
	        graphlines.append(gc)
		tick_label.append(str(sline[2]) +'KiB\n'+ 'Read\n'+sline[0])        
            	latpoints.append(int(sline[17]))
	        gc=gc+1
        	colors.append(writebar)
        if sline[5] == "100":
            	columnheaders=['I/O Size','Protection','Read BW (MiB/s)','Read IOPS', 'Read Average Latency (ms)']
            	myrow=[str(sline[2]) + 'KiB',sline[0],int(sline[15]),int(sline[16]),int(sline[17]*10)/10]
        elif sline[5] == "0":
            	columnheaders=['I/O Size','Protection','Write BW (MiB/s)','Write IOPS', 'Write Average Latency (ms)']
            	myrow=[str(sline[2]) + 'KiB',sline[0],int(sline[11]),int(sline[12]),int(sline[13]*10)/10]
        else:
            	columnheaders=['Write BW (MiB/s)','Write IOPS','Write Average\nLatency (ms)','Protection','Read Avera
            	myrow=[int(sline[11]),int(sline[12]),int(sline[13]*10)/10,sline[0],int(sline[17]*10)/10,int(sline[16]
    	trows.append(myrow)
    ax1.bar(graphlines, barheight, width=0.8,tick_label=tick_label, color=colors)
    rawtitle=str(sline[1]+' '+sline[3])
    mytitle=rawtitle.upper()
    plt.title(mytitle)
    plt.rcParams['xtick.labelsize']=8
    ax1.set_ylabel('Throughput (MiB/s)')
    ax2=ax1.twinx()
    ax2.plot(graphlines,latpoints,color=hline,marker='_',linestyle='',markersize=340/len(graphlines))
    ax2.set_ylabel('Average Latency (ms)',color=hline)
    ax2.tick_params(colors=hline)
    fig.tight_layout()
    the_table=plt.table(cellLoc='center',cellText=trows,colLabels=columnheaders,loc='bottom',bbox=[0.0,-(.25+len(trow
    for (row, col), cell in the_table.get_celld().items():
    	if (row == 0) or (col == -1):
    		cell.set_text_props(fontproperties=FontProperties(weight='bold'))
    the_table.auto_set_font_size(False)
    the_table.set_fontsize(6)
    plt.subplots_adjust(bottom=.5)
    plt.savefig("/root/"+filter+".png")	
    plt.cla()
    plt.clf()
    plt.close('all')
    del plt
    del barheight
    del graphlines
    del tick_label
    del sortgraph
