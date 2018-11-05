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

regionsite=['FL_ICHE2700', 'FL_SF2500', 'FL_SF2800', 'FL_WS1500']
startDate='2017-11-01'; endDate='2017-12-01'
#discharge, gage height, water temp, spec cond, nitrate
# variables=['00060', '00065', '00010', '00095']
variables=['00010', '00095']

#get site data from database
pw = cfg.MYSQL_PW
db = MySQLdb.connect(host="localhost", user="root", passwd=pw, db="sp")
cur = db.cursor()

cur.execute('select id, region, site, name, latitude, ' +\
    'longitude, usgs, addDate, embargo, site.by, contact, contactEmail ' +\
    'from site;')
sqlresp = cur.fetchall()
sitedf = pd.DataFrame(list(sqlresp), columns=['id','region','site','name','latitude',
    'longitude','usgs','addDate','embargo','by','contact','contactEmail'])

#cross reference site names with associated usgs gages; prepare for usgs request
sitedf['regionsite'] = sitedf["region"].map(str) + "_" + sitedf["site"]
gageid = sitedf.loc[sitedf.regionsite.isin(regionsite)].usgs.tolist()
sitedict = dict(zip(gageid, regionsite))
gageid = [x for x in gageid if x is not None]
gageidstr = ",".join(gageid)
if(len(gageid) == 0 or gageidstr is None):
    logging.error('No gage ids')
varcodestr = ",".join(variables)

#request usgs water service data in universal time (T01:15 makes it line up with our datasets)
url = "https://nwis.waterservices.usgs.gov/nwis/iv/?format=json&sites=" + \
    gageidstr + "&startDT=" + startDate + "T01:15Z&endDT=" + endDate + \
    "T23:59Z&parameterCd=" + varcodestr + "&siteStatus=all"
r = requests.get(url)
if r.status_code != 200:
    logging.error('USGS server error?')
usgs_raw = r.json()

# a = ', '.join("%s=%r" % (key,val) for (key,val) in usgs_raw.iteritems())
# b = a.split('02321000')
# len(b)
# b[0]
# len(b[1])
# len(b[2])
# len(b[3])

# for i in xrange(len(usgs_raw['value']['timeSeries'])): #number of sites*vars
def parse_usgs_response(i, usgs_raw):

    ts = usgs_raw['value']['timeSeries'][i]
    usgst = pd.read_json(simplejson.dumps(ts['values'][0]['value']))
    vcode = ts['variable']['variableCode'][0]['value']

    # if vcode=='00060': # discharge
    #     colnm = 'USGSDischarge_m3s'
    #     if usgst.empty: #return empty df in dict
    #         out = {ts['sourceInfo']['siteCode'][0]['value']:
    #             pd.DataFrame({'DateTime_UTC':[],
    #             colnm:[]}).set_index(["DateTime_UTC"])}
    #         return out
    #     else:
    #         usgst.value = usgst.value / 35.3147
    # else:
    #     colnm = 'USGSLevel_m'
    #     if usgst.empty:
    #         out = {ts['sourceInfo']['siteCode'][0]['value']:
    #             pd.DataFrame({'DateTime_UTC':[],
    #             colnm:[]}).set_index(["DateTime_UTC"])}
    #         return out
    #     else:
    #         usgst.value = usgst.value / 3.28084

    if vcode == '00010': #water tempSpecCond_mScm
        colnm = 'WaterTemp_C'
        if usgst.empty:
            logging.error('watertemp df is empty')
    elif vcode == '00095': #spec cond
        colnm = 'SpecCond_mScm'
        if usgst.empty:
            logging.error('spcond df is empty')
    else:
        logging.error('vcode other than watertemp and spcond')

    site_id = ts['sourceInfo']['siteCode'][0]['value']
    variable_df = usgst[['dateTime',
        'value']].rename(columns={'dateTime': 'DateTime_UTC',
        'value': colnm}).set_index(["DateTime_UTC"])
    out = {site_id: variable_df}

    return out

xx = map(lambda x: parse_usgs_response(x, usgs_raw=usgs_raw),
    range(len(usgs_raw['value']['timeSeries'])))

# g=gageid[1]
# k = xx[1]
# k.keys()
# g=gageid[0]
# k = xx[0]
# k.keys()
# len(xx)
gage_df_list = []
for g in gageid:
    gage_df = [k.values()[0] for k in xx if k.keys()[0] == g]
    gage_df = reduce(lambda x,y: x.merge(y, how='outer', left_index=True,
        right_index=True), gage_df)
    gage_df = gage_df.sort_index().apply(lambda x: pd.to_numeric(x,
        errors='coerce')).resample('15Min').mean()
    gage_df['site'] = sitedict[g]
    gage_df_list.append(gage_df.reset_index())

out = pd.concat(gage_df_list)
out = out.set_index(['DateTime_UTC', 'site'])
out.columns.name = 'variable'
out = out.stack()
out.name = "value"
out = out.reset_index()
out[['region','site']] = out['site'].str.split("_", expand=True)
out = out[['DateTime_UTC','region','site','variable','value']]
# out.head()

return out


db.close()
