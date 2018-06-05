import json
import pymongo
from bson import json_util
filename="7f730341-5f1b-328f-b3b2-efc2fcaedbbc"
connection = pymongo.MongoClient("mongodb://benchsystem:SES.sys.Fast@localhost/benchmarkdata")
#connection.the_database.authenticate('benchsystem','SES.sys.Fast')
db=connection['benchmarkdata']
record1 = db[filename]
def convert(name):
    s1 = name.replace('.', '_')
    return s1

def change_keys(obj, convert):
    """
    Recursively goes through the dictionary obj and replaces keys with the convert function.
    """
    if isinstance(obj, (str, int, float)):
        return obj
    if isinstance(obj, dict):
        new = obj.__class__()
        for k, v in obj.iteritems():
            new[convert(k)] = change_keys(v, convert)
    elif isinstance(obj, (list, set, tuple)):
        new = obj.__class__(change_keys(v, convert) for v in obj)
    else:
        return obj
    return new

with open(filename+'.json') as f:
    file_data=json.load(f)

#page=open(filename+".json", 'r')
#parsed = json_util.loads(page.read())
#print ('parsed %s') %(parsed)
#for item in parsed[filename]:
#print(file_data)
cleandata=change_keys(file_data,convert)
#print(cleandata)
record1.insert(cleandata)
