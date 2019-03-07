library(RMariaDB)
library(stringr)

newly_departed_file = commandArgs(trailingOnly=TRUE)
# setwd('/home/mike/git/streampulse/server_copy/sp/')
setwd('/home/aaron/sp/')

#connect to database
conf = readLines('config.py')
ind = which(lapply(conf, function(x) grepl('MYSQL_PW', x)) == TRUE)
pw = str_match(conf[ind], '.*\\"(.*)\\"')[2]
con = dbConnect(RMariaDB::MariaDB(), dbname='sp', username='root', password=pw)

#extract information from filename
siteyear = str_match(newly_departed_file,
    'predictions_([a-zA-Z]{2}_[a-zA-Z0-9]+_[0-9]{4}).rds')[2]
model_deets = strsplit(siteyear, '_')[[1]]

#delete records associated with departed file from database
nrows_affected = dbExecute(con, paste0("DELETE FROM results WHERE region='",
    model_deets[1], "' AND site='", model_deets[2], "' AND year='",
    model_deets[3], "';"))

dbDisconnect(con)
