library(stringr)
library(RMariaDB)
library(DBI)

#read in mysql pw
conf = readLines('/home/mike/git/streampulse/server_copy/sp/config.py')
# conf = readLines('/home/aaron/sp/config.py')
ind = which(lapply(conf, function(x) grepl('MYSQL_PW', x)) == TRUE)
pw = str_match(conf[ind], '.*\\"(.*)\\"')[2]
# pw = readLines('/home/mike/Dropbox/stuff_2/credentials/spdb.txt')

#read in site table from mysql
con = dbConnect(RMariaDB::MariaDB(), dbname='sp', username='root', password=pw)
site = dbReadTable(con, "site")

#get list of fitted model names available on server
fnames = dir('data')
modnames = dir('data', pattern='modOut')
sitenmyr_all = str_match(modnames, 'modOut_(\\w+_\\w+)_([0-9]{4})')[,2:3]

#isolate those that are public (no embargo or past embargo period)
public_sites = difftime(Sys.time(), site$addDate,
    units='days') > site$embargo * 365
site = site[public_sites,c('region','site')]
sitenames_public = paste(site[,1], site[,2], sep='_')

#filter available models so that only public ones can be viewed
modelnames_public = intersect(sitenmyr_all[,1], sitenames_public)
sitenmyr = sitenmyr_all[sitenmyr_all[,1] %in% modelnames_public,]

sitenames = sitenmyr[,1]
siteyears = sitenmyr[,2]
defaultv = list(sitenames=sitenames, siteyears=siteyears)
# sitenames = sitenmyr[,1]
# siteyears = sitenmyr[,2]

dbDisconnect(con)
