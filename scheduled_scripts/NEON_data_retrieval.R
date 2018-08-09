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

#DO must always be first in these vectors. Sitemonths from the other datasets
#will be ignored if they're not represented in DO.
products = c('DO_mgL', 'Nitrate_mgL', 'O2GasTransferVelocity_ms')
prods_abb = c('DO', 'Nitrate', 'O2GasTransferVelocity')
prod_codes = c('DP1.20288.001', 'DP1.20033.001', 'DP1.20190.001')

varname_mappings = list(sensorDepth='Level_m',
    specificConductance='SpecCond_uScm',
    dissolvedOxygen='DO_mgL',
    dissolvedOxygenSaturation='DOsat_pct',
    pH='pH',
    chlorophyll='ChlorophyllA_ugL',
    turbidity='Turbidity_FNU',
    fDOM='fDOM_ppb')

#update log file
write(paste('\n    Running script at:', Sys.time()),
    '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)

#query sites already in our database
res = dbSendQuery(con, paste("SELECT DISTINCT site",
    "FROM data WHERE upload_id=-900"))
resout = dbFetch(res)
dbClearResult(res)
known_sites = resout$site

if(length(known_sites)){
    known_sites = unique(str_split(known_sites, '_')[[1]][1]) #remove _up/_down
}

for(p in 1:length(products)){

    #get lists of retreived sets
    res = dbSendQuery(con, paste0("SELECT DISTINCT site, MID(DateTime_UTC, 1, 7) ",
        "AS date FROM data WHERE upload_id=-900 and variable='", products[p], "';"))
    # "AS date FROM data WHERE upload_id=-900 and variable='Nitrate_mgL'"))
    resout = dbFetch(res)
    dbClearResult(res)
    retrieved_sets = paste(resout$site, resout$date)

    #for Nitrate and k, only ingest datasets for which we have DO data
    if(prods_abb[p] == 'DO'){
        relevant_sitemonths = retrieved_sets
    }

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

    #download list of available datasets for the current data product
    write(paste('Checking for new', prods_abb[p], 'data.'),
        '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)
    req = GET(paste0("http://data.neonscience.org/api/v0/products/", prod_codes[p]))
    txt = content(req, as="text")
    neondata = fromJSON(txt, simplifyDataFrame=TRUE, flatten=TRUE)

    #get available urls, sites, and dates
    urls = unlist(neondata$data$siteCodes$availableDataUrls)
    avail_sets = str_match(urls, '(?:.*)/([A-Z]{4})/([0-9]{4}-[0-9]{2})')

    #determine which are new and worth grabbing (represented in DO dataset)
    sets_to_grab = vector()
    for(i in 1:nrow(avail_sets)){
        avail_sitemo = paste(avail_sets[i,2], avail_sets[i,3])
        if(! avail_sitemo %in% retrieved_sets){
            sets_to_grab = append(sets_to_grab, i)
        }
    }
    sets_to_grab = as.data.frame(avail_sets[sets_to_grab,],
        stringsAsFactors=FALSE)

    if(prods_abb[p] == 'DO'){
        relevant_sitemonths = c(relevant_sitemonths,
            do.call(paste, sets_to_grab[,2:3]))
    } else {
        in_DO = do.call(paste, sets_to_grab[,2:3]) %in% relevant_sitemonths
        sets_to_grab = sets_to_grab[in_DO,]
    }

    #filter sets known to have issues
    if(prods_abb[p] != 'DO'){
        dataset_blacklist = readLines(paste0('../../logs_etc/NEON/NEON_blacklist_',
            prods_abb[p], '.txt'))
        sets_to_grab = sets_to_grab[! sets_to_grab[,1] %in% dataset_blacklist,]
    }

    #process new datasets one at a time
    write(paste(nrow(sets_to_grab), 'new', prods_abb[p], 'set(s) to add.'),
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

        if(prods_abb[p] %in% c('DO', 'O2GasTransferVelocity')){
            data_inds = intersect(grep("expanded", d$data$files$name),
                grep("instantaneous", d$data$files$name))
        } else {
            # if(prods_abb[p] == 'Nitrate'){
            data_inds = intersect(grep("expanded", d$data$files$name),
                grep("15_minute", d$data$files$name))
            # } else {
            #     data_inds = intersect(grep("expanded", d$data$files$name),
            #         grep("15_minute", d$data$files$name))
            # }
        }

        # two_stations = ifelse(length(data_inds) == 2, TRUE, FALSE)

        #download site data
        req = GET(paste0('http://data.neonscience.org/api/v0/sites/', site))
        txt = content(req, as="text")
        site_resp = fromJSON(txt, simplifyDataFrame=TRUE, flatten=TRUE)

        #update site table if this site is new
        if(! site %in% known_sites){

            cur_time = Sys.time()
            attr(cur_time,'tzone') = 'UTC'

            #create data frame to insert
            site_data = data.frame('region'=rep(site_resp$data$stateCode, 2),
                'site'=c(paste0(site_resp$data$siteCode, '_up'),
                    paste0(site_resp$data$siteCode, '_down')),
                'name'=c(paste(site_resp$data$siteDescription, 'Upstream'),
                    paste(site_resp$data$siteDescription, 'Downstream')),
                'latitude'=rep(site_resp$data$siteLatitude, 2),
                'longitude'=rep(site_resp$data$siteLongitude, 2),
                'usgs'=rep(NA, 2), 'addDate'=rep(cur_time, 2),
                'embargo'=rep(0, 2), 'by'=rep(-900, 2),
                'contact'=rep('NEON', 2), 'contactEmail'=rep(NA, 2))

            dbWriteTable(con, 'site', site_data, append=TRUE)

            write(paste('Added new site: ', site),
                '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)

            known_sites = append(known_sites, site)
        }

        #determine which dataset is upstream/downstream if necessary
        if(length(data_inds) == 2){
            position = str_split(d$data$files$name[data_inds[1]], '\\.')[[1]][7]
            updown_order = ifelse(position == '101', 1:2, 2:1)
        }

        for(j in 1:length(data_inds)){

            #download data
            data = read.delim(d$data$files$url[data_inds[j]], sep=",")
            # data = read.delim(d$data$files$url
            #     [intersect(grep("expanded", d$data$files$name),
            #         grep("15_minute", d$data$files$name))], sep=",")

            #get list of variables included
            varind = grep('SciRvw', colnames(data))
            rgx = str_match(colnames(data)[varind],
                '^(\\w*)(?:FinalQFSciRvw|SciRvwQF)$')
            varlist = flagprefixlist = rgx[,2]
            if('specificCond' %in% varlist){
                varlist[which(varlist == 'specificCond')] =
                    'specificConductance'
            }
            if('dissolvedOxygenSat' %in% varlist){
                varlist[which(varlist == 'dissolvedOxygenSat')] =
                    'dissolvedOxygenSaturation'
            }
            varlist = varlist[varlist != 'fDOM']


            for(k in 1:length(varlist)){

                # na_filt = data[!is.na(data[,v]) & data[,v] >= 0,,
                #     drop=FALSE]
                # na_filt = data[!is.na(data$surfWaterNitrateMean &
                #         data$surfWaterNitrateMean != -1),]

                #if it's wonky, move on and add the url to a blacklist
                # weak_coverage = dim(na_filt)[1] < 10
                na_filt = data[!is.na(data[,varlist[k]]) &
                    data[,varlist[k]] >= 0,] # <0 = error
                weak_coverage = nrow(na_filt) / nrow(data) < 0.01
                # mostly_err = sum(data[,v] < 0, na.rm=TRUE) / nrow(data) > 0.9
                if(weak_coverage){
                    write(paste('Weak coverage in', varlist[k], 'dataset:',
                        site, date), '../../logs_etc/NEON/NEON_ingest.log',
                        append=TRUE)

                    #blacklist problematic datasets so they don't get checked
                    #each time and clog the logfile. Doesn't apply to water qual
                    #data because it includes many variables.
                    if(prods_abb[p] == 'Nitrate'){
                        write(url, paste0('../../logs_etc/NEON/NEON_blacklist',
                            prods_abb[p], '.txt', append=TRUE)
                    }

                    next
                }
                # if(mostly_err){
                #     write(paste('Dataset mostly errors: ', site, date),
                #         '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)
                #
                #     write(url, '../../logs_etc/NEON/NEON_blacklist',
                #         prods_abb[p], '.txt', append=TRUE)
                #     next
                # }

                #compose flag column names
                neonflag1 = paste0(flagprefixlist[k], 'FinalQF')
                neonflag2 = paste0(varlist[k], 'FinalQF')
                litflag1 = paste0(flagprefixlist[k], 'FinalQFSciRvw')
                litflag2 = paste0(flagprefixlist[k], 'SciRvwQF')

                #replace flag=NA with flag=0
                tryCatch({ #sometimes literature flag column has one name...
                    na_filt[is.na(na_filt[,litflag1]), litflag1] = 0
                }, error=function(e){})
                tryCatch({ #sometimes another
                    na_filt[is.na(na_filt[,litflag2]), litflag2] = 0
                }, error=function(e){})

                #compress NEON flag information into one column. flag=1, no flag=0
                #in NEON parlance, 1=error, 0=good/not reviewed, -1=untestable.
                #for final QA and sci review though, it's just 1 or 0.
                #take into account inconsistent variable names.
                na_filt$flag = 0
                flagcols = intersect(colnames(na_filt),
                    c(neonflag1, neonflag2, litflag1, litflag2))

                if(length(flagcols) == 2){
                    flagged = mapply(`|`, na_filt[,flagcols[1]],
                        na_filt[,flagcols[2]])
                    na_filt$flag[flagged] = 1
                } else {
                    na_filt[,flagcols] = 1
                }

                # tryCatch({
                #     na_filt$flag[na_filt[,neonflag1] | na_filt[,litflag1]] = 1
                # }, error=function(e){})
                # tryCatch({
                #     na_filt$flag[na_filt[,neonflag2] | na_filt[,litflag1]] = 1
                # }, error=function(e){})
                # tryCatch({
                #     na_filt$flag[na_filt[,neonflag1] | na_filt[,litflag2]] = 1
                # }, error=function(e){})
                # tryCatch({
                #     na_filt$flag[na_filt[,neonflag2] | na_filt[,litflag2]] = 1
                # }, error=function(e){})
                # tryCatch({
                #     na_filt$flag[as.logical(na_filt[,litflag2])] = 1 #depth
                # }, error=function(e){})


                #reformat colnames, etc.
                na_filt = na_filt[, c('startDateTime', varlist[k], 'flag')]
                # na_filt = na_filt[, c('startDateTime', 'surfWaterNitrateMean', 'flag')]
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
                    if(prods_abb[p] == 'Nitrate'){
                        site_suffix = '_down'
                    } else {
                        if(j == 1)
                        site_suffix =
                    flag_data$site = site_resp$data$siteCode
                    flag_data$variable = varname_mappings[[varlist[k]]]
                    flag_data$flag = 'Questionable'
                    flag_data$comment = 'At least one NEON QC test did not pass'
                    flag_data$by = -900

                    dbWriteTable(con, 'flag', flag_data, append=TRUE)

                    #get vector of resultant flag IDs to include in data table
                    res = dbSendQuery(con,
                        paste0("SELECT id FROM flag WHERE startDate IN ",
                        "('", paste(flag_run_starts, collapse="','"),
                            "') AND `by`=-900;"))
                    resout = dbFetch(res)
                    dbClearResult(res)
                    flag_ids = resout$id

                    write(paste('Added', length(flag_ids), varlist[k],
                        'flag IDs for: ', site, date),
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
                                prods_abb[p], site, date),
                                '../../logs_etc/NEON/NEON_ingest.log',
                                append=TRUE)
                            next
                        }
                    )
                }
                na_filt$flag[na_filt$flag == 0] = NA
                options(warn=0)

                #assemble rest of data frame to insert
                colnames(na_filt) = c('DateTime_UTC', 'value', 'flag')
                na_filt$region = site_resp$data$stateCode
                na_filt$site = site_resp$data$siteCode
                na_filt$variable = varname_mappings[[varlist[k]]]
                na_filt$upload_id = -900

                if(prods_abb[p] == 'Nitrate'){
                    nitrate_molec_mass = 62.0049
                    na_filt$value = (na_filt$value * nitrate_molec_mass) / 1000
                }
                if(prods_abb[p] == 'O2GasTransferVelocity'){
                }

                dbWriteTable(con, 'data', na_filt, append=TRUE)

                write(paste('Added', nrow(na_filt), varlist[k],
                    'records for: ', site, date),
                    '../../logs_etc/NEON/NEON_ingest.log', append=TRUE)
            }
        }
    }
}

dbDisconnect(con)

#todo: average 5 min stuff by 30 (thts the interval that water qual comes in)
#the additional (non instantaneous) file for each site may contain depth (this is buoy)
#just determined sensor updown order, now utilize that info
