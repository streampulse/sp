library(openxlsx)
library(RMariaDB)
library(DBI)
library(stringr)
library(dplyr)
library(httr)
library(jsonlite)
library(rvest)

# setup ####

# setwd('/home/aaron/sp')
wd1 = '/home/mike/git/streampulse/server_copy/sp'
setwd(wd1)

logfile = paste0(wd1, '/scheduled_scripts/cuahsi/cuahsi_upload.log')
write(paste('\n\tRunning script at:', Sys.time()), logfile, append=TRUE)
today = Sys.Date()

#if there was an error during the last run, stop
lre = readLines('scheduled_scripts/cuahsi/last_run_error.log')
if(lre == '1'){
    write(paste('STOP: error logged during previous run.'), logfile,
        append=TRUE)
    stop()
}

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

# update metadata ####

#load excel worksheets into dataframes and export as csv
# date = as.character(Sys.Date())

wb = loadWorkbook('scheduled_scripts/cuahsi/cuahsi_metadata.xlsx')
shtnames = names(wb)[-(1:2)]
# shtnames = shtnames[-which(shtnames == 'DataValues')]
shtnames = shtnames[! shtnames %in% c('Introduction','Description of Tables',
    'Samples','LabMethods',
    'QualityControlLevels','DataValues','Categories','DerivedFrom',
    'GroupDescriptions', 'Groups','OffsetTypes')]

# dir.create(paste0('scheduled_scripts/cuahsi/', as.character(today)))
for(s in shtnames){
    dat = read.xlsx('scheduled_scripts/cuahsi/cuahsi_metadata.xlsx', s)
    dat = dat[-(1:4),-1]
    dat[is.na(dat)] = ''
    write.csv(dat, paste0('scheduled_scripts/cuahsi/BulkUpload/Sources/',
        s, '.csv'), row.names=FALSE)
}

#update data records ####

#read in all site data from site table
res = dbSendQuery(con, paste("SELECT CONCAT(region, '_', site) AS site,",
    "ROUND(latitude, 5) AS lat, ROUND(longitude, 6) AS lon,",
    "embargo, addDate FROM site;"))
sites = dbFetch(res)
# sites = sites[-c(5:74),]
# sites = sites[-c(5, 55, 62:70),]
dbClearResult(res)

#filter embargoed sites
embargo_end = sites$addDate + as.difftime(sites$embargo * 365, units='days')
public_sites = embargo_end < as.POSIXct(today)
embargoed_sites = sites[! public_sites, 'site']
sites = sites[public_sites,]
# sites = sites[-c(5, 47:51),]
sites = sites[,!colnames(sites) %in% c('embargo', 'addDate')]


# site_df = dbFetch(res)
# # site_df = site_df[-c(5:74),]
# site_df = site_df[-c(5, 55, 62:70),]
# dbClearResult(res)
#
# #filter embargoed sites
# embargo_end = site_df$addDate + as.difftime(site_df$embargo * 365, units='days')
# public_sites = embargo_end < as.POSIXct(today)
# embargoed_sites = site_df[! public_sites, 'site']
# site_df = site_df[public_sites,]
# site_df = site_df[,!colnames(site_df) %in% c('embargo', 'addDate')]
#
# # region_vec = unname(sapply(site_df$site, FUN=function(x) strsplit(x, '_')[[1]][1]))
# # regions = sort(unique(region_vec))
# # for(i in 1:length(regions)){
# #     r = regions[i]
# #     sites = site_df[region_vec == r,]
#     # sites = sites[-5,]

#DB/FILE PREP; RELEGATE TO SEPARATE FILE
#GENERATE DHIST FROM DATA TABLE, USE REGION NOT REGIONSITE, APPEND COL OF 1S
#never mind; dhist should generate itself; just make an empty file


#i guess just read all from data_history
#then read id, regionsite from data
#then see whether each has ids that are missing in the other

