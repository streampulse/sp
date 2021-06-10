library(stringr)
library(RMariaDB)
library(DBI)
library(ks)

#read in mysql pw
# conf = readLines('/home/mike/git/streampulse/server_copy/sp/config.py')
conf = readLines('/home/aaron/sp/config.py')
ind = which(lapply(conf, function(x) grepl('MYSQL_PW', x)) == TRUE)
pw = str_match(conf[ind], '.*\\"(.*)\\"')[2]

#read in site and results tables from mysql
con = dbConnect(RMariaDB::MariaDB(), dbname='sp', username='root', password=pw)
site = dbReadTable(con, "site")
results = dbReadTable(con, "results")
doy = as.numeric(strftime(results$date, format='%j'))

#get list of fitted model names available on server
modnames = dir('../model_viz/data', pattern='modOut')
sitenm_all = str_match(modnames, 'modOut_(\\w+_\\w+)_[0-9]{4}')[,2]

#isolate those that are public (no embargo or past embargo period)
public_sites = difftime(Sys.time(), site$addDate,
    units='days') > site$embargo * 365
site = site[public_sites, c('region','site')]
sitenames_public = paste(site[,1], site[,2], sep='_')

#filter available models so that only public ones can be viewed.
#legacy code, so unnecessarily convoluted
modelnames_public = intersect(sitenm_all, sitenames_public)
sitenames = sitenm_all[sitenm_all %in% modelnames_public]
sitenames = unique(sitenames)
# modelnames_public = intersect(sitenmyr_all[,1], sitenames_public)
# sitenmyr = sitenmyr_all[sitenmyr_all[,1] %in% modelnames_public,]

#powell stuff to expensive
# #get list of Powell Center Synthesis fitted model names available on server
# modlists = dir('../model_viz/powell_data/shiny_lists/')
# sitenm_all_pow = str_match(modlists, '^(\\w+_[0-9]+)_[0-9]{4}')[,2]
# sitenm_all_pow = unique(sitenm_all_pow)

#compute overall kernel density so that it need not always be recomputed
overall_kernel = kde(na.omit(results[, c('GPP','ER')]))

dbDisconnect(con)
