import os
import sys
import pandas as pd
import requests
import simplejson
import logging
import copy
from datetime import datetime, timedelta
import sqlalchemy as sa
from sqlalchemy.ext.declarative import declarative_base

#import credentials from streampulse flask app config file, helper functions
# app_dir = '/home/aaron/sp'
app_dir = '/home/mike/git/streampulse/server_copy/sp'
os.chdir(app_dir)
import config as cfg
wrk_dir = app_dir + '/scheduled_scripts/USGS_data_retrieval'
os.chdir(wrk_dir)
from helper_funcs import parse_usgs_response, chunker_ingester

#configure database connection
pw = cfg.MYSQL_PW
db = sa.create_engine('mysql://root:{0}@localhost/sp'.format(pw))
session = sa.orm.Session(bind=db.engine) #for bulk insertion
Base = declarative_base() #for defining ORM
Base.metadata.bind = db #necessary for some reason
class Data(Base):

    __tablename__ = 'data'

    id = sa.Column(sa.Integer, primary_key=True)
    region = sa.Column(sa.String(10))
    site = sa.Column(sa.String(50))
    DateTime_UTC = sa.Column(sa.DateTime)
    variable = sa.Column(sa.String(50))
    value = sa.Column(sa.Float)
    flag = sa.Column(sa.Integer)
    upload_id = sa.Column(sa.Integer)

    def __init__(self, region, site, DateTime_UTC, variable, value, flag, upid):
        self.region = region
        self.site = site
        self.DateTime_UTC = DateTime_UTC
        self.variable = variable
        self.value = value
        self.flag = flag
        self.upload_id = upid

    def __repr__(self):
        return '<Data %r, %r, %r, %r, %r>' % (self.region, self.site,
        self.DateTime_UTC, self.variable, self.upload_id)
Base.metadata.create_all()

#configure logging
logging.basicConfig(filename='usgs_sync.log', level=logging.WARNING,
    format='%(asctime)s - %(levelname)s - %(message)s')

#define sites and corresponding variables to be synced here. explanation below:
#discharge, gage height, water temp, spec cond, nitrate+nitrite
#'00060', '00065', '00010', '00095', '99133'
regionsite = ['FL_ICHE2700',
    'FL_SF2500',
    'FL_SF2800',
    'FL_WS1500']
regionsite_update = copy.copy(regionsite)
variables = [['00010', '00095', '99133'],
    ['00010', '00095'],
    ['00010', '00095', '99133'],
    ['00010', '00095']]

#get site data from database
sitedf = pd.read_sql('select id, region, site, name, latitude, ' +\
    'longitude, usgs, addDate, embargo, site.by, contact, contactEmail, ' +\
    'firstRecord, lastRecord from site;', db.engine)

#assemble dict of gageid, name, vars and data coverage for each site
sitedf['regionsite'] = sitedf["region"].map(str) + "_" + sitedf["site"]
gageid = sitedf.loc[sitedf.regionsite.isin(regionsite)].usgs.tolist()
firstrec = sitedf.loc[sitedf.regionsite.isin(regionsite)].firstRecord.tolist()
firstrec = sitedf.loc[sitedf.regionsite.isin(regionsite)].firstRecord.dt.\
    strftime('%Y-%m-%d').tolist()
lastrec = sitedf.loc[sitedf.regionsite.isin(regionsite)].lastRecord.dt.\
    strftime('%Y-%m-%d').tolist()
sitedict = {}
for i in xrange(len(regionsite)):
    sitedict[gageid[i]] = (regionsite[i], variables[i],
        firstrec[i], lastrec[i])

#bring in records of which dates have already been collected for each site.
#omit sites that don't need to be synced
try:
    coverage = pd.read_csv('coverage_tracking.csv')
    coverage_file_found = True
except IOError:
    coverage_file_found = False
    logging.warning('No coverage tracking file found')

