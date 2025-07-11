# library(devtools)
# devtools::install_github("NEONScience/NEON-geolocation/geoNEON")
# devtools::install_github("NEONScience/NEON-utilities/neonUtilities")
# devtools::install_github('NEONScience/NEON-reaeration/reaRate')
#rm(list=ls()); cat('\014')

# setwd('/home/mike/git/streampulse/server_copy/sp/scheduled_scripts/')
# known_sites <- c("WALK", "MCRA", "PRIN", "MAYF", "PRPO", "SUGG", "BLUE", "LECO", "LEWI", "CARI", "ARIK",
#     "BARC", "GUIL", "COMO", "WLOU", "KING", "POSE", "MART", "CUPE", "HOPB", "MCDI", "REDB",
#     "BIGC", "TOOK", "BLDE", "OKSR", "SYCA", "CRAM", "BLWA", "PRLA", "LIRO", "TOMB", "FLNT", "TECR")

library(httr)
library(jsonlite)
library(data.table)
library(dplyr)
# library(downloader)
library(RMariaDB)
library(DBI)
library(stringr)
library(lubridate)
# library(reaRate)
# library(geoNEON)
# library(neonUtilities)

# setwd('/home/mike/git/streampulse/server_copy/sp/scheduled_scripts/')
setwd('/home/aaron/sp/scheduled_scripts/')

conf = readLines('../config.py')
extract_from_config = function(key) {
    ind = which(lapply(conf, function(x) grepl(key, x)) == TRUE)
    val = str_match(conf[ind], '.*\\"(.*)\\"')[2]
    return(val)
}
pw = extract_from_config('MYSQL_PW')
# pw = readLines('/home/mike/Dropbox/stuff_2/credentials/spdb.txt')

con = dbConnect(
    RMariaDB::MariaDB(),
    dbname = 'sp',
    # username='mike', password=pw)
    username = 'root',
    password = pw
)

#DO must always be first in these vectors. Sitemonths from the other datasets
#will be ignored if they're not represented in DO.
products = c(
    'DO_mgL',
    'Nitrate_mgL',
    'O2GasTransferVelocity_ms',
    'Discharge_m3s',
    'WaterTemp_C'
) #, 'Depth_m')
prods_abb = str_split(products, '_', simplify = TRUE)[, 1]
prod_codes = c(
    'DP1.20288.001',
    'DP1.20033.001',
    'DP1.20190.001',
    'DP4.00130.001',
    'DP1.20053.001'
) #, 'DP1.20016.001')
# NEON.DOM.SITE.DP1.20004.001, Barometric pressure above water on-buoy
prod_varlists = list(
    c(
        'Level_m',
        'SpecCond_uScm',
        'DO_mgL',
        'DOsat_pct',
        'pH',
        'ChlorophyllA_ugL',
        'Turbidity_FNU'
    ),
    'Nitrate_mgL',
    'O2GasTransferVelocity_ms',
    'Discharge_m3s',
    'WaterTemp_C'
) #,
# 'Depth_m')

varname_mappings = list(
    sensorDepth = 'Level_m',
    specificConductance = 'SpecCond_uScm',
    dissolvedOxygen = 'DO_mgL',
    dissolvedOxygenSaturation = 'DOsat_pct',
    localDissolvedOxygenSat = 'DOsat_pct',
    pH = 'pH',
    chlorophyll = 'ChlorophyllA_ugL',
    turbidity = 'Turbidity_FNU',
    fDOM = 'fDOM_ppb',
    surfWaterNitrateMean = 'Nitrate_mgL',
    maxpostDischarge = 'Discharge_m3s',
    surfWaterTempMean = 'WaterTemp_C',
    surfacewaterElevMean = 'Depth_m'
)

#update log file
write(
    paste('\n\tRunning script at:', Sys.time()),
    '../../logs_etc/NEON/NEON_ingest.log',
    append = TRUE
)

#query sites already in our database
# res = dbSendQuery(con, paste("SELECT DISTINCT MID(site, 1, 4) as site",
#     "FROM data WHERE upload_id=-900"))
res = dbSendQuery(
    con,
    paste(
        "SELECT DISTINCT MID(site, 1, 4) as site",
        "FROM site WHERE `by`=-900"
    )
)
resout = dbFetch(res)
dbClearResult(res)
known_sites = resout$site

# p=i=j=1;k=3
# p=6;i=414;j=1;k=1 #for testing depth
# sets_to_grab = sets_to_grab[61,]

