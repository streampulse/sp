import config as cfg
from flask_login import current_user
from datetime import datetime, timedelta
import smtplib
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart

def email_msg(txt, subj, recipient, header=True, render_html=False):

    gmail_pw = cfg.GRDO_GMAIL_PW

    if header:
        cur_user = str(current_user.get_id()) if current_user else 'anonymous'
        deets = datetime.now().strftime('%Y-%m-%d %H:%M:%S') +\
            '; userID=' + cur_user + '\n'

        txt = deets + txt

    #compose email
    msg = MIMEMultipart()
    
    if render_html:
        msg.attach(MIMEText(txt, 'html'))
    else:
        msg.attach(MIMEText(txt))

    msg['Subject'] = subj
    msg['From'] = 'grdouser@gmail.com'
    msg['To'] = recipient

    #log in to gmail, send email
    server = smtplib.SMTP('smtp.gmail.com', 587)
    server.ehlo()
    server.starttls()
    server.login("grdouser@gmail.com", gmail_pw)
    server.sendmail('grdouser@gmail.com', [recipient],
        msg.as_string())
    server.quit()
