import os
import sys
import MySQLdb
import pandas as pd
import requests
import simplejson
# wrk_dir = '/home/aaron/sp'
wrk_dir = '/home/mike/git/streampulse/server_copy/sp'
sys.path.insert(0, wrk_dir)
os.chdir(wrk_dir)
import config as cfg
wrk_dir = '/home/mike/git/streampulse/server_copy/sp/scheduled_scripts/USGS_data_retrieval'
os.chdir(wrk_dir)
from parse_usgs_response import parse_usgs_response


regionsite=['FL_ICHE2700','FL_NR1000']; startDate='2017-11-01'; endDate='2017-12-01'
#discharge, gage height, water temp, spec cond, nitrate
# variables=['00060', '00065', '00010', '00095']
variables=['00010', '00095']

pw = cfg.MYSQL_PW

db = MySQLdb.connect(host="localhost", user="root", passwd=pw, db="sp")
cur = db.cursor()

cur.execute('select id, region, site, name, latitude, ' +\
    'longitude, usgs, addDate, embargo, site.by, contact, contactEmail ' +\
    'from site;')
# nusers = int(cur.fetchone()[0])
sqlresp = cur.fetchall()
sitedf = pd.DataFrame(list(sqlresp), columns=['id','region','site','name','latitude',
    'longitude','usgs','addDate','embargo','by','contact','contactEmail'])

sitedf['regionsite'] = sitedf["region"].map(str) + "_" + sitedf["site"]

gageid = sitedf.loc[sitedf.regionsite.isin(regionsite)].usgs.tolist()
sitedict = dict(zip(gageid, regionsite))
gageid = [x for x in gageid if x is not None]
gageidstr = ",".join(gageid)
#lat,lng = sitex.loc[:,['latitude','longitude']].values.tolist()[0]
if(len(gageid) == 0 or gageidstr is None):
    sys.exit('no gage ids')
varcodestr = ",".join(variables)
#request usgs water service data in universal time (T01:15 makes it line up with our datasets)
url = "https://nwis.waterservices.usgs.gov/nwis/iv/?format=json&sites=" + \
    gageidstr + "&startDT=" + startDate + "T01:15Z&endDT=" + endDate + \
    "T23:59Z&parameterCd=" + varcodestr + "&siteStatus=all"
r = requests.get(url)
print r.status_code
if r.status_code != 200:
    sys.exit('USGS_error')
usgs_raw = r.json()


def parse_usgs_response(x, usgs_raw):

    x = 0
    ts = usgs_raw['value']['timeSeries'][x]
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
    # elif vcode == '00065': #level
    #     colnm = 'USGSLevel_m'
    #     if usgst.empty:
    #         out = {ts['sourceInfo']['siteCode'][0]['value']:
    #             pd.DataFrame({'DateTime_UTC':[],
    #             colnm:[]}).set_index(["DateTime_UTC"])}
    #         return out
    #     else:
    #         usgst.value = usgst.value / 3.28084
    elif vcode == '00010': #water tempSpecCond_mScm
        colnm = 'WaterTemp_C'
        if usgst.empty:
            out = {ts['sourceInfo']['siteCode'][0]['value']:
                pd.DataFrame({'DateTime_UTC':[],
                colnm:[]}).set_index(["DateTime_UTC"])}
            sys.exit('watertemp df is empty')
        else:
            usgst.value = usgst.value / 3.28084
    elif vcode == '00095': #spec cond
        colnm = 'SpecCond_mScm'
        if usgst.empty:
            out = {ts['sourceInfo']['siteCode'][0]['value']:
                pd.DataFrame({'DateTime_UTC':[],
                colnm:[]}).set_index(["DateTime_UTC"])}
            return out
        else:
            usgst.value = usgst.value / 3.28084
    else:
        pass

    # usgst['site'] = ts['sourceInfo']['siteCode'][0]['value'] # site code
    out = {ts['sourceInfo']['siteCode'][0]['value']:usgst[['dateTime',
        'value']].rename(columns={'dateTime':'DateTime_UTC',
        'value':colnm}).set_index(["DateTime_UTC"])}
    return out


xx = map(lambda x: parse_usgs_response(x, usgs_raw=usgs_raw),
    range(len(usgs_raw['value']['timeSeries'])))

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
out.head()

return out[['DateTime_UTC','region','site','variable','value']]


db.close()
