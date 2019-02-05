import os
import sys
import sqlalchemy as sa
import pandas as pd
from sqlalchemy.ext.declarative import declarative_base

#import credentials from streampulse flask app config file
#app_dir = '/home/aaron/sp'
app_dir = '/home/mike/git/streampulse/server_copy/sp'
sys.path.insert(0, app_dir)
os.chdir(app_dir)
import config as cfg

#configure database connection
pw = cfg.MYSQL_PW
db = sa.create_engine('mysql://root:{0}@localhost/sp'.format(pw))
session = sa.orm.Session(bind=db.engine)

#get list of NEON sites
sites = pd.read_sql("select distinct concat(region, '_', site) as a from " +\
    "site where `by` = -902;", db.engine).a.tolist()

#update variableList and coverage columns in site table
for u in sites:
    with open('site_update_stored_procedure_powell.sql', 'r') as f:
        t = f.read()
    t = t.replace('RR', u.split('_')[0])
    t = t.replace('SS', u.split('_')[1])

    session.execute(t)
    session.execute('CALL update_site_table();')
    session.commit()

session.close()
