library(openxlsx)
library(RMariaDB)
library(DBI)
library(stringr)
library(dplyr)
library(httr)
library(jsonlite)

# setwd('/home/aaron/sp')
setwd('/home/mike/git/streampulse/server_copy/sp')
logfile = 'scheduled_scripts/cuahsi/cuahsi_upload.log'
write(paste('\n\tRunning script at:', Sys.time()), logfile, append=TRUE)
date = as.character(Sys.Date())

#connect to database
# conf = readLines('/home/aaron/sp/scheduled_scripts/')
conf = readLines('config.py')
extract_from_config = function(key){
    ind = which(lapply(conf, function(x) grepl(key, x)) == TRUE)
    val = str_match(conf[ind], '.*\\"(.*)\\"')[2]
    return(val)
}
pw = extract_from_config('MYSQL_PW')
con = dbConnect(RMariaDB::MariaDB(), dbname='sp', username='root', password=pw)

#read in all site data from site table
res = dbSendQuery(con, paste("SELECT CONCAT(region, '_', site) AS site,",
    "ROUND(latitude, 5) AS lat, ROUND(longitude, 6) AS lon FROM site;"))
sites = dbFetch(res)
# sites = sites[-c(5, 55, 62:64),]
dbClearResult(res)

#query Ask Geo database for UTC offsets associated with each site's lat/long
accnt_id = '2023'
api_key = extract_from_config('ASKGEO_KEY')
latlongs = paste(paste(sites$lat, sites$lon, sep='%2C'), collapse='%3B')
askGeoReq_base = paste0('https://api.askgeo.com/v1/', accnt_id, '/',
    api_key, '/query.json?databases=Point%2CTimeZone&points=', latlongs)
    # api_key, '/query.json?databases=Point&points=', latlongs)
askGeoReq_summer = paste0(askGeoReq_base, '&dateTime=2018-06-21')
askGeoReq_winter = paste0(askGeoReq_base, '&dateTime=2018-12-21')

r = httr::GET(askGeoReq_summer)
json = httr::content(r, as="text", encoding="UTF-8")
d_summer = try(jsonlite::fromJSON(json), silent=TRUE)
# ds_bak = d_summer
# head(d_summer)

r = httr::GET(askGeoReq_winter)
json = httr::content(r, as="text", encoding="UTF-8")
d_winter = try(jsonlite::fromJSON(json), silent=TRUE)
# dw_bak = d_winter
# head(d_winter)

#read series data from database, remove bad data records
res = dbSendQuery(con, paste("SELECT data.value AS DataValue,",
    "data.DateTime_UTC AS DateTimeUTC,",
    "CONCAT(data.region, '_', data.site) AS SiteCode, data.variable AS VariableCode,",
    "flag.flag AS QualityControlLevelCode FROM data LEFT JOIN flag ON",
    "data.flag=flag.id WHERE data.region='NC';"))
resout = dbFetch(res)
dbClearResult(res)
resout = resout[resout$QualityControlLevelCode != 'Bad Data',]
# head(resout)
# d_backup = d
# d = d_backup
# d_summer = d

#convert offsets to hours, bind with latlongs, bind with site data
d_summer = d_summer$data$TimeZone %>%
    mutate(UTCOffset=CurrentOffsetMs / 1000 / 60 / 60) %>%
    select(UTCOffset) %>% bind_cols(d_summer$data$Point)
d_winter = d_winter$data$TimeZone %>%
    mutate(UTCOffset=CurrentOffsetMs / 1000 / 60 / 60) %>%
    select(UTCOffset) %>% bind_cols(d_winter$data$Point)
d = left_join(sites, d_summer, by=c('lat'='Latitude', 'lon'='Longitude'))
d = left_join(d, d_winter, by=c('lat'='Latitude', 'lon'='Longitude'),
    suffix=c('.summer', '.winter'))

#make df of dates, weekdays, months from minyear to maxyear in set
mindate = as.Date(paste0(substr(min(resout$DateTimeUTC), 1, 4), '-01-01'))
maxdate = as.Date(paste0(substr(max(resout$DateTimeUTC), 1, 4), '-12-31'))
tm = data.frame(unix=mindate:maxdate)
tm$date = as.Date(tm$unix, origin='1970-01-01')
tm$wkday = strftime(tm$date, format='%a')
tm$month = strftime(tm$date, format='%m')

if(any(tm$date <= as.Date('1985-12-31'))){
    write(paste('pre-1986 date encountered; update DST handers'),
        logfile, append=TRUE)
    stop()
}

