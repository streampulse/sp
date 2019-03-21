# import sys
# sys.path.insert(0, '/home/mike/git/streampulse/server_copy/sp')

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timedelta
import pandas as pd
import os
import zipfile
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
    " from site where concat(region, '_', site) not in ('" + "','".join(embargoed_sites) +\
    "') into outfile '/var/lib/mysql-" +\
    "files/all_basic_site_data.csv' fields terminated by ',' enclosed by '\"'" +\
    " lines terminated by '\\n';")

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

sitedata['ds'] = 'StreamPULSE-Leveraged'
sitedata.loc[sitedata.regionsite.isin(core_sites), 'ds'] = 'StreamPULSE-Core'
sitedata.loc[sitedata.ds_ref == -900, 'ds'] = 'https://data.neonscience.org/home'
sitedata.loc[sitedata.ds_ref == -902, 'ds'] = 'https://www.nature.com/articles/sdata2018292'
sitedata.insert(loc=3, column='dataSource', value=sitedata.ds)

#clean up, export, zip
sitedata = sitedata.drop(['ds_ref', 'regionsite', 'ds'], axis=1)
basic_site_data_path = app.config['BULK_DNLD_FOLDER'] + '/all_basic_site_data.csv'
sitedata.to_csv(basic_site_data_path, index=False, encoding='utf-8')

zf = zipfile.ZipFile(basic_site_data_path + '.zip', 'w')
zf.write(basic_site_data_path, 'all_basic_site_data.csv', zipfile.ZIP_DEFLATED)
zf.close()


# sitecols = db.engine.execute("SELECT group_concat(\"'\", column_name, \"'\")" +\
#     "FROM information_schema." +\
#     "columns WHERE table_schema = 'sp' AND table_name = 'site';")
# sitecols = list(sitecols)[0][0]

#export all public sp data (will move and zip later in shell script)
db.engine.execute("select 'regionID','siteID','dateTimeUTC','variable','value'" +\
    ",'flagID','flagComment' union all select data.region, data.site, " +\
    "data.DateTime_UTC, data.variable, data.value, " +\
    "flag.flag, flag.comment from data left join flag on data.flag=flag.id " +\
    "where data.upload_id >= 0 and concat(data.region, '_', data.site) not " +\
    "in ('" + "','".join(embargoed_sites) + "') into outfile " +\
    "'/var/lib/mysql-files/all_sp_data.csv' fields terminated by ',' " +\
    "enclosed by '\"' lines terminated by '\\n';")

#export all neon data (will move and zip later in shell script)
db.engine.execute("select 'regionID','siteID','dateTimeUTC','variable','value'" +\
    ",'flagID','flagComment' union all select data.region, data.site, " +\
    "data.DateTime_UTC, data.variable, data.value, " +\
    "flag.flag, flag.comment from data left join flag on data.flag=flag.id " +\
    "where data.upload_id = -900 into outfile " +\
    "'/var/lib/mysql-files/all_neon_data.csv' fields terminated by ',' " +\
    "enclosed by '\"' lines terminated by '\\n';")

#export all powell data (this need not be repeated; powell is static)
# db.engine.execute("select 'regionID','siteID','dateTimeUTC','variable','value'" +\
#     ",'flagID','flagComment' union all select region, site, " +\
#     "DateTime_UTC, variable, value from powell into outfile" +\
#     "'/var/lib/mysql-files/all_powell_data.csv' fields terminated by ',' " +\
#     "enclosed by '\"' lines terminated by '\\n';")

#export all grab data (will move and zip later in shell script)
db.engine.execute("select 'regionID','siteID','dateTimeUTC','variable','value'" +\
    ",'method','writeInMethod','methodDetail'" +\
    ",'flagID','flagComment' union all select grabdata.region, grabdata.site, " +\
    "grabdata.DateTime_UTC, grabdata.variable, grabdata.value, grabdata.method, " +\
    "grabdata.write_in, grabdata.addtl, " +\
    "grabflag.flag, grabflag.comment from grabdata left join grabflag on " +\
    "grabdata.flag=grabflag.id into outfile " +\
    "'/var/lib/mysql-files/all_grab_data.csv' fields terminated by ',' " +\
    "enclosed by '\"' lines terminated by '\\n';")
