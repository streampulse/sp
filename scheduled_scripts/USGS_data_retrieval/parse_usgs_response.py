import requests
import pandas as pd
import simplejson

def parse_usgs_response(x, usgs_raw):

    ts = usgs_raw['value']['timeSeries'][x]
    usgst = pd.read_json(simplejson.dumps(ts['values'][0]['value']))
    vcode = ts['variable']['variableCode'][0]['value']

    if vcode=='00060': # discharge
        colnm = 'USGSDischarge_m3s'
        if usgst.empty: #return empty df in dict
            out = {ts['sourceInfo']['siteCode'][0]['value']:
                pd.DataFrame({'DateTime_UTC':[],
                colnm:[]}).set_index(["DateTime_UTC"])}
            return out
        else:
            usgst.value = usgst.value / 35.3147
    else:
        colnm = 'USGSLevel_m'
        if usgst.empty:
            out = {ts['sourceInfo']['siteCode'][0]['value']:
                pd.DataFrame({'DateTime_UTC':[],
                colnm:[]}).set_index(["DateTime_UTC"])}
            return out
        else:
            usgst.value = usgst.value / 3.28084

    # usgst['site'] = ts['sourceInfo']['siteCode'][0]['value'] # site code
    out = {ts['sourceInfo']['siteCode'][0]['value']:usgst[['dateTime',
        'value']].rename(columns={'dateTime':'DateTime_UTC',
        'value':colnm}).set_index(["DateTime_UTC"])}
    return out
