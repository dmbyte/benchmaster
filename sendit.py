import requests
import sys
filetosend = sys.argv[1]

#http://docs.python-requests.org/en/latest/user/quickstart/#post-a-multipart-encoded-file

url = "http://benchmarks.futurereality.net:5000"
fin = open(filetosend, 'rb')
files = {'file': fin}
try:
	r = requests.post(url, files=files)
	print r.text
finally:
	fin.close()
