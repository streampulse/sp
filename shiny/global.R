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

#get list of Powell Center Synthesis fitted model names available on server
# dx = '/home/mike/git/streampulse/model/ancillary/powell_data_import/RDS_components/'
powIn = dir('powell_data/inData', pattern='inData')
# powI = dir(paste0(dx, 'inData'), pattern='inData')
# powOut = dir(paste0(dx, 'outData'), pattern='outData')
# powOutEx = dir(paste0(dx, 'outExtra'), pattern='outExtra')
fnames = dir('data')
modnames = dir('data', pattern='modOut')
sitenmyr_all_pow = str_match(powIn,
    '^inData_(\\w+_[0-9]+)_([0-9]{4})')[,2:3]

#create mapping of input data fields and their pretty equivalents
varmap = list('DO.sat'=list('DO sat', 'DO sat (%)'),
    'depth'=list('Depth', 'Depth (m)'),
    'temp.water'=list('Water temp',
        expression(paste('Water temp (', degree, 'C)'))),
    'light'=list('PAR', 'Light (PAR)'),
    'discharge'=list('Discharge',
        expression(paste('Discharge (m'^3, 's'^-1, ')'))))

dbDisconnect(con)
