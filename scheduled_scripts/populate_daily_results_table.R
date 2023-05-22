
library(RMariaDB)
library(DBI)
library(tidyverse)
library(glue)

setwd('/home/aaron/sp/shiny/model_viz/data/')

conf = readLines('../../../config.py')
extract_from_config = function(key){
    ind = which(lapply(conf, function(x) grepl(key, x)) == TRUE)
    val = str_match(conf[ind], '.*\\"(.*)\\"')[2]
    return(val)
}
pw = extract_from_config('MYSQL_PW')

con = dbConnect(RMariaDB::MariaDB(), dbname='sp',
    username='root', password=pw)

f = list.files('.')
mods = f[grep('modOut', f)]

#filter embargoed site results before continuing
sitedata = dbGetQuery(con, glue("select region as regionID, site as siteID, name as siteName,",
    "latitude, longitude, usgs as USGSgageID, addDate, `by` as ds_ref, ",
    "embargo as embargoDaysRemaining, contact, contactEmail, firstRecord, ",
    "lastRecord, variableList, grabVarList, concat(region, '_', site) as ",
    "regionsite from site;"))
embargoed_sites = sitedata[sitedata$embargoDaysRemaining > 0, 'regionsite']

regsite = str_match(mods, 'modOut_(.*?)_[0-9]{4}.rds$')[, 2]
mods = mods[! regsite %in% embargoed_sites]

DBI::dbExecute(con, 'delete from results;')
DBI::dbExecute(con, 'alter table results auto_increment=1;')

for(i in 1:length(mods)){

    mod = readRDS(mods[i])
    r_s_y = str_match(mods[i], 'modOut_([A-Za-z]{2})_(.+?)_([0-9]{4}).rds$')[2:4]

    results_overwrite = mod$fit$daily %>%
        mutate(
            region = r_s_y[1],
            site = r_s_y[2],
            year = r_s_y[3],
            errors = substr(errors, 1, 50)) %>%
        select(region, site, year, date, GPP=GPP_daily_mean,
            GPP_lower=GPP_daily_2.5pct,
            GPP_upper=GPP_daily_97.5pct, ER=ER_daily_mean,
            ER_lower=ER_daily_2.5pct, ER_upper=ER_daily_97.5pct,
            K600=K600_daily_mean, K600_lower=K600_daily_2.5pct,
            K600_upper=K600_daily_97.5pct, valid_day, warnings, errors)

    DBI::dbWriteTable(con, 'results', results_overwrite, append=TRUE)
}

dbDisconnect(con)
