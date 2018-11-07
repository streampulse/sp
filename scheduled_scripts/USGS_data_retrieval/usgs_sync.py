import os

#see usgs_sync_setup

#import setup and helper funcs
app_dir = '/home/aaron/sp'
#app_dir = '/home/mike/git/streampulse/server_copy/sp'
wrk_dir = app_dir + '/scheduled_scripts/USGS_data_retrieval'
os.chdir(wrk_dir)
from usgs_sync_setup import *

logging.warning('\nstarting script')

#get site data from database
sitedf = pd.read_sql('select id, region, site, name, latitude, ' +\
    'longitude, usgs, addDate, embargo, site.by, contact, contactEmail, ' +\
    'firstRecord, lastRecord from site;', db.engine)

#assemble dict of gageid, name, vars and data coverage for each site
sitedf['regionsite'] = sitedf["region"].map(str) + "_" + sitedf["site"]
gageid = sitedf.loc[sitedf.regionsite.isin(regionsite)].usgs.tolist()
firstrec = sitedf.loc[sitedf.regionsite.isin(regionsite)].firstRecord.dt.\
    strftime('%Y-%m-%d').tolist()
lastrec = sitedf.loc[sitedf.regionsite.isin(regionsite)].lastRecord.dt.\
    strftime('%Y-%m-%d').tolist()
sitedict = {}
for i in xrange(len(regionsite)):
    df_ind = [j for j in xrange(len(sitedf)) if sitedf.usgs[j] == gageid[i]][0]
    rs_ind = [j for j in xrange(len(regionsite)) if regionsite[j] == sitedf.regionsite[df_ind]][0]
    sitedict[gageid[i]] = (regionsite[rs_ind], variables[rs_ind],
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
# g=gageid[5]
for g in gageid:

    site_name = sitedict[g][0]
    varcode_str = ','.join(sitedict[g][1])
    start_date_str = sitedict[g][2]
    end_date_str = sitedict[g][3]
    start_date = datetime.strptime(start_date_str, '%Y-%m-%d')
    end_date = datetime.strptime(end_date_str, '%Y-%m-%d')

    #adjust start and end dates for data pull so we dont get redundant records
    if coverage_file_found and site_name in coverage.site.tolist():
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
            continue
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

    xx = []
    for i in xrange(len(usgs_raw['value']['timeSeries'])):
        try:
            xx.append(parse_usgs_response(i, usgs_raw=usgs_raw, g=g))
        except ValueError:
            continue
    # xx = map(lambda x: parse_usgs_response(x, usgs_raw=usgs_raw, g=g),
    #     range(len(usgs_raw['value']['timeSeries'])))

    #merge dfs for each variable into a single df and then append to list
    gage_df = [k.values()[0] for k in xx if k.keys()[0] == g]
    gage_df = reduce(lambda x,y: x.merge(y, how='outer', left_index=True,
        right_index=True), gage_df)
    gage_df = gage_df.sort_index().apply(lambda x: pd.to_numeric(x,
        errors='coerce')).resample('15Min').mean()
    gage_df['site'] = site_name
    gage_df_list.append(gage_df.reset_index())

if gage_df_list:

    #combine list of dfs into one df; final organizing, supplementing, formatting
    out = pd.concat(gage_df_list)
    out = out.set_index(['DateTime_UTC', 'site'])
    out.columns.name = 'variable'
    out = out.stack()
    out.name = "value"
    out = out.reset_index()
    out[['region','site']] = out['site'].str.split('_', expand=True)
    out = out[['region','site','DateTime_UTC','variable','value']]
    out['flag'] = None
    out['upload_id'] = -901

    #write to database in chunks of 100,000 records each
    chunker_ingester(out)
    # session.commit()

    #update variableList and coverage columns in site table
    for u in regionsite_update:
        with open('../../site_update_stored_procedure.sql', 'r') as f:
            t = f.read()
        t = t.replace('RR', u.split('_')[0])
        t = t.replace('SS', u.split('_')[1])

        session.execute(t)
        session.execute('CALL update_site_table();')
        session.commit()

    session.close()
    sitedict
    #store record of which time ranges have been pulled from usgs for each site
    coverage_tracking = pd.DataFrame({'site': [x[0] for x in sitedict.values()],
        'coverage_start': [x[2] for x in sitedict.values()],
        'coverage_end': [x[3] for x in sitedict.values()]})
    coverage_tracking = coverage_tracking[['site', 'coverage_start', 'coverage_end']]
    coverage_tracking.to_csv('coverage_tracking.csv', index=False)

else:
    logging.warning('Nothing to do. done.')