# res = dbSendQuery(con, paste0("SELECT id, cuahsi_status FROM data_history",
#     "WHERE region='", r,"';"))
# res = dbSendQuery(con, paste0("SELECT id, region, cuahsi_status FROM ",
#     "data_history;"))
# dhist = dbFetch(res)
# # dim(dhist)
# dbClearResult(res)
# write.csv(dhist, 'scheduled_scripts/cuahsi/data_history.csv',
#     row.names=FALSE)
dhist = tryCatch(read.csv('scheduled_scripts/cuahsi/data_history.csv',
    stringsAsFactors=FALSE), error=function(e){
        if(e$message == 'no lines available in input'){
            data.frame(id=numeric(), cuahsi_status=character())
        } else {
            write(paste('Error: data_history.csv not found?:\n\t', e), logfile,
                append=TRUE)
            writeLines('1', 'scheduled_scripts/cuahsi/last_run_error.log')
            stop()
        }
    })

# res = dbSendQuery(con, paste0("SELECT id, ",
#     "CONCAT(data.region, '_', data.site) AS site FROM data",
#     "WHERE region='", r,"';"))
# res = dbSendQuery(con, paste0("SELECT id, ",
#     "CONCAT(data.region, '_', data.site) AS site FROM data;"))

# res = dbSendQuery(con, paste0("SELECT id, ",
#     "CONCAT(data.region, '_', data.site) AS site FROM data;"))
# d = dbFetch(res)
# dim(d)
# head(d)
# dbClearResult(res)


res = dbSendQuery(con, paste("SELECT data.id, data.value AS DataValue,",
    "data.DateTime_UTC AS DateTimeUTC, data.upload_id,",
    "CONCAT(data.region, '_', data.site) AS SiteCode, data.variable AS VariableCode,",
    "flag.flag AS QualifierCode FROM data LEFT JOIN flag ON",
    "data.flag=flag.id WHERE data.upload_id >= 0 AND (flag.flag != 'Bad Data'",
    "OR flag.flag IS NULL);"))
# res = dbSendQuery(con, paste("SELECT * FROM data LEFT JOIN flag ON",
#     "data.flag=flag.id WHERE data.upload_id >= 0 AND flag.flag != 'Bad Data';"))
    # "data.flag=flag.id WHERE data.region='", r, "';"))
# "data.flag=flag.id;"))
d = dbFetch(res)
dbClearResult(res)

# ignore_inds = d$upload_id <= -900 | d$SiteCode %in% embargoed_sites |
#     d$QualifierCode == 'Bad Data'

# embargo_log = d$SiteCode %in% embargoed_sites
# recs_to_ignore = d$id[embargo_log]
# d = d[!embargo_log,]

d = d[! d$SiteCode %in% embargoed_sites,]

# d = d[is.na(d$QualifierCode) |
#         d$QualifierCode != 'Bad Data',]
# d = d[! d$SiteCode %in% embargoed_sites,]

# accounted_for =  d$id %in% dhist$id
# ones = dhist$id[dhist$cuahsi_status == '1']
# d = d[! accounted_for | (accounted_for & d$id %in% ones),]
d = d[! d$id %in% dhist$id,]


# dhist2 = dhist[1:10,]
# d2 = d[1:10,]
# d2
# dhist2
# d2[11,] = c(47, 'AZ_GG')
# dhist2[11,] = c(45, 'AZ', 2)
#
# upload_to_cuahsi = d2[! d2$id %in% dhist2$id[dhist2$cuahsi_status == 1],]
# dhist2[! dhist2$id %in% d2$id, 'cuahsi_status'] = 3


