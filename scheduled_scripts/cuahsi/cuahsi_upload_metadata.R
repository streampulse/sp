#load excel worksheets into dataframes and export as csv
setwd('/home/mike/git/streampulse/server_copy/sp/scheduled_scripts/cuahsi')
date = as.character(Sys.Date())

wb = loadWorkbook('NC_Advanced.xlsx')
shtnames = names(wb)[-(1:2)]
# shtnames = shtnames[-which(shtnames == 'DataValues')]
shtnames = shtnames[! shtnames %in% c('Introduction','Description of Tables',
    'Samples','LabMethods',
    'QualityControlLevels','DataValues','Categories','DerivedFrom',
    'GroupDescriptions', 'Groups','OffsetTypes')]

dir.create(date)
for(s in shtnames){
    dat = read.xlsx('NC_Advanced.xlsx', s)
    dat = dat[-(1:4),-1]
    dat[is.na(dat)] = ''
    write.csv(dat, paste0(date, '/', s, '.csv'), row.names=FALSE)
}
