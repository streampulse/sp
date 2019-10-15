import os
import sys
import sqlalchemy as sa
import pandas as pd

wrk_dir = '/home/aaron/sp'
# wrk_dir = '/home/mike/git/streampulse/server_copy/sp'
sys.path.insert(0, wrk_dir)
os.chdir(wrk_dir)
import config as cfg

pw = cfg.MYSQL_PW
db = sa.create_engine('mysql://root:{0}@localhost/sp'.format(pw))

#get number of users, observations, and sites to post on SP landing page
nusers = pd.read_sql("select count(id) as n from user", db.engine).n[0]
nobs = pd.read_sql("select count(id) as n from data", db.engine).n[0]
nobs_powell = pd.read_sql("select count(id) as n from powell", db.engine).n[0]
nobs = nobs + nobs_powell
nsites = pd.read_sql("select count(id) as n from site", db.engine).n[0]

#write to csv
spstats = pd.DataFrame({'nusers':[nusers], 'nobs':[nobs], 'nsites':[nsites]})
spstats.to_csv('scheduled_scripts/homepage_counts/homepage_counts.csv',
    index=False, encoding='utf-8')
