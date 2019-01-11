from odm2api.ODMconnection import dbconnection
import odm2api.services.readService as odm2rs

# A SQLite file-based connection
session_factory = dbconnection.createConnection('sqlite',
                                                '/myfilepath/odm2db.sqlite')
read = odm2rs.ReadODM2(session_factory)

# A connection to a server-based database system
db_credentials = {
    'address': 'ip-or-domainname',
    'db': 'dbname',
    'user': 'dbuser',
    'password': 'password'
}
session_factory = dbconnection.createConnection('postgresql',
                                                **db_credentials)
read = odm2rs.ReadODM2(session_factory)
