import sys
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timedelta
import pandas as pd
import os
import re
import zipfile

app_dir = '/home/aaron/sp'
#app_dir = '/home/mike/git/streampulse/server_copy/sp'
sys.path.insert(0, app_dir)
os.chdir(app_dir)
import config as cfg

app = Flask(__name__)

app.config['SECRET_KEY'] = cfg.SECRET_KEY
app.config['SQLALCHEMY_DATABASE_URI'] = cfg.SQLALCHEMY_DATABASE_URI
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = cfg.SQLALCHEMY_TRACK_MODIFICATIONS
app.config['META_FOLDER'] = cfg.META_FOLDER
app.config['REACH_CHAR_FOLDER'] = cfg.REACH_CHAR_FOLDER
app.config['RESULTS_FOLDER'] = cfg.RESULTS_FOLDER
app.config['BULK_DNLD_FOLDER'] = cfg.BULK_DNLD_FOLDER
app.config['SECURITY_PASSWORD_SALT'] = cfg.SECURITY_PASSWORD_SALT

db = SQLAlchemy(app)

def zipfile_listdir_recursive(dir_name):

    fileList = []
    for file in os.listdir(dir_name):
        dirfile = os.path.join(dir_name, file)

        if os.path.isfile(dirfile):
            fileList.append(dirfile)
        elif os.path.isdir(dirfile):
            fileList.extend(zipfile_listdir_recursive(dirfile))

    return fileList

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
os.remove(basic_site_data_path)


# sitecols = db.engine.execute("SELECT group_concat(\"'\", column_name, \"'\")" +\
#     "FROM information_schema." +\
#     "columns WHERE table_schema = 'sp' AND table_name = 'site';")
# sitecols = list(sitecols)[0][0]

#export all public sp data (will move and zip later in shell script)
db.engine.execute("select 'regionID','siteID','dateTimeUTC','variable','value'" +\
    ",'flagID','flagComment' union all select data.region, data.site, " +\
    "data.DateTime_UTC, data.variable, data.value, " +\
    "flag.flag, flag.comment from data left join flag on data.flag=flag.id " +\
    "where (data.upload_id >= 0 or data.upload_id=-901) and concat(data.region, '_', data.site) not " +\
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

##export all powell data (this need not be repeated; powell is static)
#db.engine.execute("select 'regionID','siteID','dateTimeUTC','variable','value'" +\
#    " union all select region, site, " +\
#    "DateTime_UTC, variable, value from powell into outfile" +\
#    "'/var/lib/mysql-files/all_powell_data.csv' fields terminated by ',' " +\
#    "enclosed by '\"' lines terminated by '\\n';")

#export all grab data (will move and zip later in shell script)
db.engine.execute("select 'regionID','siteID','dateTimeUTC','variable','value'" +\
    ",'method','writeInMethod','methodDetail'" +\
    ",'flagID','flagComment' union all select grabdata.region, grabdata.site, " +\
    "grabdata.DateTime_UTC, grabdata.variable, grabdata.value, grabdata.method, " +\
    "grabdata.write_in, grabdata.addtl, " +\
    "grabflag.flag, grabflag.comment from grabdata left join grabflag on " +\
    "grabdata.flag=grabflag.id where concat(grabdata.region, '_', grabdata.site) not " +\
    "in ('" + "','".join(embargoed_sites) + "') into outfile " +\
    "'/var/lib/mysql-files/all_grab_data.csv' fields terminated by ',' " +\
    "enclosed by '\"' lines terminated by '\\n';")

#collect all site metadata text files and zip
metafolder = app.config['META_FOLDER']
writefiles = zipfile_listdir_recursive(metafolder)
rel_wfs = [re.match(metafolder + '/(.*)', f).group(1) for f in writefiles]
zf = zipfile.ZipFile(app.config['BULK_DNLD_FOLDER'] +\
    '/all_supplementary_site_metadata.zip', 'w')
for i in xrange(len(writefiles)):
    zf.write(writefiles[i], 'all_supplementary_site_metadata/' + rel_wfs[i])
zf.close()

#collect all reach characterization data files and zip
reachcharfolder = app.config['REACH_CHAR_FOLDER']
writefiles = zipfile_listdir_recursive(reachcharfolder)
rel_wfs = [re.match(reachcharfolder + '/(.*)', f).group(1) for f in writefiles]
zf = zipfile.ZipFile(app.config['BULK_DNLD_FOLDER'] +\
    '/all_reach_characterization_datasets.zip', 'w')
for i in xrange(len(writefiles)):
    zf.write(writefiles[i], 'all_reach_characterization_datasets/' + rel_wfs[i])
zf.close()

#export all model summary data
# modelcols = db.engine.execute("SELECT group_concat(\"'\", column_name, \"'\")" +\
#     "FROM information_schema." +\
#     "columns WHERE table_schema = 'sp' AND table_name = 'results';")
# modelcols = list(modelcols)[0][0]
# modelcols = modelcols.replace("'", "")
db.engine.execute("select 'region','site','start_date','end_date'," +\
    "'requested_variables','year','run_finished','model','method'," +\
    "'engine','rm_flagged','used_rating_curve','pool','proc_err','obs_err'" +\
    ",'proc_acor','ode_method','deficit_src','interv','fillgaps'," +\
    "'estimate_areal_depth','O2_GOF','GPP_95CI','ER_95CI','prop_pos_ER'," +\
    "'prop_neg_GPP','ER_K600_cor','coverage','kmax','current_best' "
    "union all select region,site,start_date,end_date,requested_variables," +\
    "year,run_finished,model,method,engine,rm_flagged,used_rating_curve," +\
    "pool,proc_err,obs_err,proc_acor,ode_method,deficit_src,interv," +\
    "fillgaps,estimate_areal_depth,O2_GOF,GPP_95CI,ER_95CI,prop_pos_ER," +\
    "prop_neg_GPP,ER_K600_cor,coverage,kmax,current_best from model " +\
    "where concat(model.region, '_', model.site) not " +\
    "in ('" + "','".join(embargoed_sites) + "') into outfile" +\
    "'/var/lib/mysql-files/all_model_summary_data.csv' fields terminated by ',' " +\
    "enclosed by '\"' lines terminated by '\\n';")

#export all daily model results
db.engine.execute("select 'region','site','year','solar_date','GPP'," +\
    "'GPP_lower','GPP_upper','ER','ER_lower','ER_upper','K600','K600_lower'," +\
    "'K600_upper','msgs_fit','warnings','errors' union all select " +\
    "region,site,year,solar_date,GPP,GPP_lower,GPP_upper,ER,ER_lower," +\
    "ER_upper,K600,K600_lower,K600_upper,msgs_fit,warnings,errors from results" +\
    " where concat(results.region, '_', results.site) not " +\
    "in ('" + "','".join(embargoed_sites) + "')" +\
    " into outfile '/var/lib/mysql-files/all_daily_model_results.csv' " +\
    "fields terminated by ',' enclosed by '\"' lines terminated by '\\n';")

# #collect all streampulse+neon model outputs and zip
# modeloutfolder = app.config['RESULTS_FOLDER']
# writefiles = zipfile_listdir_recursive(modeloutfolder)
# rel_wfs = [re.match(modeloutfolder + '/(.*)', f).group(1) for f in writefiles]
# zf = zipfile.ZipFile(app.config['BULK_DNLD_FOLDER'] + '/all_sp_neon_model_outputs.zip', 'w')
# for i in xrange(len(writefiles)):
#     zf.write(writefiles[i], 'all_sp_neon_model_outputs/' + rel_wfs[i])
# zf.close()

#would then do the same for powell model outputs
#...
