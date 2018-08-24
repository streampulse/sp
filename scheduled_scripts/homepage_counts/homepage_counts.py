import os
os.chdir('/home/aaron/sp')
import config as cfg
import MySQLdb
import pandas as pd

pw = cfg.MYSQL_PW

db = MySQLdb.connect(host="localhost", user="root", passwd=pw, db="sp")
cur = db.cursor()

#get number of users, observations, and sites to post on SP landing page
cur.execute("select count(id) as n from user")
nusers = int(cur.fetchone()[0])
cur.execute("select count(id) as n from data")
nobs = int(cur.fetchone()[0])
cur.execute("select count(id) as n from site")
nsites = int(cur.fetchone()[0])

db.close()

#write to csv
spstats = pd.DataFrame({'nusers':[nusers], 'nobs':[nobs], 'nsites':[nsites]})
spstats.to_csv('scheduled_scripts/homepage_counts/homepage_counts.csv',
    index=False, encoding='utf-8')
