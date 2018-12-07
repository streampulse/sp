#load excel worksheets into dataframes and export as csv
setwd('/home/mike/git/streampulse/server_copy/sp/scheduled_scripts/cuahsi')

wb = loadWorkbook('NC_Advanced.xlsx')
shtnames = names(wb)[-(1:2)]
shtnames = shtnames[-which(shtnames == 'DataValues')]
dir.create(date)
for(s in shtnames){
    dat = read.xlsx('NC_Advanced.xlsx', s)
    dat = dat[-(1:4),-1]
    write.csv(dat, paste0(date, '/', s, '.csv'))
}
