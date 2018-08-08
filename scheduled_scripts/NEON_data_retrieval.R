# library(devtools)
# devtools::install_github("NEONScience/NEON-geolocation/geoNEON")
# devtools::install_github("NEONScience/NEON-utilities/neonUtilities")
# devtools::install_github('NEONScience/NEON-reaeration/reaRate')

library(httr)
library(jsonlite)
library(dplyr)
library(downloader)
library(RMariaDB)
library(DBI)
library(stringr)
library(accelerometry)
library(reaRate)
# library(geoNEON)
# library(neonUtilities)

setwd('/home/mike/git/streampulse/server_copy/sp/scheduled_scripts/')
# setwd('/home/aaron/sp/scheduled_scripts/')

pw = readLines('/home/mike/Dropbox/stuff_2/credentials/spdb.txt')
con = dbConnect(RMariaDB::MariaDB(), dbname='sp',
    username='root', password=pw)

# variables = c('Nitrate_mgL')
products = c('DO_mgL')
# var_codes = c('DP1.20033.001') #DP1.20288.001 wq; DP1.20190.001 rea
prod_codes = c('DP1.20288.001')
for(p in 1:length(products)){

    #get lists of retreived sets for nitrate (N), gas transfer velocity (K) and O2 (O)
    res = dbSendQuery(con, paste0("SELECT DISTINCT site, MID(DateTime_UTC, 1, 7) ",
        "AS date FROM data WHERE upload_id=-900 and variable='", products[p], "';"))
    # "AS date FROM data WHERE upload_id=-900 and variable='Nitrate_mgL'"))
    resout = dbFetch(res)
    dbClearResult(res)
    retrieved_sets = paste(resout$site, resout$date)

    # res = dbSendQuery(con, paste0("SELECT DISTINCT site, MID(DateTime_UTC, 1, 7) ",
    #     "AS date FROM data WHERE upload_id=-900 and variable='Nitrate_mgL'"))
    # resout = dbFetch(res)
    # dbClearResult(res)
    # retrieved_sets = paste(resout$site, resout$date)
    #
    # res = dbSendQuery(con, paste0("SELECT DISTINCT site, MID(DateTime_UTC, 1, 7) ",
    #     "AS date FROM data WHERE upload_id=-900 and variable='Nitrate_mgL'"))
    # resout = dbFetch(res)
    # dbClearResult(res)
    # retrieved_sets_N = paste(resout$site, resout$date)

    res = dbSendQuery(con, paste("SELECT DISTINCT site",
        "FROM data WHERE upload_id=-900"))
    resout = dbFetch(res)
    dbClearResult(res)
    known_sites = resout$site

    #update log file
    write(paste('\n    Running script at:', Sys.time()),
        '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)

    #download list of available datasets for the current data product
    write(paste('Checking for new', products[p], 'data.'),
        '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)
    req = GET(paste0("http://data.neonscience.org/api/v0/products/", prod_codes[p]))
    txt = content(req, as="text")
    neondata = fromJSON(txt, simplifyDataFrame=TRUE, flatten=TRUE)

    #get available urls, sites, and dates
    urls = unlist(neondata$data$siteCodes$availableDataUrls)
    avail_sets = str_match(urls, '(?:.*)/([A-Z]{4})/([0-9]{4}-[0-9]{2})')

    #determine which are new
    sets_to_grab = vector()
    for(i in 1:nrow(avail_sets)){
        avail_sitemo = paste(avail_sets[i,2], avail_sets[i,3])
        if(! avail_sitemo %in% retrieved_sets){
            sets_to_grab = append(sets_to_grab, i)
        }
    }
    sets_to_grab = avail_sets[sets_to_grab,]

    #filter sets known to have issues
    dataset_blacklist = readLines(paste0('../../logs_etc/NEON/NEON_blacklist_',
        strsplit(products[p], '_')[[1]][1], '.txt'))
    sets_to_grab = sets_to_grab[! sets_to_grab[,1] %in% dataset_blacklist,]

    #process new datasets one at a time
    write(paste(nrow(sets_to_grab), 'new sets to add.'),
        '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)

    for(i in 1:nrow(sets_to_grab)){

        url = sets_to_grab[i,1]
        site = sets_to_grab[i,2]
        date = sets_to_grab[i,3]

        write(paste('Processing:', site, date),
            '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)

        #download a dataset for one site and month
        d = GET(url)
        d = fromJSON(content(d, as="text"))


        if(products[p] %in% c('DO_mgL', 'O2GasTransferVelocity_ms')){
            data_inds = intersect(grep("expanded", d$data$files$name),
                grep("instantaneous", d$data$files$name))
        } else {
            # if(products[p] == 'Nitrate_mgL'){
            data_inds = intersect(grep("expanded", d$data$files$name),
                grep("15_minute", d$data$files$name))
            # } else {
            #     data_inds = intersect(grep("expanded", d$data$files$name),
            #         grep("15_minute", d$data$files$name))
            # }
        }

        for(j in 1:length(data_inds)){
            data = read.delim(d$data$files$url[data_inds[j]] , sep=",")
        }
        # data = read.delim(d$data$files$url
        #     [intersect(grep("expanded", d$data$files$name),
        #         grep("15_minute", d$data$files$name))], sep=",")


        na_filt = data[!is.na(data$surfWaterNitrateMean &
                data$surfWaterNitrateMean != -1),]

        #if it's wonky, move on and add the url to a blacklist
        weak_coverage = dim(na_filt)[1] < 10
        neg_ones = sum(na_filt$surfWaterNitrateMean == -1) / nrow(na_filt) > 0.9
        if(weak_coverage){
            write(paste('Weak coverage in dataset:', site, date),
                '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)

            write(url, '../../logs_etc/NEON/NEON_blacklist.txt', append=TRUE)
            next
        }
        if(neg_ones){
            write(paste('Dataset mostly errors: ', site, date),
                '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)

            write(url, '../../logs_etc/NEON/NEON_blacklist.txt', append=TRUE)
            next
        }

        #download site data
        req = GET(paste0('http://data.neonscience.org/api/v0/sites/', site))
        txt = content(req, as="text")
        site_resp = fromJSON(txt, simplifyDataFrame=TRUE, flatten=TRUE)

        #update site table if this site is new
        if(! site %in% known_sites){

            cur_time = Sys.time()
            attr(cur_time,'tzone') = 'UTC'

            #create data frame to insert
            site_data = data.frame('region'=site_resp$data$stateCode,
                'site'=site_resp$data$siteCode,
                'name'=site_resp$data$siteDescription,
                'latitude'=site_resp$data$siteLatitude,
                'longitude'=site_resp$data$siteLongitude,
                'usgs'=NA, 'addDate'=cur_time, 'embargo'=0, 'by'=-900,
                'contact'='NEON', 'contactEmail'=NA)

            dbWriteTable(con, 'site', site_data, append=TRUE)

            write(paste('Added new site: ', site),
                '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)

            known_sites = append(known_sites, site)
        }

        #compress NEON flag information into one column. flag=1, no flag=0
        na_filt$flag = 0
        na_filt$flag[na_filt$finalQF | na_filt$finalQFSciRvw] = 1

        #reformat colnames, etc.
        na_filt = na_filt[, c('startDateTime', 'surfWaterNitrateMean', 'flag')]
        na_filt$startDateTime = as.character(na_filt$startDateTime)
        na_filt$startDateTime = gsub('T', ' ', na_filt$startDateTime)
        na_filt$startDateTime = gsub('Z', '', na_filt$startDateTime)

        #update flag table if there are any flags
        if(any(na_filt$flag == 1)){

            #locate blocks of flagged data
            r = rle2(na_filt$flag, indices=TRUE, return.list=TRUE)
            rlog = as.logical(r$values)
            flag_run_starts = na_filt$startDateTime[r$starts[rlog]]
            flag_run_ends = na_filt$startDateTime[r$stops[rlog]]

            #create data frame to insert
            flag_data = data.frame('startDate'=flag_run_starts)
            flag_data$endDate = flag_run_ends
            flag_data$region = site_resp$data$stateCode
            flag_data$site = site_resp$data$siteCode
            flag_data$variable = 'Nitrate_mgL'
            flag_data$flag = 'Questionable'
            flag_data$comment = 'At least one NEON QC test did not pass'
            flag_data$by = -900

            dbWriteTable(con, 'flag', flag_data, append=TRUE)

            #get vector of resultant flag IDs to include in data table
            res = dbSendQuery(con, paste0("SELECT id FROM flag WHERE startDate IN ",
                "('", paste(flag_run_starts, collapse="','"), "') AND `by`=-900;"))
            resout = dbFetch(res)
            dbClearResult(res)
            flag_ids = resout$id

            write(paste('Added', length(flag_ids), 'flag IDs for: ', site, date),
                '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)
        }

        #add flag IDs to data table.
        options(warn=3) #if flagidvec isn't the right size, raise an exception
        if(exists('flag_ids')){

            #flagidvec should always fit, but in case the below is buggy, it'll
            #log an error and go to the next url
            flagidvec = rep(flag_ids, r$lengths[as.logical(r$values)])
            tryCatch(na_filt$flag[na_filt$flag == 1] <- flagidvec,
                error=function(e){
                    write(paste('Error with flagidvec insertion for:',
                        site, date), '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)
                    next
                }
            )
        }
        na_filt$flag[na_filt$flag == 0] = NA
        options(warn=0)

        #assemble rest of data frame to insert
        colnames(na_filt) = c('DateTime_UTC', 'value', 'flag')
        nitrate_molec_mass = 62.0049
        na_filt$value = (na_filt$value * nitrate_molec_mass) / 1000
        na_filt$region = site_resp$data$stateCode
        na_filt$site = site_resp$data$siteCode
        na_filt$variable = 'Nitrate_mgL'
        na_filt$upload_id = -900

        dbWriteTable(con, 'data', na_filt, append=TRUE)

        write(paste('Added', nrow(na_filt), 'records for: ', site, date),
            '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)
    }

    dbDisconnect(con)

