# library(devtools)
# devtools::install_github("NEONScience/NEON-geolocation/geoNEON")
# devtools::install_github("NEONScience/NEON-utilities/neonUtilities")

library(httr)
library(jsonlite)
library(dplyr)
library(downloader)
# library(geoNEON)
# library(neonUtilities)
library(RMariaDB)
library(DBI)

# basics ####

req = GET("http://data.neonscience.org/api/v0/products/DP1.10003.001")
# x = content(req, as="parsed")
txt = content(req, as="text")
avail = fromJSON(txt, simplifyDataFrame=T, flatten=T)

#keywords
avail$data$keywords
#references for documentation
avail$data$specs
#availability for each site and month
avail$data$siteCodes
#just months
avail$data$siteCodes$availableMonths
#urls for api calls
urls = unlist(avail$data$siteCodes$availableDataUrls)

#get a dataset
brd = GET(urls[grep("WOOD/2015-07", urls)])
brdf = fromJSON(content(brd, as="text"))

# view just the available data files
brdf$data$files

#filename format for manually collected (observational) data
#(sometimes domain and site are omitted):
#**NEON.[domain number].[site code].[data product ID].[file-specific name].
#[date of file creation] **

#filename format for sensor data
#NEON.[domain number].[site code].[data product ID].00000.
#[soil plot number].[depth].[averaging interval].[data table name].
#[year]-[month].[data package].[date of file creation]

#isolate files by name components and read them into a table
brd.count = read.delim(brdf$data$files$url
    [intersect(grep("countdata", brdf$data$files$name),
        grep("basic", brdf$data$files$name))], sep=",")

brd.point = read.delim(brdf$data$files$url
    [intersect(grep("perpoint", brdf$data$files$name),
        grep("basic", brdf$data$files$name))], sep=",")

#plot demo
clusterBySp <- brd.count %>%
    group_by(scientificName) %>%
    summarize(total=sum(clusterSize))

# Reorder so list is ordered most to least abundance
clusterBySp <- clusterBySp[order(clusterBySp$total, decreasing=T),]

# Plot
barplot(clusterBySp$total, names.arg=clusterBySp$scientificName,
    ylab="Total", cex.names=0.5, las=2)

#read the readme
readme = url(d$data$files$url[grep('readme', d$data$files$url)[1]])
r = readLines(readme)
r[1:10] #read a few lines at a time for managability

# for reals ####

#nitrate data

req = GET("http://data.neonscience.org/api/v0/products/DP1.20033.001")
txt = content(req, as="text")
avail = fromJSON(txt, simplifyDataFrame=TRUE, flatten=TRUE)

#availability for each site and month
avail$data$siteCodes
#just months
avail$data$siteCodes$availableMonths
#urls for api calls
urls = unlist(avail$data$siteCodes$availableDataUrls)

sort(unique(substr(urls, 58, 61)))

#get a collection of data files from one site and month
d = GET(urls[1]) #the first one only has a single observation
d = GET(urls[2]) #all -1s
d = GET(urls[5])
d = fromJSON(content(d, as="text"))

# view just the available data file names
d$data$files$name

data = read.delim(d$data$files$url
    [intersect(grep("basic", d$data$files$name),
        grep("15_minute", d$data$files$name))], sep=",")

# sum(is.na(data$surfWaterNitrateMean))/nrow(data)
head(data, 2)
dim(data)
nitr = data[!is.na(data$surfWaterNitrateMean),]
dim(nitr)
nitr$surfWaterNitrateMean
nitr$
sum(nitr$surfWaterNitrateMean == -1)/nrow(nitr)

data2 = read.delim(d$data$files$url
    [intersect(grep("expanded", d$data$files$name),
        grep("15_minute", d$data$files$name))], sep=",")
colnames(data2)
nitr2 = data2[!is.na(data2$surfWaterNitrateMean),]
dim(nitr2)
nitr2$surfWaterNitrateMean
sum(nitr2$surfWaterNitrateMean == -1)/nrow(nitr2)


#if dim(nitr)[1] < 10
#if sum(nitr$surfWaterNitrateMean == -1)/nrow(nitr) > 0.7

# loop to find datasets that actually contain data ####

req = GET("http://data.neonscience.org/api/v0/products/DP1.20033.001")
txt = content(req, as="text")
avail = fromJSON(txt, simplifyDataFrame=TRUE, flatten=TRUE)

urls = unlist(avail$data$siteCodes$availableDataUrls)

for(i in 1:length(urls)){
    print(urls[i])
    d = GET(urls[i])
    d = fromJSON(content(d, as="text"))
    data = read.delim(d$data$files$url
        [intersect(grep("basic", d$data$files$name),
            grep("15_minute", d$data$files$name))], sep=",")
    nitr = data[(!is.na(data$surfWaterNitrateMean) &
            data$surfWaterNitrateMean != -1),] #untested

    weak_coverage = dim(nitr)[1] < 10
    negative_ones = sum(nitr$surfWaterNitrateMean == -1) / nrow(nitr) > 0.9
    if(weak_coverage){
        print('weak cov')
        next
    }
    if(negative_ones){
        print('negs')
        next
    }

    assign(paste0('nitr', i), nitr, .GlobalEnv)
}

