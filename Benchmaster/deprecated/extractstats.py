import json
with open('test.pure.json','r') as f:
	fiodata=json.load(f)
print 'Total Test Nodes: %s'% (len(fiodata['client_stats'])-1)
print 'RW Setting: %s'%(fiodata['client_stats'][0]['job options']['rw'])
print 'Read: %s'%(fiodata['client_stats'][0]['job options']['rwmixread'])
print 'IO Depth: %s'%(fiodata['client_stats'][0]['job options']['iodepth'])
print 'Jobs per node: %s'%(fiodata['client_stats'][0]['job options']['numjobs'])
print 'Latency Target: %s'%(fiodata['client_stats'][0]['job options']['latency_target'])
print 'Latency window %s'%(fiodata['client_stats'][0]['job options']['latency_window'])
print 'Percent of I/O that MUST be in the targer during the window: %s'%(fiodata['client_stats'][0]['job options']['latency_percentile'])
for x in range(0,len(fiodata['client_stats'])):
	print '-----------------------------------------------------------------------'
	if x == len(fiodata['client_stats'])-1:
		print 'SUMMARY STATS'
	else:
		print 'Hostname:  %s'% (fiodata['client_stats'][x]['hostname'])

	print 'Bandwidth: %s MiB/s'% ((fiodata['client_stats'][x]['write']['bw'])/1024)
	print 'IOPS:      %s '% (fiodata['client_stats'][x]['write']['bw'])
	print 'Avg lat:   %sms'% (fiodata['client_stats'][x]['write']['lat_ns']['mean']/1000000)
	print 'Max lat:   %sms'% (fiodata['client_stats'][x]['write']['lat_ns']['max']/1000000)
	print 'STDev:     %sms'% (fiodata['client_stats'][x]['write']['lat_ns']['stddev']/1000000)
	totalios=fiodata['client_stats'][x]['write']['total_ios']

#print fiodata['client_stats'][x]['write']['clat_ns']

