import os
from time import strftime
from flask import Flask, request, redirect, url_for, send_from_directory
from werkzeug import secure_filename

UPLOAD_FOLDER = 'uploads'
ALLOWED_EXTENSIONS = set(['tgz'])

app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

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
	    finalfilename=filename+'-'+strftime("%Y%m%dT%H%M%S")
            file.save(os.path.join(app.config['UPLOAD_FOLDER'], finalfilename))
            # for browser, add 'redirect' function on top of 'url_for'
            # TODO: 
            # - set dateofrun = filename|cut -f2 -d"."|cut -f2 -d"-"
            # - extract .tgz file
            # - set recordID = guid
            # - loop through subdirectories
            # - set benchmark = dirname
            # - split each output file using logic in viewresult.sh
            # - import the generated json file into guid->date->benchmark->dirname
            
            return url_for('uploaded_file',
                                    filename=finalfilename)
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

