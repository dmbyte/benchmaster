from flask import Flask
from flask import redirect
from flask import request
from flask import send_from_directory
from flask import url_for
import fnmatch
import os
import tarfile
from time import strftime
from werkzeug import secure_filename

UPLOAD_FOLDER = 'uploads'

TMP_FOLDER = '/tmp/benchmaster'
ALLOWED_EXTENSIONS = set(['tgz'])

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 2000 * 1024 * 1024

def find(pattern, path):
#find all files in the given path with the given pattern
    result = []
    for root, dirs, files in os.walk(path):
        for name in files:
            if fnmatch.fnmatch(name, pattern):
                result.append(os.path.join(root, name))
    return result	

def allowed_file(filename):
    # this has changed from the original example because the original did not work for me
        return filename[-3:].lower() in ALLOWED_EXTENSIONS

@app.route('/', methods=['GET', 'POST'])
def upload_file():
    if request.method == 'POST':
        file = request.files['file']
        if file and allowed_file(file.filename):
            print '**found file', file.filename
            filename = secure_filename(file.filename)
	    finalfilename = filename + '-' + strftime("%Y%m%dT%H%M%S")
            file.save(os.path.join(app.config['UPLOAD_FOLDER'], finalfilename))
            # for browser, add 'redirect' function on top of 'url_for'
            #
	    # untar the file into TMP_FOLDER/finalfilename
	    tmppath = TMP_folder + "/" + finalfilename
	    if not os.path.exists(tmppath):
                os.makedirs(tmppath)
	    tar = tarfile.open(UPLOAD_FOLDER + "/" + finalfilename)
	    tar.extractall(tmppath)
	    #find all the .benchmark files
	    benchfilelst = find('*.benchmark', 'tmppath')
            jsonoutfile=benchfilelst+'.json'
	    for result in benchfilelst:
	        pathelements = result.split('/')
	    	# testname=last dir before benchmark filename
		testname = pathelements[len(pathelements)-2]	
	    # for each subdir, run splitit routine (currently a script)
		jsonout = open(result + '.json')
		with open(result, 'r') as rfile:
                    for line in rfile:
                        if '{' in line:
                            ofile=open(jsonoutfile,'wb')
                            for line in rfile:
                            #write out json file 
                                ofile.write(line)
                            #be sure to add extra info (cluster id, datestamp, jobname
	    # import data to mongo
	    # cleanup 		
            return url_for('uploaded_file', filename=finalfilename)
    return '''
    <!doctype html>
    <title>Upload new File</title>
    <h1>Upload new File</h1>
    <form action="" method=post enctype=multipart/form-data>
      <p><input type=file name=file>
         <input type=submit value=Upload>
    </form>
    '''

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'],
                               filename)

if __name__ == '__main__':
	app.run(host='0.0.0.0')