#between 1986 and 2007, DST was from 1st sunday in apr to last sunday in oct
#get DST start and END for each year in this range
dst_starts = dst_ends = vector()
old_dst = filter(tm, date < as.Date('2007-03-09'))
if(nrow(old_dst)){
    apr_sundays = old_dst[old_dst$month %in% '04' & old_dst$wkday == 'Sun',]
    oct_sundays = old_dst[old_dst$month %in% '10' & old_dst$wkday == 'Sun',]
    apr_sundays$cnt = unlist(tapply(rep(1, nrow(apr_sundays)),
        substr(apr_sundays$date, 1, 7), cumsum))
    oct_sundays$cnt = unlist(tapply(rep(1, nrow(oct_sundays)),
        substr(oct_sundays$date, 1, 7), cumsum))
    dst_starts = append(dst_starts,
        apr_sundays$date[which(apr_sundays$cnt == 1)])
    dst_ends = append(dst_ends,
        oct_sundays$date[which(oct_sundays$cnt %in% 4:5 &
            substr(oct_sundays$date, 9, 10) %in% as.character(24:30))])
}

#as of 2007, DST is from 2nd sunday in march to 2nd sunday in nov
#get DST start and END for each year in this range
new_dst = filter(tm, date > as.Date('2007-03-09'))
mar_sundays = new_dst[new_dst$month %in% '03' & new_dst$wkday == 'Sun',]
nov_sundays = new_dst[new_dst$month %in% '11' & new_dst$wkday == 'Sun',]
mar_sundays$cnt = unlist(tapply(rep(1, nrow(mar_sundays)),
    substr(mar_sundays$date, 1, 7), cumsum))
nov_sundays$cnt = unlist(tapply(rep(1, nrow(nov_sundays)),
    substr(nov_sundays$date, 1, 7), cumsum))
dst_starts = append(dst_starts,
    mar_sundays$date[which(mar_sundays$cnt == 2)])
dst_ends = append(dst_ends,
    nov_sundays$date[which(nov_sundays$cnt == 2)])

# d0 = d
# d = d0
# s = dst_starts
# e = dst_ends
# dst_starts = s
# dst_ends = e

#determine utc offsets and local time for each date in dataset, join to set
d = left_join(resout, d, by=c('SiteCode'='site'))
dst_starts_exp = paste0("as.POSIXct('", dst_starts, "')")
dst_ends_exp = paste0("as.POSIXct('", dst_ends, "')")
bool_exp = paste(
    paste('(d$DateTimeUTC', dst_starts_exp, sep=' > '),
    paste(dst_ends_exp, 'd$DateTimeUTC)', sep=' > '),
    sep=' & ', collapse=' | ')
d$UTCOffset = ifelse(eval(parse(text=bool_exp)),
    d$UTCOffset.summer, d$UTCOffset.winter)
d$LocalDateTime = d$DateTimeUTC + as.difftime(d$UTCOffset, units='hours')

#join method data to set
# methods = read.csv(paste0(date, '/Methods.csv'), stringsAsFactors=FALSE)
mmap = c('WaterPres_kPa'='U20','WaterTemp_C'='U20','DO_mgL'='hobo_DO',
    'CDOM_mV'='turner_CDOM','SpecCond_mScm'='CS547','Turbidity_mV'='turner_turb',
    'pH'='CS526','AirPres_kPa'='U20','AirTemp_C'='U20','CO2_ppm'='vaisala_CO2',
    'Light_lux'='hobo_light','Nitrate_mgL'='suna_V2',
    'Light2_lux'='hobo_light','satDO_mgL'='hobo_DO','DOsat_pct'='hobo_DO',
    'WaterTemp2_C'='U20', 'WaterTemp3_C'='U20','Light3_lux'='hobo_light',
    'Light4_lux'='hobo_light','Light5_lux'='hobo_light')
method_map = data.frame(var=names(mmap), MethodCode=unname(mmap),
    stringsAsFactors=FALSE)
allvars = unique(d$VariableCode)
methodless = data.frame(var=allvars[! allvars %in% names(mmap)], MethodCode='0')
method_map = rbind(method_map, methodless)
d = left_join(d, method_map, by=c('VariableCode'='var'))
core = read.csv('static/sitelist.csv', stringsAsFactors=FALSE)
coresites = paste(core$REGIONID, core$SITEID, sep='_')
d$MethodCode[! d$SiteCode %in% coresites] = '0'

#join sources data to set
##ADD OTHER SOURCES; DETERMINE PROGRAMMATICALLY? ADD FIELDS TO UPLOAD PAGE?

#load excel worksheets into dataframes and export as csv
'/home/mike/Dropbox/streampulse/data/cuahsi_connection/hydroserver_templates'

wb = loadWorkbook('NC_Advanced.xlsx')
shtnames = names(wb)[-(1:2)]
shtnames = shtnames[-which(shtnames == 'DataValues')]
dir.create(date)
for(s in shtnames){
    dat = read.xlsx('NC_Advanced.xlsx', s)
    dat = dat[-(1:4),-1]
    write.csv(dat, paste0(date, '/', s, '.csv'))
}

#read in datavalues worksheet as dataframe
dat = read.xlsx('NC_Advanced.xlsx', 'DataValues')
dat = dat[-(1:4),-1]


resout$UTCOffset =
select(resout, value, )
colnames(resout)

#remove directory
unlink(date, recursive='TRUE')
