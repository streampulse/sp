library(tidyverse)
library(imputeTS)
library(anomalize)
#library(feather)
library(lubridate)

print('pipeline.R')

setwd('/home/aaron/sp')
#setwd('/home/mike/git/streampulse/server_copy/sp')

#retrieve arguments passed from app.py
args = commandArgs(trailingOnly=TRUE)
names(args) = c('notificationEmail', 'tmpcode', 'region', 'site',
                'report_filenames', 'tmpfile', 'files_to_remove')
# args = list('tmpcode'='53fca4976eb0')

out = try(source('pipeline/pipeline_subroutine.R', local = TRUE))

if('try-error' %in% class(out)){

    try({
        unlink(args['tmpfile'])
        files_to_remove = strsplit(args['files_to_remove'], ', ')[[1]]
        for(f in files_to_remove){
            ferr = gsub('spuploads', 'sperr', f)
            file.copy(f, ferr, overwrite = TRUE)
            unlink(f)
        }
    }, silent = TRUE)

    #system2('/home/mike/miniconda3/envs/python2/bin/python',
    system2('/home/aaron/miniconda3/envs/sp/bin/python',
        args=c('pipeline/notify_user_err.py', args))

} else {
    message('pipeline.R success')
}
