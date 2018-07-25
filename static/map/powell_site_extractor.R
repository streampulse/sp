x = read.csv('~/git/streampulse/jim_projects/example_data/powell_vars.csv')
x = x[rownames(unique(x[,c('lat','lon')])), 1:3]
#there are a couple NAs at the bottom that i removed manually
write.csv(x, '~/git/streampulse/server_copy/sp/static/map/powell_sites.csv',
    row.names=FALSE)
