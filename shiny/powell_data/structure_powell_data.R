library(lubridate)
library(stringr)

setwd('~/git/streampulse/server_copy/sp/shiny/')
powIn = dir('powell_data/inData', pattern='inData')
powOut = dir('powell_data/outData', pattern='outData')
powOutEx = dir('powell_data/outExtra', pattern='outExtra')

estpred = readRDS('powell_data/estpred.rds')
conf = readRDS('powell_data/config.rds')
diagn = readRDS('powell_data/diag.rds')

PI = readRDS(paste0('powell_data/inData/', powIn[1]))
PO = readRDS(paste0('powell_data/outData/', powOut[1]))
PE = readRDS(paste0('powell_data/outExtra/', powOutEx[1]))

pin = substr(powIn, 8, nchar(powIn))
pout = substr(powOut, 9, nchar(powOut))
pex = substr(powOutEx, 10, nchar(powOutEx))

for(i in 1:length(powIn)){

    PI = readRDS(paste0('powell_data/inData/', powIn[i]))
    PO = readRDS(paste0('powell_data/outData/', powOut[i]))
    PO$date = as.Date(PO$date)

    Pc = str_match(powIn[i], '^inData_([A-Za-z]{2})_([0-9]+)_([0-9]{4})')[,2:4]
    # PE = readRDS(paste0('powell_data/outExtra/outExtra_', Pc[1], '_',
    #     Pc[2], '.rds'))
    # Ps = str_match(powIn[i], '^inData_[A-Za-z]{2}_([0-9]+)_[0-9]{4}.rds$')[,2]
    Ps = paste0('nwis_', Pc[2])
    Es = estpred[estpred$site_name == Ps,]
    Es = Es[year(Es$date) == Pc[3],]
    Es$date = as.Date(Es$date)

    shinylist = list(predictions=Es,
        # fit=list(daily=PO, KQ_binned=PE$KQ_binned),
        fit=list(daily=PO), #cant do KQ nodes because data_index field is all NA
        data=PI, #missing DO.mod (not published)
        data_daily=Es[,c('date','discharge')])

    saveRDS(shinylist, paste0('powell_data/shiny_lists/', Pc[1], '_', Pc[2],
        '_', Pc[3], '.rds'))
}

# xd = readRDS('powell_data/shiny_lists/AK_15298040_2010.rds')
# xd = readRDS('powell_data/shiny_lists/AK_15298040_2016.rds')

