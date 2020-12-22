import sys
import os
app_dir = '/home/aaron/sp'
#app_dir = '/home/mike/git/streampulse/server_copy/sp'
sys.path.insert(0, app_dir)
os.chdir(app_dir)
from helpers import email_msg
from sys import argv

script_name, notificationEmail, tmpcode, region, site, report_filenames, tmpfile, files_to_remove = argv


email_template = 'static/email_templates/pipeline_complete.txt'
with open(email_template, 'r') as e:
    email_body = e.read()

tmpurl = 'https://data.streampulse.org/pipeline-complete-' + tmpcode
#tmpurl = 'http://127.0.0.1:5000/pipeline-complete-' + tmpcode
email_body = email_body % (region, site, tmpurl, tmpurl)

email_msg(email_body, 'StreamPULSE upload complete', notificationEmail,
    header=False, render_html=True)
