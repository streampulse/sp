import requests
import pandas as pd
import simplejson
import logging

def parse_usgs_response(i, usgs_raw, g):
    logging.error('test: ' + g)

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
