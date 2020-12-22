library(tidyverse)
library(imputeTS)
library(anomalize)
#library(feather)
library(lubridate)

setwd('/home/aaron/sp')
#setwd('/home/mike/git/streampulse/server_copy/sp')

#retrieve arguments passed from app.py
args = commandArgs(trailingOnly=TRUE)
names(args) = c('notificationEmail', 'tmpcode', 'region', 'site', 'report_filenames')
# args = list('tmpcode'='04b4447bb586')

out = try(source('pipeline/pipeline_subroutine.R', local = TRUE))

if('try-error' %in% class(out)){

    #system2('/home/mike/miniconda3/envs/python2/bin/python',
    system2('/home/aaron/miniconda3/envs/sp/bin/python',
        args=c('pipeline/notify_user_err.py', args))

} else {
    message('pipeline.R success')
}
