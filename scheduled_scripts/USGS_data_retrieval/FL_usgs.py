import os
import sys
import MySQLdb
import pandas as pd
import requests
import simplejson
import logging
# wrk_dir = '/home/aaron/sp'
app_dir = '/home/mike/git/streampulse/server_copy/sp'
sys.path.insert(0, app_dir)
os.chdir(app_dir)
import config as cfg
wrk_dir = '/home/mike/git/streampulse/server_copy/sp/scheduled_scripts/USGS_data_retrieval'
os.chdir(wrk_dir)
# from parse_usgs_response import parse_usgs_response

#configure logging
logging.basicConfig(filename='usgs_sync.log', level=logging.ERROR,
    format='%(asctime)s - %(levelname)s - %(message)s')

regionsite = ['FL_ICHE2700',
    'FL_SF2500',
    'FL_SF2800',
    'FL_WS1500']
variables = [['00010', '00095', '99133'],
    ['00010', '00095'],
    ['00010', '00095', '99133'],
    ['00010', '00095']]

# startDate='2017-11-01'; endDate='2017-12-01'
#discharge, gage height, water temp, spec cond, nitrate
# variables=['00060', '00065', '00010', '00095']
# variables=['00010', '00095', '99133']

#get site data from database
pw = cfg.MYSQL_PW
db = MySQLdb.connect(host="localhost", user="root", passwd=pw, db="sp")
cur = db.cursor()

cur.execute('select id, region, site, name, latitude, ' +\
    'longitude, usgs, addDate, embargo, site.by, contact, contactEmail, ' +\
    'firstRecord, lastRecord from site;')
sqlresp = cur.fetchall()
sitedf = pd.DataFrame(list(sqlresp), columns=['id','region','site','name',
    'latitude','longitude','usgs','addDate','embargo','by','contact',
    'contactEmail','firstRecord','lastRecord'])

#assemble dict of gageid, name, vars and data coverage for each site
sitedf['regionsite'] = sitedf["region"].map(str) + "_" + sitedf["site"]
gageid = sitedf.loc[sitedf.regionsite.isin(regionsite)].usgs.tolist()
firstrec = sitedf.loc[sitedf.regionsite.isin(regionsite)].firstRecord.tolist()
lastrec = sitedf.loc[sitedf.regionsite.isin(regionsite)].lastRecord.tolist()
sitedict = {}
for i in xrange(len(regionsite)):
    sitedict[gageid[i]] = (regionsite[i], variables[i],
        firstrec[i], lastrec[i])

# gageidstr = ",".join(gageid)
# if(len(gageid) == 0 or gageidstr is None):
#     logging.error('No gage ids')
# varcodestr = ",".join(variables)


def parse_usgs_response(i, usgs_raw):

    ts = usgs_raw['value']['timeSeries'][i]
    usgst = pd.read_json(simplejson.dumps(ts['values'][0]['value']))
    vcode = ts['variable']['variableCode'][0]['value']

    if vcode == '00010': #water tempSpecCond_mScm
        colnm = 'WaterTemp_C'
        if usgst.empty:
            logging.error('watertemp df is empty: ' + g)
    elif vcode == '00095': #spec cond
        colnm = 'SpecCond_mScm'
        if usgst.empty:
            logging.error('spcond df is empty: ' + g)
    elif vcode == '99133': #nitrate
        colnm = 'Nitrate_mgL'
        if usgst.empty:
            logging.error('nitrate df is empty: ' + g)
    else:
        logging.error('vcode other than watertemp, spcond, nitrate')

    site_id = ts['sourceInfo']['siteCode'][0]['value']
    variable_df = usgst[['dateTime',
        'value']].rename(columns={'dateTime': 'DateTime_UTC',
        'value': colnm}).set_index(["DateTime_UTC"])
    out = {site_id: variable_df}

    return out


# g = gageid[0]
gage_df_list = []
for g in gageid:

    varcodestr = ','.join(sitedict[g][1])
    start_date = sitedict[g][2].strftime('%Y-%m-%d')
    end_date = sitedict[g][3].strftime('%Y-%m-%d')

    #request usgs water service data in universal time (T01:15 makes it line up with our datasets)
    url = "https://nwis.waterservices.usgs.gov/nwis/iv/?format=json&sites=" + \
        g + "&startDT=" + start_date + "T01:15Z&endDT=" + end_date + \
        "T23:59Z&parameterCd=" + varcodestr + "&siteStatus=all"
    r = requests.get(url)
    if r.status_code != 200:
        logging.error('USGS server error: ' + g)
    usgs_raw = r.json()

    xx = map(lambda x: parse_usgs_response(x, usgs_raw=usgs_raw),
        range(len(usgs_raw['value']['timeSeries'])))

    # for g in gageid:
    gage_df = [k.values()[0] for k in xx if k.keys()[0] == g]
    gage_df = reduce(lambda x,y: x.merge(y, how='outer', left_index=True,
        right_index=True), gage_df)
    gage_df = gage_df.sort_index().apply(lambda x: pd.to_numeric(x,
        errors='coerce')).resample('15Min').mean()
    gage_df['site'] = sitedict[g][0]
    gage_df_list.append(gage_df.reset_index())

out = pd.concat(gage_df_list)
out = out.set_index(['DateTime_UTC', 'site'])
out.columns.name = 'variable'
out = out.stack()
out.name = "value"
out = out.reset_index()
out[['region','site']] = out['site'].str.split("_", expand=True)
out = out[['DateTime_UTC','region','site','variable','value']]
out.head()

return out


db.close()