for (p in 1:length(products)) {
    # print(paste('p=',p))

    if (prods_abb[p] == 'O2GasTransferVelocity') {
        write(
            'Skipping K for now.',
            '../../logs_etc/NEON/NEON_ingest.log',
            append = TRUE
        )
        next
    }

    #get lists of retreived sets
    res = dbSendQuery(
        con,
        paste0(
            "SELECT DISTINCT MID(site, 1, 4) as site, ",
            "MID(DateTime_UTC, 1, 7) ",
            "AS date FROM data WHERE upload_id=-900 and variable in ('",
            paste(prod_varlists[[p]], collapse = "','"),
            "');"
        )
    )
    resout = dbFetch(res)
    dbClearResult(res)
    retrieved_sets = paste(resout$site, resout$date)

    #for non-waterqual, only ingest datasets for which we have waterqual (DO, etc) data
    # if (prods_abb[p] == 'DO') {
    #     relevant_sitemonths = retrieved_sets
    # }

    #download list of available datasets for the current data product
    write(
        paste('Checking for new', prods_abb[p], 'data.'),
        '../../logs_etc/NEON/NEON_ingest.log',
        append = TRUE
    )
    req = GET(paste0(
        "http://data.neonscience.org/api/v0/products/",
        prod_codes[p]
    ))
    txt = content(req, as = "text")
    neondata = fromJSON(txt, simplifyDataFrame = TRUE, flatten = TRUE)

    #get available urls, sites, and dates
    urls = unlist(neondata$data$siteCodes$availableDataUrls)
    avail_sets = str_match(urls, '(?:.*)/([A-Z]{4})/([0-9]{4}-[0-9]{2})')

    #determine which are new and worth grabbing (represented in DO dataset)
    sets_to_grab = vector()
    for (ii in 1:nrow(avail_sets)) {
        avail_sitemo = paste(avail_sets[ii, 2], avail_sets[ii, 3])
        if (!avail_sitemo %in% retrieved_sets) {
            sets_to_grab = append(sets_to_grab, ii)
        }
    }
    sets_to_grab = as.data.frame(
        avail_sets[sets_to_grab, ],
        stringsAsFactors = FALSE
    )

    # if (prods_abb[p] == 'DO') {
    #     relevant_sitemonths = c(
    #         relevant_sitemonths,
    #         do.call(paste, sets_to_grab[, 2:3])
    #     )
    # } else {
    #     in_DO = do.call(paste, sets_to_grab[, 2:3]) %in% relevant_sitemonths
    #     sets_to_grab = sets_to_grab[in_DO, ]
    # }

    #filter sets known to have issues
    if (prods_abb[p] != 'DO') {
        dataset_blacklist = readLines(paste0(
            '../../logs_etc/NEON/NEON_blacklist_',
            prods_abb[p],
            '.txt'
        ))
        sets_to_grab = sets_to_grab[!sets_to_grab[, 1] %in% dataset_blacklist, ]
    }

    #process new datasets one at a time
    write(
        paste(nrow(sets_to_grab), 'new', prods_abb[p], 'set(s) to add.'),
        '../../logs_etc/NEON/NEON_ingest.log',
        append = TRUE
    )

    if (nrow(sets_to_grab) == 0) {
        next
    }

    d_collect <- data.frame()
    for (i in 1:nrow(sets_to_grab)) {
        # print(paste('i=',i))

        url = sets_to_grab[i, 1]
        site = sets_to_grab[i, 2]
        date = sets_to_grab[i, 3]

        write(
            paste('Processing:', site, date),
            '../../logs_etc/NEON/NEON_ingest.log',
            append = TRUE
        )

        #download a dataset for one site and month
        d = GET(url)
        d = fromJSON(content(d, as = "text"))

        if (prods_abb[p] %in% c('DO', 'O2GasTransferVelocity')) {
            data_inds = intersect(
                grep("expanded", d$data$files$name),
                grep("instantaneous", d$data$files$name)
            )
        } else if (prods_abb[p] == 'Nitrate') {
            data_inds = intersect(
                grep("expanded", d$data$files$name),
                grep("15_minute", d$data$files$name)
            )
        } else if (prods_abb[p] == 'WaterTemp') {
            data_inds = intersect(
                grep("expanded", d$data$files$name),
                grep("5min", d$data$files$name)
            )
            # if(length(data_inds) == 2){ #in case some sites have 2 depths
            #     name_components = strsplit(d$data$files$name[data_inds], '\\.')
            #     surface = sapply(name_components, function(x) x[7] == '101')
            #     data_inds = data_inds[surface]
            # }
        } else if (prods_abb[p] == 'Depth') {
            data_inds = intersect(
                grep("expanded", d$data$files$name),
                grep("5_min", d$data$files$name)
            )
        } else {
            data_inds = intersect(
                grep("expanded", d$data$files$name),
                grep("csd_continuousDischarge_pub", d$data$files$name)
            )
        }

        if (!length(data_inds)) {
            write(
                paste('Error: Datasets missing for', site, date),
                '../../logs_etc/NEON/NEON_ingest.log',
                append = TRUE
            )
            next
        }

        # two_stations = ifelse(length(data_inds) == 2, TRUE, FALSE)

        #download site data (needed for flags even if site known)
        req = GET(paste0('http://data.neonscience.org/api/v0/sites/', site))
        txt = content(req, as = "text")
        site_resp = fromJSON(txt, simplifyDataFrame = TRUE, flatten = TRUE)

        #skip this dataset if its sensor information is not available
        sensor_data_ind = grep("sensor_positions", d$data$files$name)[1]
        if (is.na(sensor_data_ind)) {
            write(
                paste(
                    'Problem with sensor data for site',
                    site,
                    '(',
                    prods_abb[p],
                    date,
                    ')'
                ),
                '../../logs_etc/NEON/NEON_ingest.log',
                append = TRUE
            )
            next
        }

        #update site table if this site is new
        if (!site %in% known_sites) {
            if (prods_abb[p] != 'DO') {
                write(
                    paste(
                        'Unknown site encountered for non-waterqual variable:',
                        prods_abb[p],
                        site,
                        date,
                        '. This should have been filtered.'
                    ),
                    '../../logs_etc/NEON/NEON_ingest.log',
                    append = TRUE
                )
                next
            }

            #get lat/long for upstream and downstream stations
            errflag = FALSE
            tryCatch(
                {
                    sensor_data_ind = grep(
                        "sensor_positions",
                        d$data$files$name
                    )[1]
                    sensor_pos = read.delim(
                        d$data$files$url[sensor_data_ind],
                        sep = ","
                    )
                    sensor_pos[2, 1] #raise exception if only one row
                },
                error = function(e) {
                    write(
                        paste(
                            'Problem with sensor positions for site',
                            site,
                            '(',
                            prods_abb[p],
                            date,
                            ')'
                        ),
                        '../../logs_etc/NEON/NEON_ingest.log',
                        append = TRUE
                    )
                    errflag <<- TRUE
                }
            )
            if (errflag) {
                next
            }

            cur_time = Sys.time()
            attr(cur_time, 'tzone') = 'UTC'

            #create data frame to insert
            site_data = data.frame(
                'region' = rep(site_resp$data$stateCode, 2),
                'site' = c(
                    paste0(site_resp$data$siteCode, '-up'),
                    paste0(site_resp$data$siteCode, '-down')
                ),
                'name' = c(
                    paste(site_resp$data$siteDescription, 'Upstream'),
                    paste(site_resp$data$siteDescription, 'Downstream')
                ),
                'latitude' = sensor_pos$referenceLatitude,
                'longitude' = sensor_pos$referenceLongitude,
                'usgs' = rep(NA, 2),
                'addDate' = rep(cur_time, 2),
                'embargo' = rep(0, 2),
                'by' = rep(-900, 2),
                'contact' = rep('NEON', 2),
                'contactEmail' = rep(NA, 2)
            )

            dbWriteTable(con, 'site', site_data, append = TRUE)

            write(
                paste('Added new site: ', site),
                '../../logs_etc/NEON/NEON_ingest.log',
                append = TRUE
            )

            known_sites = append(known_sites, site)
        }

        #determine which dataset is upstream/downstream if necessary
        updown_suffixes = c('-up', '-down')
        if (length(data_inds) == 2) {
            position = str_split(d$data$files$name[data_inds[1]], '\\.')[[1]][7]
            updown_order = if (position == '101') 1:2 else 2:1
        } else if (length(data_inds) == 1) {
            updown_order = 1:2 #this should never run
        } else {
            #something's wonky
            write(
                paste(
                    'Problem with data file number for site',
                    site,
                    '(',
                    prods_abb[p],
                    date,
                    ')'
                ),
                '../../logs_etc/NEON/NEON_ingest.log',
                append = TRUE
            )
            next
        }

        for (j in 1:length(data_inds)) {
            # print(paste('j=',j))

            #add appropriate suffix for upstream/downstream sites
            if (prods_abb[p] %in% c('Nitrate', 'Discharge')) {
                site_suffix = '-down' #these vars only measured at downstream
            } else {
                site_suffix = updown_suffixes[updown_order[j]]
            }
            site_with_suffix = paste0(site_resp$data$siteCode, site_suffix)

            #download data
            data = read.delim(d$data$files$url[data_inds[j]], sep = ",")

            #get list of variables included
            if (prods_abb[p] == 'DO') {
                varind = grep('SciRvw', colnames(data))
                rgx = str_match(
                    colnames(data)[varind],
                    '^(\\w*)(?:FinalQFSciRvw|SciRvwQF)$'
                )
                rgx <- rgx[!grepl('seaLevel|chlaRelFluoro', rgx[, 1]), ]
                varlist = flagprefixlist = rgx[, 2]
                if ('specificCond' %in% varlist) {
                    varlist[which(varlist == 'specificCond')] =
                        'specificConductance'
                }
                if ('dissolvedOxygenSat' %in% varlist) {
                    varlist[which(varlist == 'dissolvedOxygenSat')] =
                        'dissolvedOxygenSaturation'
                }
                if ('localDOSat' %in% varlist) {
                    varlist[which(varlist == 'localDOSat')] =
                        'localDissolvedOxygenSat'
                }
                varlist = varlist[varlist != 'fDOM']
            } else if (prods_abb[p] == 'Nitrate') {
                varlist = 'surfWaterNitrateMean'
                flagprefixlist = ''
            } else if (prods_abb[p] == 'WaterTemp') {
                varlist = 'surfWaterTempMean'
                flagprefixlist = ''
            } else if (prods_abb[p] == 'Depth') {
                varlist = 'surfacewaterElevMean'
                flagprefixlist = 'sWatElev'
            } else {
                #discharge
                varlist = 'maxpostDischarge'
                flagprefixlist = 'discharge'
            }

            for (k in 1:length(varlist)) {
                # print(paste('k=',k))

                current_var = varlist[k]
                current_var_u = varname_mappings[[varlist[k]]]

                #if it's wonky, move on and add the url to a blacklist
                na_filt = data[
                    !is.na(data[, current_var]) &
                        data[, current_var] >= 0,
                ] # <0 = error
                weak_coverage = nrow(na_filt) / nrow(data) < 0.01
                # if (!weak_coverage) {
                #     browser()
                # }
                if (weak_coverage) {
                    write(
                        paste(
                            'Insufficient coverage in',
                            current_var,
                            'for:',
                            site_with_suffix,
                            date
                        ),
                        '../../logs_etc/NEON/NEON_ingest.log',
                        append = TRUE
                    )

                    #blacklist problematic datasets so they don't get checked
                    #each time and clog the logfile. Doesn't apply to water qual
                    #data because it includes many variables.
                    if (
                        prods_abb[p] %in%
                            c('Nitrate', 'Discharge', 'WaterTemp', 'Depth')
                    ) {
                        write(
                            url,
                            paste0(
                                '../../logs_etc/NEON/NEON_blacklist_',
                                prods_abb[p],
                                '.txt'
                            ),
                            append = TRUE
                        )
                    }

                    next
                }

                #compose flag column names
                neonflag1 = paste0(flagprefixlist[k], 'FinalQF')
                neonflag2 = paste0(current_var, 'FinalQF')
                neonflag3 = paste0(flagprefixlist[k], 'finalQF')
                litflag1 = paste0(flagprefixlist[k], 'FinalQFSciRvw')
                litflag2 = paste0(flagprefixlist[k], 'SciRvwQF')
                litflag3 = paste0(flagprefixlist[k], 'finalQFSciRvw')

                #replace flag=NA with flag=0
                tryCatch(
                    {
                        #sometimes literature flag column has one name...
                        na_filt[is.na(na_filt[, litflag1]), litflag1] = 0
                    },
                    error = function(e) {}
                )
                tryCatch(
                    {
                        #sometimes another
                        na_filt[is.na(na_filt[, litflag2]), litflag2] = 0
                    },
                    error = function(e) {}
                )
                tryCatch(
                    {
                        #maybe even a third
                        na_filt[is.na(na_filt[, litflag3]), litflag3] = 0
                    },
                    error = function(e) {}
                )

                #compress NEON flag information into one column. flag=1, no flag=0
                #in NEON parlance, 1=error, 0=good/not reviewed, -1=untestable.
                #for final QA and sci review though, it's just 1 or 0.
                #take into account inconsistent variable names.
                na_filt$flag = 0
                flagcols = intersect(
                    colnames(na_filt),
                    c(
                        neonflag1,
                        neonflag2,
                        neonflag3,
                        litflag1,
                        litflag2,
                        litflag3
                    )
                )

                if (length(flagcols) == 2) {
                    flagged = mapply(
                        `|`,
                        na_filt[, flagcols[1]],
                        na_filt[, flagcols[2]]
                    )
                    na_filt$flag[flagged] = 1
                } else {
                    na_filt[, flagcols] = 1
                }

                #reformat colnames, etc.
                if ('startDateTime' %in% colnames(na_filt)) {
                    NULL #do nothing
                } else if ('startDate' %in% colnames(na_filt)) {
                    colnames(na_filt)[which(colnames(na_filt) == 'startDate')] =
                        'startDateTime'
                } else if ('endDate' %in% colnames(na_filt)) {
                    colnames(na_filt)[which(colnames(na_filt) == 'endDate')] =
                        'startDateTime'
                } else {
                    write(
                        paste(
                            'Datetime column not found for:',
                            current_var,
                            site_with_suffix,
                            date
                        ),
                        '../../logs_etc/NEON/NEON_ingest.log',
                        append = TRUE
                    )
                    next
                }

                na_filt = na_filt[, c('startDateTime', current_var, 'flag')]
                # na_filt = na_filt[, c('startDateTime', 'surfWaterNitrateMean', 'flag')]
                na_filt$startDateTime = as.character(na_filt$startDateTime)
                na_filt$startDateTime = gsub('T', ' ', na_filt$startDateTime)
                na_filt$startDateTime = gsub('Z', '', na_filt$startDateTime)

                #update flag table if there are any flags
                if (any(na_filt$flag == 1)) {
                    #locate blocks of flagged data
                    # r = rle2(na_filt$flag, indices=TRUE, return.list=TRUE)
                    r = rle(na_filt$flag)
                    ends = cumsum(r$lengths)
                    r = list(
                        values = r$values,
                        starts = c(1, ends[-length(ends)] + 1),
                        stops = ends,
                        lengths = r$lengths
                    )

                    rlog = as.logical(r$values)
                    flag_run_starts = na_filt$startDateTime[r$starts[rlog]]
                    flag_run_ends = na_filt$startDateTime[r$stops[rlog]]

                    #create data frame to insert
                    flag_data = data.frame('startDate' = flag_run_starts)
                    flag_data$endDate = flag_run_ends
                    flag_data$region = site_resp$data$stateCode
                    flag_data$site = site_with_suffix
                    flag_data$variable = current_var_u
                    flag_data$flag = 'Questionable'
                    flag_data$comment = 'At least one NEON QC test did not pass'
                    flag_data$by = -900

                    dbWriteTable(con, 'flag', flag_data, append = TRUE)

                    #duplicate flag data for upstream station for variables that
                    #are only measured at the downstream station.
                    if (prods_abb[p] %in% c('Nitrate', 'Discharge')) {
                        flag_data$site = paste0(
                            substr(flag_data$site, 1, 4),
                            '-up'
                        )
                        dbWriteTable(con, 'flag', flag_data, append = TRUE)
                    }

                    #get vector of resultant flag IDs to include in data table
                    flag_ids = c()
                    nfchunks = ceiling(length(flag_run_starts) / 200)
                    for (l in 1:nfchunks) {
                        if (l == nfchunks) {
                            ch = flag_run_starts
                        } else {
                            ch = flag_run_starts[1:200]
                            flag_run_starts =
                                flag_run_starts[201:length(flag_run_starts)]
                        }

                        res = dbSendQuery(
                            con,
                            paste0(
                                "SELECT id FROM flag WHERE startDate IN ",
                                "('",
                                paste(ch, collapse = "','"),
                                "') AND variable='",
                                current_var_u,
                                "' AND `by`=-900 AND region='",
                                site_resp$data$stateCode,
                                "' AND site='",
                                site_with_suffix,
                                "';"
                            )
                        )
                        resout = dbFetch(res)
                        dbClearResult(res)
                        chunkout = resout$id
                        flag_ids = c(flag_ids, chunkout)
                    }
                }

                #add flag IDs to data table.
                options(warn = 3) #if flagidvec isn't the right size, raise an exception
                if (exists('flag_ids')) {
                    #flagidvec should always fit, but in case the below is buggy,
                    #it'll log an error and go to the next url
                    errflag = FALSE
                    tryCatch(
                        {
                            flagidvec = rep(
                                flag_ids,
                                r$lengths[as.logical(r$values)]
                            )
                            na_filt$flag[na_filt$flag == 1] = flagidvec
                            write(
                                paste(
                                    'Added',
                                    length(flag_ids),
                                    current_var,
                                    'flag ID(s) for: ',
                                    site_with_suffix,
                                    date
                                ),
                                '../../logs_etc/NEON/NEON_ingest.log',
                                append = TRUE
                            )
                        },
                        error = function(e) {
                            write(
                                paste(
                                    'Error with flagidvec creation/insertion for:',
                                    current_var,
                                    site_with_suffix,
                                    date
                                ),
                                '../../logs_etc/NEON/NEON_ingest.log',
                                append = TRUE
                            )
                            errflag <<- TRUE
                        }
                    )
                    rm(flag_ids)
                    if (errflag) next
                }
                na_filt$flag[na_filt$flag == 0] = NA
                options(warn = 0)

                # thin to fifteen minute interval
                colnames(na_filt) = c('DateTime_UTC', 'value', 'flag')
                na_filt <- na_filt %>%
                    mutate(
                        m15 = floor_date(as.POSIXct(DateTime_UTC), '15 minutes')
                    ) %>%
                    group_by(m15) %>%
                    summarize(
                        DateTime_UTC = first(DateTime_UTC),
                        value = first(value),
                        flag = first(flag),
                        .groups = 'drop'
                    ) %>%
                    select(-m15)

                #assemble rest of data frame to insert
                na_filt$region = site_resp$data$stateCode
                na_filt$site = site_with_suffix
                na_filt$variable = current_var_u
                na_filt$upload_id = -900

                if (prods_abb[p] == 'Nitrate') {
                    nitrate_molec_mass = 62.0049
                    na_filt$value = (na_filt$value * nitrate_molec_mass) / 1000
                }
                if (prods_abb[p] == 'Discharge') {
                    na_filt$value = na_filt$value / 1000
                }
                if (prods_abb[p] == 'Depth') {
                    sensor_data_ind = grep(
                        "sensor_positions",
                        d$data$files$name
                    )[1]
                    sensor_pos = read.delim(
                        d$data$files$url[sensor_data_ind],
                        sep = ","
                    )
                    ref_elev = sensor_pos$referenceElevation[updown_order[j]]
                    offset = sensor_pos$zOffset[updown_order[j]]
                    na_filt$value = na_filt$value - ref_elev - offset
                }
                if (prods_abb[p] == 'O2GasTransferVelocity') {
                    print('this isnt hooked up yet')
                }

                d_collect <- bind_rows(d_collect, na_filt)

                #duplicate data for upstream station for variables that
                #are only measured at the downstream station.
                # if (prods_abb[p] %in% c('Nitrate', 'Discharge')) {
                #     na_filt$site = paste0(substr(na_filt$site, 1, 4), '-up')
                #     dbWriteTable(con, 'data', na_filt, append = TRUE)
                # }

                # write(
                #     paste(
                #         'Added',
                #         nrow(na_filt),
                #         current_var,
                #         'records for: ',
                #         site_with_suffix,
                #         date
                #     ),
                #     '../../logs_etc/NEON/NEON_ingest.log',
                #     append = TRUE
                # )
            }
        }
    }

    #below: two ways to ensure consistent sample interval of 15 mins. appears not
    #to be necessary after full test on DO product and all its variables+sites

    # d_collect <- d_collect %>%
    #     mutate(
    #         m15 = floor_date(as.POSIXct(DateTime_UTC), '15 minutes')
    #     ) %>%
    #     group_by(m15, site, variable) %>%
    #     summarize(across(everything(), first), .groups = 'drop') %>%
    #     select(-m15)

    # setDT(d_collect)
    # d_collect[, m15 := floor_date(as.POSIXct(DateTime_UTC), "15 minutes")]
    # summary_cols <- setdiff(names(d_collect), c("m15", "site", "variable"))
    # d_collect <- d_collect[, lapply(.SD, first), by = .(m15, site, variable)]
    # d_collect[, m15 := NULL]

    dbWriteTable(con, 'data', d_collect, append = TRUE)

    write(
        paste(
            'Added',
            nrow(d_collect),
            products[p],
            'records'
        ),
        '../../logs_etc/NEON/NEON_ingest.log',
        append = TRUE
    )
}

dbDisconnect(con)
