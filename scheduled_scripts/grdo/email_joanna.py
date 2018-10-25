# os.chdir('/home/mike/git/streampulse/server_copy/sp')
import os
import sys
import MySQLdb
import pandas as pd
import datetime
#for emailing:
import smtplib
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart

wrk_dir = '/home/aaron/sp'
#wrk_dir = '/home/mike/git/streampulse/server_copy/sp'
sys.path.insert(0, wrk_dir)
os.chdir(wrk_dir)
import config as cfg

mysql_pw = cfg.MYSQL_PW
gmail_pw = cfg.GRDO_GMAIL_PW

db = MySQLdb.connect(host="localhost", user="root", passwd=mysql_pw, db="sp")
cur = db.cursor()

#get number of users, observations, and sites to post on SP landing page
cur.execute("select * from grdo;")
uploads = cur.fetchall()
uploads = pd.DataFrame(list(uploads))
uploads.drop(0, axis=1, inplace=True)
uploads.columns = ['name', 'email', 'addDate', 'embargo', 'notes', 'dataFiles', 'metaFiles']

db.close()

uploads.to_csv('scheduled_scripts/grdo/grdo_uploads.csv', index=False, encoding='utf-8')

rn = datetime.datetime.utcnow()
new_rows = [(rn - x).days <= 7 for x in uploads.addDate]
new_submissions = str(sum(new_rows))

#begin message, add body text
msg = MIMEMultipart()
with open('scheduled_scripts/grdo/email_text.txt', 'rb') as fp:
    email_text = fp.read()
    email_text = email_text % new_submissions
    # msg = MIMEText(email_text) #would use this if it were not a multipart message
    msg.attach(MIMEText(email_text))

#compose message
msg['Subject'] = 'GRDO uploads'
msg['From'] = 'grdouser@gmail.com'
msg['To'] = 'joanna.r.blaszczak@gmail.com'
with open('scheduled_scripts/grdo/grdo_uploads.csv', 'rb') as fp:
    csv = MIMEApplication(fp.read(), Name='grdo_uploads.csv')
csv['Content-Disposition'] = 'attachment; filename="grdo_uploads.csv"'
msg.attach(csv)

# Send the message via local SMTP server if i ever set one up
# s = smtplib.SMTP('localhost')
# s.sendmail('vlahm13@gmail.com', ['joanna.r.blaszczak@gmail.com'], msg.as_string())

#log in to gmail, send email
server = smtplib.SMTP('smtp.gmail.com', 587)
server.ehlo()
server.starttls()
server.login("grdouser@gmail.com", gmail_pw)
server.sendmail('grdouser@gmail.com', ['joanna.r.blaszczak@gmail.com'],
    msg.as_string())
server.quit()