# res = dbSendQuery(con, paste0("SELECT data_history.id AS hist_id, data.id, ",
#     "data_history.cuahsi_status, ",
#     "CONCAT(data.region, '_', data.site) AS site FROM data_history ",
#     "LEFT JOIN data ON data_history.id=data.id UNION ALL ",
#     "SELECT data_history.id AS hist_id, data.id, data_history.cuahsi_status, ",
#     "CONCAT(data.region, '_', data.site) AS site FROM data_history ",
#     "RIGHT JOIN data ON data_history.id=data.id ",
#     "WHERE data.region='",
#     r, "' AND data.upload_id >= 0 AND data_history.id IS NULL;"))
# res = dbSendQuery(con, paste0("SELECT data_history.id FROM data_history ",
#     "LEFT JOIN data ON data_history.id=data.id UNION ALL ",
#     "SELECT data_history.id FROM data_history ",
#     "RIGHT JOIN data ON data_history.id=data.id ",
#     "WHERE data.region='",
#     r, "' AND data.upload_id >= 0 AND data_history.id is NULL;"))
# res = dbSendQuery(con, paste0("SELECT data_history.id FROM data_history ",
#     "LEFT JOIN data ON data_history.id=data.id where region='NC' UNION ALL ",
#     "SELECT data_history.id FROM data_history ",
#     "RIGHT JOIN data ON data_history.id=data.id where region='NC' ",
#     "AND data_history.id IS NULL;"))
# res = dbSendQuery(con, paste0("SELECT data_history.id FROM data_history ",
#     "LEFT JOIN data ON data_history.id=data.id where site='KANSASR' UNION ALL ",
#     "SELECT data_history.id FROM data_history ",
#     "RIGHT JOIN data ON data_history.id=data.id where site='KANSASR' ",
#     "AND data_history.id IS NULL;"))

# upload_to_cuahsi = d[! d$id %in% dhist$id,]
# remove_from_cuahsi = dhist[! dhist$id %in% d$id,]


# res = dbSendStatement(con, paste0("UPDATE data_history SET cuahsi_status=",
#     "2 WHERE id in ("))
# d = dbFetch(res)
# dim(resout)
# dbClearResult(res)

# u = upload_to_cuahsi
# upload_to_cuahsi = upload_to_cuahsi[substr(upload_to_cuahsi$site, 1, 2) == 'NC',]

#query Ask Geo database for UTC offsets associated with each site's lat/long
accnt_id = '2023'
api_key = extract_from_config('ASKGEO_KEY')
sites = sites[sites$site %in% unique(d$SiteCode),]
latlongs = paste(paste(sites$lat, sites$lon, sep='%2C'), collapse='%3B')
askGeoReq_base = paste0('https://api.askgeo.com/v1/', accnt_id, '/',
    api_key, '/query.json?databases=Point%2CTimeZone&points=', latlongs)
    # api_key, '/query.json?databases=Point&points=', latlongs)
askGeoReq_summer = paste0(askGeoReq_base, '&dateTime=2018-06-21')
askGeoReq_winter = paste0(askGeoReq_base, '&dateTime=2018-12-21')

d_summer = tryCatch({
    r = httr::GET(askGeoReq_summer)
    json = httr::content(r, as="text", encoding="UTF-8")
    jsonlite::fromJSON(json)
}, error=function(e){
    write(paste('Error: AskGeo issue (summer):\n\t', e), logfile,
        append=TRUE)
    writeLines('1', 'scheduled_scripts/cuahsi/last_run_error.log')
    stop()
})
# r = httr::GET(askGeoReq_summer)
# json = httr::content(r, as="text", encoding="UTF-8")
# d_summer = try(jsonlite::fromJSON(json), silent=TRUE)
# ds_bak = d_summer
# d_summer = ds_bak
# head(d_summer)

d_winter = tryCatch({
    r = httr::GET(askGeoReq_winter)
    json = httr::content(r, as="text", encoding="UTF-8")
    jsonlite::fromJSON(json)
}, error=function(e){
    write(paste('Error: AskGeo issue (winter):\n\t', e), logfile,
        append=TRUE)
    writeLines('1', 'scheduled_scripts/cuahsi/last_run_error.log')
    stop()
})

# saveRDS(d_winter$data, 'scheduled_scripts/cuahsi/d_winter.rds')
# saveRDS(d_summer$data, 'scheduled_scripts/cuahsi/d_summer.rds')
# d_winter = d_summer = list()
# d_winter$data = readRDS('scheduled_scripts/cuahsi/d_winter.rds')
# d_summer$data = readRDS('scheduled_scripts/cuahsi/d_summer.rds')

# r = httr::GET(askGeoReq_winter)
# json = httr::content(r, as="text", encoding="UTF-8")
# d_winter = try(jsonlite::fromJSON(json), silent=TRUE)
# dw_bak = d_winter
# d_winter = dw_bak
# head(d_winter)

