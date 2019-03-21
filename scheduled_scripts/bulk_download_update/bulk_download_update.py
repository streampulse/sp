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
app.config['BULK_DNLD_FOLDER'] = cfg.BULK_DNLD_FOLDER
app.config['SECURITY_PASSWORD_SALT'] = cfg.SECURITY_PASSWORD_SALT

db = SQLAlchemy(app)

#get list of embargoed sites
# embargo_df = pd.read_sql('select concat(region, "_", site) as regionsite, ' +\
#     'embargo, addDate from site;', db.engine)
# embargoed_sites = embargo_df.loc[embargo_df['embargoDaysRemaining'] > 0,
#     'regionsite'].tolist()



#get all site table data except for id column; extract list of embargoed sites
sitedata = pd.read_sql("select region as regionID, site as siteID, name as siteName," +\
    "latitude, longitude, usgs as USGSgageID, addDate, `by` as ds_ref, " +\
    "embargo as embargoDaysRemaining, contact, contactEmail, firstRecord, " +\
    "lastRecord, variableList, grabVarList, concat(region, '_', site) as " +\
    "regionsite from site;", db.engine)
# #export site data table for all public sites
# db.engine.execute("select 'regionID','siteID','siteName','latitude','longitude'" +\
#     ",'USGSgageID','addDate','source','contact','contactEmail','firstRecord','lastRecord'" +\
#     ",'variableList','grabVarList' union all " +\
#     "select region,site,name,latitude,longitude,usgs,addDate,by" +\
#     "contact,contactEmail,firstRecord,lastRecord,variableList,grabVarList" +\
#     " from site where concat(region, '_', site) not in ('" + "','".join(embargoed_sites) +\
#     "') into outfile '/var/lib/mysql-" +\
#     "files/all_basic_site_data.csv' fields terminated by ',' enclosed by '\"'" +\
#     " lines terminated by '\\n';")

embargoed_sites = sitedata.loc[sitedata['embargoDaysRemaining'] > 0,
    'regionsite'].tolist()

#convert embargo duration and addDate to days of embargo remaining
timedeltas = datetime.utcnow() - sitedata.addDate
days_past = timedeltas.map(lambda x: int(x.total_seconds() / 60 / 60 / 24))
sitedata['embargoDaysRemaining'] = sitedata['embargoDaysRemaining'] * 365 - days_past
sitedata.loc[sitedata['embargoDaysRemaining'] <= 0, 'embargoDaysRemaining'] = 0

#fill out datasource column
core_df = pd.read_csv('static/sitelist.csv')
core_sites = list(core_df["REGIONID"].map(str) + "_" + core_df["SITEID"])

sitedata['dataSource'] = 'StreamPULSE-Leveraged'
sitedata.loc[sitedata.regionsite.isin(core_sites),
    'dataSource'] = 'StreamPULSE-Core'
sitedata.loc[sitedata.ds_ref == -900,
    'dataSource'] = 'https://data.neonscience.org/home'
sitedata.loc[sitedata.ds_ref == -902,
    'dataSource'] = 'https://www.nature.com/articles/sdata2018292'



# sitecols = db.engine.execute("SELECT group_concat(\"'\", column_name, \"'\")" +\
#     "FROM information_schema." +\
#     "columns WHERE table_schema = 'sp' AND table_name = 'site';")
# sitecols = list(sitecols)[0][0]

# db.engine.execute("select data.region, data.site, data.DateTime_UTC, data.variable,
# data.value, data.flag as flagID, data.upload_id, flag.flag, flag.comment from data left
#  join flag on data.flag=flag.id where upload_id >= 0 and data.region not in ('SE','KS','AT','IN')
#   and data.site not like 'Neuse%' and data.site not like 'NHC_' and data.site not like 'MC_'
#   and data.site not in ('751MUD', 'Carapa', 'ArbSeep') into outfile
#   '/var/lib/mysql-files/all_unembargoed_20190314.csv' fields terminated by ','
#   enclosed by '"' lines terminated by '\n';")
