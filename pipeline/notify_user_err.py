import sys
import os
app_dir = '/home/aaron/sp'
#app_dir = '/home/mike/git/streampulse/server_copy/sp'
sys.path.insert(0, app_dir)
os.chdir(app_dir)
from helpers import email_msg
from sys import argv

script_name, notificationEmail, tmpcode, region, site, report_filenames = argv

email_template = 'static/email_templates/error_notification.txt'
with open(email_template, 'r') as e:
    email_body = e.read()
email_body = email_body.format(filename=report_filenames)

tmpurl = 'https://data.streampulse.org/pipeline-complete-' + tmpcode
#tmpurl = 'http://127.0.0.1:5000/pipeline-complete-' + tmpcode

email_msg(email_body, 'StreamPULSE Error', notificationEmail,
    header=False, render_html=True)
