import requests
import pandas as pd
import simplejson

def parse_usgs_response(x, usgs_raw):

    ts = usgs_raw['value']['timeSeries'][x]
    usgst = pd.read_json(simplejson.dumps(ts['values'][0]['value']))
    vcode = ts['variable']['variableCode'][0]['value']

    if vcode == '00010': #water tempSpecCond_mScm
        colnm = 'WaterTemp_C'
        if usgst.empty:
            logging.debug('watertemp df is empty')
    elif vcode == '00095': #spec cond
        colnm = 'SpecCond_mScm'
        if usgst.empty:
            logging.debug('spcond df is empty')
    else:
        logging.debug('vcode other than watertemp and spcond')

    site_id = ts['sourceInfo']['siteCode'][0]['value']
    variable_df = usgst[['dateTime',
        'value']].rename(columns={'dateTime': 'DateTime_UTC',
        'value': colnm}).set_index(["DateTime_UTC"])
    out = {site_id: variable_df}

    return out