# add new site data to table ####

req = GET("http://data.neonscience.org/api/v0/sites/WALK")
txt = content(req, as="text")
site_resp = fromJSON(txt, simplifyDataFrame=TRUE, flatten=TRUE)

cur_time = Sys.time()
attr(cur_time,'tzone') = 'UTC'

site_data = data.frame('region'=site_resp$data$stateCode,
    'site'=site_resp$data$siteCode,
    'name'=site_resp$data$siteDescription,
    'latitude'=site_resp$data$siteLatitude,
    'longitude'=site_resp$data$siteLongitude,
    'usgs'=NA, 'addDate'=cur_time, 'embargo'=0, 'by'=-900,
    'contact'='NEON', 'contactEmail'=NA)

con = dbConnect(RMariaDB::MariaDB(), dbname='sp',
    username='root', password='pass')

res = dbSendQuery(con, paste0("SELECT * FROM site WHERE site='",
    site_data$site, "' AND region='", site_data$region, "';"))
resout = dbFetch(res)
dbClearResult(res)

if(!nrow(resout)){
    dbWriteTable(con, 'site', site_data, append=TRUE)
}


# figure out how to handle incoming qaqc data ####

req = GET("http://data.neonscience.org/api/v0/products/DP1.20033.001")
txt = content(req, as="text")
avail = fromJSON(txt, simplifyDataFrame=TRUE, flatten=TRUE)

urls = unlist(avail$data$siteCodes$availableDataUrls)

d = GET(urls[5])
d = fromJSON(content(d, as="text"))

data2 = read.delim(d$data$files$url
    [intersect(grep("expanded", d$data$files$name),
        grep("15_minute", d$data$files$name))], sep=",")
nitr2 = data2[!is.na(data2$surfWaterNitrateMean &
        data2$surfWaterNitrateMean != -1),]

# nitr2$alphaQM #alpha = 1 = test failed (this registers whether that happened across all tests)
# nitr2$betaQM #same for unable to test (lack of ancillary data)
nitr2$finalQF #1=fail, 0=pass
nitr2$finalQFSciRvw #passed science review? 1=fail, 0=pass/not reviewed

nitr2$flag = 0
nitr2$flag[nitr2$finalQF | nitr2$finalQFSciRvw] = 1

nitr2$flag[sample(c(TRUE, FALSE), nrow(nitr2), replace=TRUE)] = 1
nitr2 = nitr2[1:10, c('startDateTime', 'surfWaterNitrateMean', 'flag')]
library(accelerometry)
nitr2$flag
nitr2$startDateTime = as.character(nitr2$startDateTime)
nitr2$startDateTime = gsub('T', ' ', nitr2$startDateTime)
nitr2$startDateTime = gsub('Z', '', nitr2$startDateTime)


r = rle2(nitr2$flag, indices=TRUE, return.list=TRUE)
rlog = as.logical(r$values)
flag_run_starts = nitr2$startDateTime[r$starts[rlog]]
flag_run_ends = nitr2$startDateTime[r$stops[rlog]]
flag_data = data.frame('startDate'=flag_run_starts)
flag_data$endDate = flag_run_ends
flag_data$region = site_resp$data$stateCode
flag_data$site = site_resp$data$siteCode
flag_data$variable = 'Nitrate_mgL'
flag_data$flag = 'Questionable'
flag_data$comment = 'At least one NEON QC test did not pass'
flag_data$by = -900

con = dbConnect(RMariaDB::MariaDB(), dbname='sp',
    username='root', password='pass')

dbWriteTable(con, 'flag', flag_data, append=TRUE)

res = dbSendQuery(con, paste0("SELECT id FROM flag WHERE startDate IN ('",
    paste(flag_run_starts, collapse="','"), "');"))
resout = dbFetch(res)
dbClearResult(res)
flag_ids = resout$id


# put one site's data in the database ####

flagidvec = rep(flag_ids, r$lengths[as.logical(r$values)])
tryCatch(nitr2$flag[nitr2$flag == 1] <- flagidvec,
    error=function(e) print('log error here'))

nitrate_molec_mass = 62.0049
flag_data$value = (nitr2$surfWaterNitrateMean * nitrate_molec_mass) / 1000

sens_data = nitr2
colnames(sens_data) = c('DateTime_UTC', 'value', 'flag')
sens_data$region = site_resp$data$stateCode
sens_data$site = site_resp$data$siteCode
sens_data$variable = 'Nitrate_mgL'
sens_data$upload_id = -900

dbWriteTable(con, 'data', sens_data, append=TRUE)

# Disconnect from the database
dbDisconnect(con)

