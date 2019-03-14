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

#import credentials from streampulse flask app config file
# app_dir = '/home/aaron/sp'
app_dir = '/home/mike/git/streampulse/server_copy/sp'
sys.path.insert(0, app_dir)
import config as cfg
wrk_dir = app_dir + '/scheduled_scripts/USGS_data_retrieval'
sys.path.insert(0, wrk_dir)

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

#configure logging (all logs are warning or error level, just to avoid log clutter)
logging.basicConfig(filename='usgs_sync.log', level=logging.WARNING,
    format='%(asctime)s - %(levelname)s - %(message)s')

#define sites and corresponding variables to be synced here. var codes:
#discharge, gage height, water temp, spec cond, nitrate+nitrite
#00060,     00065,       00010,      00095,     99133
#should have put all this in one dict, but alas. happy cross-referencing.
regionsite = ['FL_ICHE2700',
    'FL_SF2500',
    'FL_SF2800',
    'FL_WS1500',
    'FL_SF700',
    'FL_NR1000',
    'AZ_SC',
    'AZ_OC',
    'AZ_WB',
    'AZ_LV',
    'AZ_AF',
    'AZ_MV',
    'NC_Eno',
    'NC_ColeMill',
    'PR_Icacos',
    'CT_Unio',
    'CT_FARM',
    'VT_Pass',
    'CT_BUNN',
    'CT_STIL',
    'CT_HUBB',
    'VT_SLPR',
    'VT_POPE',
    'VT_MOOS',
    'WI_BEC',
    'WI_BRW',
    'RI_CorkBrk',
    'NH_GOF']

regionsite_update = copy.copy(regionsite)
variables = [['00010', '00095', '99133', '00060', '00065'],
    ['00010', '00095', '00060', '00065'],
    ['00010', '00095', '99133', '00060', '00065'],
    ['00010', '00095', '00060', '00065'],
    ['00060', '00065'],
    ['00060', '00065'],
    ['00060', '00065'], #SC
    ['00060', '00065'], #OC
    ['00060', '00065'], #WB
    ['00060', '00065'], #LV
    ['00060', '00065'], #AF
    ['00060', '00065'], #MV
    ['00060', '00065'], #Eno
    ['00065'], #ColeMill
    ['00060', '00065'], #Icacos
    ['00060', '00065'], #Unio
    ['00060', '00065', '00010', '00095'], #FARM (actually has a lot more)
    ['00060', '00065'], #Pass
    ['00060', '00065'], #BUNN
    ['00060', '00065', '00010', '00095'], #STIL (and more)
    ['00060', '00065'], #HUBB
    ['00060', '00065'], #SLPR
    ['00060', '00065'], #POPE
    ['00060', '00065'], #MOOS
    ['00060', '00065', '00010', '00095'], #BEC (and more)
    ['00060', '00065', '00010', '00095'], #BRW (and more)
    ['00060', '00065', '00010', '00095'], #CorkBrk
    ['00060', '00065']] #GOF

def parse_usgs_response(i, usgs_raw, g):

    ts = usgs_raw['value']['timeSeries'][i]
    usgst = pd.read_json(simplejson.dumps(ts['values'][0]['value']))
    vcode = ts['variable']['variableCode'][0]['value']

    if vcode == '00010': #water tempSpecCond_mScm
        colnm = 'WaterTemp_C'
        if usgst.empty:
            logging.error(' watertemp df is empty: ' + g)
            #these errors get handled in usgs_sync.py and result in continuation
            raise ValueError('continue')
        else:
            logging.warning(' retrieving watertemp for ' + g)
    elif vcode == '00095': #spec cond
        colnm = 'SpecCond_uScm'
        if usgst.empty:
            logging.error(' spcond df is empty: ' + g)
            raise ValueError('continue')
        else:
            logging.warning(' retrieving spcond for ' + g)
    elif vcode == '99133': #nitrate
        colnm = 'Nitrate_mgL'
        if usgst.empty:
            logging.error(' nitrate df is empty: ' + g)
            raise ValueError('continue')
        else:
            logging.warning(' retrieving nitrate for ' + g)
    elif vcode=='00060': # discharge
        colnm = 'Discharge_m3s'
        if usgst.empty:
            logging.error(' discharge df is empty: ' + g)
            raise ValueError('continue')
        else:
            logging.warning(' retrieving discharge for ' + g)
            usgst.value = usgst.value / 35.3147
    elif vcode=='00065':
        colnm = 'Level_m'
        if usgst.empty:
            logging.error(' level df is empty: ' + g)
            raise ValueError('continue')
        else:
            logging.warning(' retrieving level for ' + g)
            usgst.value = usgst.value / 3.28084
    else:
        logging.error('vcode other than watertemp, spcond, nitrate, disch, level')
        raise ValueError('continue')

    site_id = ts['sourceInfo']['siteCode'][0]['value']
    variable_df = usgst[['dateTime',
        'value']].rename(columns={'dateTime': 'DateTime_UTC',
        'value': colnm}).set_index(["DateTime_UTC"])
    out = {site_id: variable_df}

    return out

def chunker_ingester(df, chunksize=100000):

    #determine chunks based on number of records (chunksize)
    n_full_chunks = df.shape[0] / chunksize
    partial_chunk_len = df.shape[0] % chunksize

    #convert directly to dict if small enough, otherwise do it chunkwise
    if n_full_chunks == 0:
        xdict = df.to_dict('records')
        session.bulk_insert_mappings(Data, xdict) #ingest all records
    else:
        for i in xrange(n_full_chunks):
            chunk = df.head(chunksize)
            df = df.drop(df.head(chunksize).index)
            chunk = chunk.to_dict('records')
            session.bulk_insert_mappings(Data, chunk)

        if partial_chunk_len:
            lastchunk = df.to_dict('records')
            session.bulk_insert_mappings(Data, lastchunk)
