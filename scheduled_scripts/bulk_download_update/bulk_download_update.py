# import sys
# sys.path.insert(0, '/home/mike/git/streampulse/server_copy/sp')

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timedelta
import pandas as pd
import os
import config as cfg


app = Flask(__name__)

app.config['SECRET_KEY'] = cfg.SECRET_KEY
app.config['SQLALCHEMY_DATABASE_URI'] = cfg.SQLALCHEMY_DATABASE_URI
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = cfg.SQLALCHEMY_TRACK_MODIFICATIONS
app.config['UPLOAD_FOLDER'] = cfg.UPLOAD_FOLDER
app.config['META_FOLDER'] = cfg.META_FOLDER
app.config['GRAB_FOLDER'] = cfg.GRAB_FOLDER
app.config['GRAB_FOLDER'] = cfg.GRAB_FOLDER
app.config['RESULTS_FOLDER'] = cfg.RESULTS_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 700 * 1024 * 1024 # originally set to 16 MB; now 700
app.config['SECURITY_PASSWORD_SALT'] = cfg.SECURITY_PASSWORD_SALT

db = SQLAlchemy(app)

sitedata = pd.read_sql('select region as Region, site as Site, name as ' +\
    'Name, latitude as Lat, longitude as Lon, contact as Contact, ' +\
    'contactEmail as Email, usgs as `USGS gage`, `by`,' +\
    'embargo as EmbargoDays, addDate as AddDate, variableList as Variables, ' +\
    'firstRecord, lastRecord from site;', db.engine)

sitecounts = pd.read_sql("select region as Region, site as Site," +\
    " count(*) as DataCount from data group by Region, Site", db.engine)

sitedata = pd.merge(sitedata, sitecounts, on=['Region', 'Site'], how='left')

#calculate remaining embargo days
timedeltas = datetime.utcnow() - sitedata.AddDate
days_past = timedeltas.map(lambda x: int(x.total_seconds() / 60 / 60 / 24))
sitedata['EmbargoDays'] = sitedata['EmbargoDays'] * 365 - days_past
sitedata.loc[sitedata['EmbargoDays'] <= 0, 'EmbargoDays'] = 0

#sort, filter, export
sitedata = sitedata.fillna('-').sort_values(['EmbargoDays', 'Region', 'Site'],
    ascending=False)
sitedata = sitedata.loc[~sitedata.by.isin([-900, -902]),]
sitedata = sitedata.drop(['Lat', 'Lon', 'USGS gage', 'by', 'firstRecord',
    'lastRecord'], axis=1)
sitedata = sitedata[['Region','Site','Name','EmbargoDays','DataCount','Coverage',
    'AddDate','Contact','Email','Variables']]
sitedata.to_csv('~/Desktop/embargo_summary.csv', index=False, encoding='utf-8')