##read series data from database; remove bad data records
# res = dbSendQuery(con, paste("SELECT data.value AS DataValue,",
#     "data.DateTime_UTC AS DateTimeUTC, data.upload_id,",
#     "CONCAT(data.region, '_', data.site) AS SiteCode, data.variable AS VariableCode,",
#     "flag.flag AS QualifierCode FROM data LEFT JOIN flag ON",
#     "data.flag=flag.id WHERE data.region='", r, "';"))
#     # "data.flag=flag.id;"))
# resout = dbFetch(res)
# dbClearResult(res)
# resout = resout[is.na(resout$QualifierCode) |
#     resout$QualifierCode != 'Bad Data',]
# resout = resout[! resout$SiteCode %in% embargoed_sites,]

#convert offsets to hours, bind with latlongs, bind with site data
# dw_bak = d_winter
# ds_bak = d_summer
d_summer = d_summer$data$TimeZone %>%
    mutate(UTCOffset=CurrentOffsetMs / 1000 / 60 / 60) %>%
    select(UTCOffset) %>% bind_cols(d_summer$data$Point)
d_winter = d_winter$data$TimeZone %>%
    mutate(UTCOffset=CurrentOffsetMs / 1000 / 60 / 60) %>%
    select(UTCOffset) %>% bind_cols(d_winter$data$Point)
d_summer = left_join(sites, d_summer, by=c('lat'='Latitude', 'lon'='Longitude'))
d_time = left_join(d_summer, d_winter, by=c('lat'='Latitude', 'lon'='Longitude'),
    suffix=c('.summer', '.winter'))

#make df of dates, weekdays, months from minyear to maxyear in set
mindate = as.Date(paste0(substr(min(d$DateTimeUTC, na.rm=TRUE), 1, 4),
    '-01-01'))
maxdate = as.Date(paste0(substr(max(d$DateTimeUTC, na.rm=TRUE), 1, 4),
    '-12-31'))
tm = data.frame(unix=mindate:maxdate)
tm$date = as.Date(tm$unix, origin='1970-01-01')
tm$wkday = strftime(tm$date, format='%a')
tm$month = strftime(tm$date, format='%m')

