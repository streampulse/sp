import os
import sys
import MySQLdb
import pandas as pd
import requests
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