#assemble list of dataframes, one for each site-variable combo
gage_df_list = []
for g in gageid:

    site_name = sitedict[g][0]
    varcode_str = ','.join(sitedict[g][1])
    start_date_str = sitedict[g][2]
    end_date_str = sitedict[g][3]
    start_date = datetime.strptime(start_date_str, '%Y-%m-%d')
    end_date = datetime.strptime(end_date_str, '%Y-%m-%d')

    #adjust start and end dates for data pull so we dont get redundant records
    if coverage_file_found:
        coverage_start, coverage_end = coverage.loc[coverage.site == site_name,
            ['coverage_start', 'coverage_end']].squeeze().tolist()
        coverage_start = datetime.strptime(coverage_start, '%Y-%m-%d')
        coverage_end = datetime.strptime(coverage_end, '%Y-%m-%d')
        retrieve_earlier = True if start_date < coverage_start else False
        retrieve_later = True if end_date > coverage_end else False

        if retrieve_earlier and not retrieve_later:
            logging.warning('retrieving earlier records for ' + g)
            end_date_str = str(coverage_start - timedelta(days=1))[0:10]
        elif not retrieve_earlier and retrieve_later:
            logging.warning('retrieving later records for ' + g)
            start_date_str = str(coverage_end + timedelta(days=1))[0:10]
        elif retrieve_earlier and retrieve_later:
            logging.warning('request to retrieve earlier and later; ' +\
                'just doing later for now; will get earlier tomorrow: ' + g)
            start_date_str = str(coverage_end + timedelta(days=1))[0:10]
        else:
            logging.warning('nothing to do for ' + g)
            regionsite_update = [x for x in regionsite_update if x != site_name]
    else:
        logging.warning('retrieving full span of records for ' + g)

    #request usgs water service data in universal time.
    #T01:15 makes it line up with our datasets
    url = "https://nwis.waterservices.usgs.gov/nwis/iv/?format=json&sites=" + \
        g + "&startDT=" + start_date_str + "T01:15Z&endDT=" + end_date_str + \
        "T23:59Z&parameterCd=" + varcode_str + "&siteStatus=all"
    r = requests.get(url)
    if r.status_code != 200:
        logging.error('USGS server error: ' + g)
    usgs_raw = r.json()


    xx = map(lambda x: parse_usgs_response(x, usgs_raw=usgs_raw, g=g),
        range(len(usgs_raw['value']['timeSeries'])))

    #merge dfs for each variable into a single df and then append to list
    gage_df = [k.values()[0] for k in xx if k.keys()[0] == g]
    gage_df = reduce(lambda x,y: x.merge(y, how='outer', left_index=True,
        right_index=True), gage_df)
    gage_df = gage_df.sort_index().apply(lambda x: pd.to_numeric(x,
        errors='coerce')).resample('15Min').mean()
    gage_df['site'] = site_name
    gage_df_list.append(gage_df.reset_index())

#combine list of dfs into one df; final organizing, supplementing, formatting
out = pd.concat(gage_df_list)
out = out.set_index(['DateTime_UTC', 'site'])
out.columns.name = 'variable'
out = out.stack()
out.name = "value"
out = out.reset_index()
out[['region','site']] = out['site'].str.split("_", expand=True)
out = out[['region','site','DateTime_UTC','variable','value']]
out['flag'] = None
out['upload_id'] = -901

#write to database in chunks of 100,000 records each
chunker_ingester(out)
session.commit()

#update variableList and coverage columns in site table
for u in regionsite_update:
    with open('../../site_update_stored_procedure.sql', 'r') as f:
        t = f.read()
    t = t.replace('RR', u.split('_')[0])
    t = t.replace('SS', u.split('_')[1])

    session.execute(t)
    session.execute('CALL update_site_table();')

session.close()

#store record of which time ranges have been pulled from usgs for each site
coverage_tracking = pd.DataFrame({'site': regionsite,
    'coverage_start': firstrec, 'coverage_end': lastrec})
coverage_tracking = coverage_tracking[['site', 'coverage_start', 'coverage_end']]
coverage_tracking.to_csv('coverage_tracking.csv', index=False)
