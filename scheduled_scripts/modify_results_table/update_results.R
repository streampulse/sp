library(RMariaDB)
library(stringr)

newly_arrived_file = commandArgs(trailingOnly=TRUE)
setwd('/home/mike/git/streampulse/server_copy/sp/')
# setwd('/home/aaron/sp/')

#connect to database
conf = readLines('config.py')
ind = which(lapply(conf, function(x) grepl('MYSQL_PW', x)) == TRUE)
pw = str_match(conf[ind], '.*\\"(.*)\\"')[2]
con = dbConnect(RMariaDB::MariaDB(), dbname='sp', username='root', password=pw)

#assemble results table
siteyear = str_match(newly_arrived_file,
    'predictions_([a-zA-Z]{2}_[a-zA-Z0-9]+_[0-9]{4}).rds')[2]
model_deets = strsplit(siteyear, '_')[[1]]

modout = readRDS(paste0('shiny/model_viz/data/modOut_', siteyear, '.rds'))
preds = readRDS(paste0('shiny/model_viz/data/predictions_', siteyear, '.rds'))

n_ests = nrow(preds)
siteyear_df = data.frame('region'=rep(model_deets[1], n_ests),
    'site'=rep(model_deets[2], n_ests), 'year'=rep(model_deets[3], n_ests))

results = cbind(siteyear_df, preds, modout$fit$daily[, c('K600_daily_mean',
    'K600_daily_2.5pct', 'K600_daily_97.5pct')])

#rename columns
colnames(results)[colnames(results) == 'date'] = 'solar_date'
colnames(results)[colnames(results) == 'K600_daily_mean'] = 'K600'
colnames(results)[colnames(results) == 'K600_daily_2.5pct'] = 'K600_lower'
colnames(results)[colnames(results) == 'K600_daily_97.5pct'] = 'K600_upper'
colnames(results) = sub('\\.', '_', colnames(results))

#insert new table into database
dbWriteTable(con, 'results', results, append=TRUE)

dbDisconnect(con)