if(any(tm$date <= as.Date('1985-12-31'))){
    write(paste('Error: pre-1986 date encountered; update DST handers'),
        logfile, append=TRUE)
    writeLines('1', 'scheduled_scripts/cuahsi/last_run_error.log')
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
d = left_join(d, d_time, by=c('SiteCode'='site'))
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
smap = list('ASU'=c('AZ_SC','AZ_OC','AZ_WB','AZ_LV','AZ_AF','AZ_MV'),
    'Duke'=c('NC_UEno','NC_Eno','NC_Mud','NC_NHC','NC_UNHC','NC_Stony'),
    'UFL'=c('FL_SF2500','FL_SF700','FL_NR1000','FL_WS1500','FL_ICHE2700',
        'FL_SF2800'),
    'UNH'=c('PR_QS','PR_Icacos','VT_Pass','VT_SLPR','VT_POPE','VT_MOOS',
        'PR_RioIcacosTrib','PR_Prieta','NH_BDC','NH_BEF','NH_DCF','NH_GOF',
        'NH_HBF','NH_MCQ','NH_SBM','NH_TPB','NH_WGB'),
    'UWIS'=c('WI_BEC','WI_BRW'),
    'EPFL'=c('YRN16','YRN19','YRN42','YRN47','YRN51','YRN56','YRN62','YRN68',
        'YRN83','YRN86','YRN93','YRN96','YRN116','YRN127','YRN137'),
    'URI'=c('RI_CorkBrk','MD_BARN','MD_DRKR','MD_POBR','MD_GFCP','MD_GFGB',
        'MD_GFVN'),
    'Yale'=c('CT_Unio','CT_FARM','CT_BUNN','CT_STIL','CT_HUBB')
    # 'NEON'=c(''),
    # 'USGS'=c(''),
    )
# res = dbSendQuery(con, paste("select concat(region, '_', site) from site",
#     "where region='CT';"))
# aa = dbFetch(res)
# paste(unname(unlist(aa)), collapse="','")
# dbClearResult(res)
source_map = data.frame(sites=unname(unlist(smap)),
    SourceCode=rep(names(smap), times=unlist(lapply(smap, length))),
    stringsAsFactors=FALSE)
sites_to_ul = unique(d$SiteCode)
unaccounted_for = which(! sites_to_ul %in% unname(unlist(smap)))
if(length(unaccounted_for)){
    write(paste('Error: need to add metadata for sites:',
        paste(sites_to_ul[unaccounted_for], collapse=', ')),
        logfile, append=TRUE)
    writeLines('1', 'scheduled_scripts/cuahsi/last_run_error.log')
    stop()
}
d = left_join(d, source_map, by=c('SiteCode'='sites'))
# d$SourceCode[d$upload_id == -900] = 'NEON'
# d$SourceCode[d$upload_id == -901] = 'USGS'

#join QC level data to set

##gotta sort out the below; also add in differentiators for sub/super canopy PAR/lux
##this mapping is only reasonable for NC: gotta petition groups for other regions
# lmap = list('1'=c('WaterPres_kPa','WaterTemp_C','DO_mgL','CDOM_mV',
#         'SpecCond_mScm','Turbidity_mV','pH','AirPres_kPa','AirTemp_C','CO2_ppm',
#         'Light_lux','Nitrate_mgL','Light2_lux','satDO_mgL','DOsat_pct',
#         'WaterTemp2_C','WaterTemp3_C','Light3_lux','Light4_lux','Light5_lux',
#         'satDO_mgL','DOsat_pct','Level_m','pH_mV','CDOM_ppb','Battery_V',
#         'ChlorophyllA_ugL','SpecCond_uScm','Turbidity_FNU','Turbidity_NTU'),
#     '2'=c('Depth_m','Discharge_m3s','Velocity_ms','Light_PAR','Light2_PAR',
#         'Light3_PAR','Light4_PAR','Light5_PAR',
#         'underwater_PAR','O2GasTransferVelocity_ms'))
# level_map = data.frame(vars=unname(unlist(lmap)),
#     QualityControlLevelCode=rep(names(lmap), times=unlist(lapply(lmap, length))),
#     stringsAsFactors=FALSE)
# d = left_join(d, level_map, by=c('VariableCode'='vars'))
# d$QualityControlLevelCode[d$MethodCode == '0'] = '0'
d$QualityControlLevelCode = '0'


#replace NULLs in QualifierCode
# d$QualifierCode[d$QualifierCode == 'NULL'] = '0'
d$QualifierCode[is.na(d$QualifierCode)] = '0'


#clean up and arrange columns
# d$QualifierCode[is.na(d$QualifierCode)] = 'NULL'
d$DataValue[is.na(d$DataValue)] = -9999
d = select(d, DataValue, LocalDateTime, UTCOffset, DateTimeUTC, SiteCode,
    VariableCode, QualifierCode, MethodCode, SourceCode,
    QualityControlLevelCode)
# wd0 ='/home/mike/git/streampulse/server_copy/sp/scheduled_scripts/cuahsi/'
# wd0 = paste0(getwd(), '/scheduled_scripts/cuahsi/BulkUpload')
setwd(paste0(getwd(), '/scheduled_scripts/cuahsi/BulkUpload'))
# dir.create(paste0(wd0, as.character(today)))
# setwd(paste0(wd0, as.character(today)))
# datafn = paste0('scheduled_scripts/cuahsi/', today, '/DataValues.csv')
# write.csv(d, 'DataValues_full.csv', row.names=FALSE)
# write.csv(d[1:749999,], 'DataValues.csv', row.names=FALSE)

# write.csv(d[1,], 'DataValues.csv', row.names=FALSE)
# d = read.csv(paste0(wd0, 'DataValues_full.csv'), stringsAsFactors=FALSE)
# system('zip DataValues.csv.zip DataValues.csv')

# setwd(wd0)
# setwd('/home/mike/git/streampulse/server_copy/sp')

#upload metadata
logfile_roots = c('Methods', 'Sources', 'Sites', 'Qualifiers', 'Variables')
for(i in 1:length(logfile_roots)){
    system(paste0('curl --config fileUpload_', logfile_roots[i],
        '.config'), wait=TRUE)
}

#check for metadata rejections
rejections = rep(-999, length(logfile_roots))
for(i in 1:length(logfile_roots)){
    html = xml2::read_html(paste0('logs/upload/', logfile_roots[i],
        '_upload.html'))
    rejections[i] = html %>% html_node('.badge.spanRejected') %>%
        html_text(trim=TRUE) %>%
        as.numeric()
}

if(any(is.na(rejections)) || any(rejections != 0)){
    #next line should be removed once cuahsi fixes their qualifier upload code
    rejections[which(logfile_roots == 'Qualifiers')] = 0

    write(paste0('Error: metadata rejections:\n\t',
        paste(logfile_roots, rejections, collapse='; ')), logfile, append=TRUE)
    writeLines('1', '../last_run_error.log')
    stop()
}

#upload data
data_rejection_checker = function(note){
    html = xml2::read_html(paste0('logs/upload/DataValues_upload.html'))
    rejections = html %>% html_node('.badge.spanRejected') %>%
        html_text(trim=TRUE) %>%
        as.numeric()
    if(is.na(rejections) || rejections != 0){
        write(paste0('Warning: data rejections: ', rejections, '\n\tNote: ',
            note), logfile, append=TRUE)
        writeLines('1', '../last_run_error.log')
    }
}

chunker_uploader = function(df, chunksize){

    #determine chunks based on number of records
    nrows = nrow(df)
    n_full_chunks = floor(nrows / chunksize)
    partial_chunk_len = nrows %% chunksize

    write(paste('Uploading data in', n_full_chunks,
        'chunks and a partial chunk of length', partial_chunk_len),
        logfile, append=TRUE)

    #upload all if small enough (<= 1 chunk), otherwise do it chunkwise
    if(n_full_chunks == 0){
        write.csv(d, 'Sources/DataValues.csv', row.names=FALSE)
        system(paste0('curl --config fileUpload_DataValues.config'),
            wait=TRUE)
        data_rejection_checker('chunk 1; no full chunks.')
    } else {
        for(i in 1:n_full_chunks){
            write.csv(d[1:chunksize,], 'Sources/DataValues.csv',
                row.names=FALSE)
            d = d[(chunksize + 1):nrow(d),]
            system(paste0('curl --config fileUpload_DataValues.config'),
                wait=TRUE)
            data_rejection_checker(paste('chunk', i, 'of', n_full_chunks))
            file.rename('logs/upload/Variables_upload.html',
                paste0('logs/upload/Variables_upload', i, '.html'))
        }
        if(partial_chunk_len){
            write.csv(d, 'Sources/DataValues.csv', row.names=FALSE)
            system(paste0('curl --config fileUpload_DataValues.config'),
                wait=TRUE)
            data_rejection_checker(paste('final, partial chunk out of',
                n_full_chunks, 'total chunks'))
        }
    }
}

tryCatch(chunker_uploader(d, 749999), error=function(e){
    write(paste0('Error: chunker failed:\n\t', e), logfile, append=TRUE)
    writeLines('1', '../last_run_error.log')
    stop()
})

#if everything worked, update dhist with cuahsi_status=3s
if(readLines('../last_run_error.log') == '0'){
    tryCatch({
        dhist = rbind(dhist, data.frame(id=d$id,
            cuahsi_status=rep(2, nrow(d))))
        # dhist$cuahsi_status[dhist$cuahsi_status == 1] = 2
        dhist[! dhist$id %in% d$id & dhist$cuahsi_status < 3,
            'cuahsi_status'] = 3
        #set to 4 (removed from cuahsi) in a separate script, after confirmation from liza
        write.csv(dhist, '../data_history.csv', row.names=FALSE)
    }, error=function(e){
        write(paste0('Error: failed to write data_history:\n\t', e),
            logfile, append=TRUE)
    })
} else {
    tryCatch({
        write.csv(dhist, '../data_history_checkRejections.csv', row.names=FALSE)
    }, error=function(e){
        write(paste0('Error: failed to write data_history_checkRejections:\n\t',
            e), logfile, append=TRUE)
    })
}
# write.csv(aa, '~/Desktop/site_chili.csv', row.names = F)

#remove temp directory
# unlink(today, recursive=TRUE)

# }

dbDisconnect(con)
