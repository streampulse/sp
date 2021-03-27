
library(RMariaDB)
library(DBI)
library(tidyverse)
library(glue)

setwd('/home/aaron/sp/shiny/model_viz/data/')
#setwd('~/git/streampulse/server_copy/sp/shiny/model_viz/data/')

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
    "embargo as embargoYears, contact, contactEmail, firstRecord, ",
    "lastRecord, variableList, grabVarList, concat(region, '_', site) as ",
    "regionsite from site;"))

modspecs = dbGetQuery(con, 'select * from model;') %>% as_tibble()

embargo_end = sitedata$addDate + 365 * 24 * 60 * 60 * sitedata$embargoYears
embargoed_sites = sitedata[Sys.time() <= embargo_end, 'regionsite']

regsite = str_match(mods, 'modOut_(.*?)_[0-9]{4}.rds$')[, 2]
mods = mods[! regsite %in% embargoed_sites]

time_now = Sys.time()
attr(time_now, 'tzone') = 'UTC'

results_overwrite = details_append = input_data_deets = tibble()
for(i in 1:length(mods)){

    m = mods[i]
    mod = readRDS(m)
    r_s_y = str_match(m, 'modOut_([A-Za-z]{2})_(.+?)_([0-9]{4}).rds$')[2:4]

    #make a tibble that will update the daily model results table
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
            K600_upper=K600_daily_97.5pct, valid_day, warnings, errors) %>%
        bind_rows(results_overwrite)

    #make a tibble that will update the model specs table
    # details_append = tibble(region = r_s_y[1],
    #                            site = r_s_y[2],
    #                            year = r_s_y[3]) %>%

    input_data_deets = mod$data %>%
        as_tibble() %>%
        summarize(across(-any_of(c('date', 'solar.time')),
                         list(mean = ~mean(., na.rm = TRUE),
                              max = ~max(., na.rm = TRUE),
                              sd = ~sd(., na.rm = TRUE)))) %>%
        mutate(region = !!r_s_y[1],
               site = !!r_s_y[2],
               year = !!r_s_y[3]) %>%
        select(region, site, year, everything()) %>%
        bind_rows(input_data_deets)

    thismod = filter(modspecs,
           region == !!r_s_y[1],
           site == !!r_s_y[2],
           year == !!r_s_y[3])

    if(nrow(thismod) == 0){

        #nabbed from elsewhere, so some redundancy
        spec_str = substr(m, 8, nchar(m)-4)
        spec_vec = strsplit(spec_str, '_')[[1]]

        preds = readRDS(paste0('predictions_', spec_str, '.rds'))

        modyear = spec_vec[3]
        # modyear = ifelse(substr(spec_vec[3],1,4) == substr(spec_vec[4],1,4),
        #     substr(spec_vec[3],1,4), 0)

        rmse = sqrt(mean((mod$data$DO.mod - mod$data$DO.obs)^2, na.rm=TRUE))

        gpp_upperCI = abs(preds$GPP.upper - preds$GPP)
        gpp_lowerCI = abs(preds$GPP.lower - preds$GPP)
        gpp_95ci = mean(c(gpp_upperCI, gpp_lowerCI), na.rm=TRUE)
        er_upperCI = abs(preds$ER.upper - preds$ER)
        er_lowerCI = abs(preds$ER.lower - preds$ER)
        er_95ci = mean(c(er_upperCI, er_lowerCI), na.rm=TRUE)

        prop_pos_er = sum(preds$ER > 0, na.rm=TRUE) / length(preds$ER)
        prop_neg_gpp = sum(preds$GPP < 0, na.rm=TRUE) / length(preds$GPP)

        pearson = cor(mod$fit$daily$ER_mean, mod$fit$daily$K600_daily_mean,
                      use='na.or.complete')

        # coverage = as.numeric(as.Date(spec_vec[4]) - as.Date(spec_vec[3]))
        coverage = as.numeric(as.Date(preds$date[nrow(preds)]) -
                                  as.Date(preds$date[1]))

        rc = ifelse(spec_vec[1] == 'NC' && spec_vec[2] != 'Eno', TRUE, FALSE)

        kmax = max(mod$fit$daily$K600_daily_mean, na.rm=TRUE)

        details_append = tibble(
            region=spec_vec[1],
            site=spec_vec[2],
            start_date=as.Date(preds$date[1]),
            end_date=as.Date(preds$date[nrow(preds)]),
            requested_variables='all',
            year=modyear,
            run_finished=time_now,
            model='streamMetabolizer',
            method='bayes',
            engine='stan',
            rm_flagged="Bad Data,Questionable",
            used_rating_curve=rc,
            pool='binned',
            proc_err=TRUE,
            obs_err=TRUE,
            proc_acor=FALSE,
            ode_method='trapezoid',
            deficit_src='DO-mod',
            interv='15 min',
            fillgaps='interpolation',
            estimate_areal_depth=TRUE,
            O2_GOF=rmse,
            GPP_95CI=gpp_95ci,
            ER_95CI=er_95ci,
            prop_pos_ER=prop_pos_er,
            prop_neg_GPP=prop_neg_gpp,
            ER_K600_cor=pearson,
            coverage=coverage,
            kmax=kmax,
            current_best=TRUE
        ) %>%
            bind_rows(details_append)
    }
}

results_overwrite = arrange(results_overwrite, region, site, year)
DBI::dbExecute(con, 'delete from results;')
DBI::dbExecute(con, 'alter table results auto_increment=1;')
DBI::dbWriteTable(con, 'results', results_overwrite, append=TRUE)

if(nrow(details_append) > 0){
    DBI::dbWriteTable(con, 'model', details_append, append=TRUE)
}

#some users will want this:
input_data_deets = arrange(input_data_deets, region, site, year)
write_csv(input_data_deets,
          '../../../../bulk_download_files/model_input_summary_data.csv')

dbDisconnect(con)
