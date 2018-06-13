library(devtools)
devtools::install_github("NEONScience/NEON-geolocation/geoNEON")
devtools::install_github("NEONScience/NEON-utilities/neonUtilities")

library(httr)
library(jsonlite)
library(dplyr)
library(downloader)

req = GET("http://data.neonscience.org/api/v0/products/DP1.10003.001")
# x = content(req, as="parsed")
txt = content(req, as="text")
avail = fromJSON(txt, simplifyDataFrame=T, flatten=T)

#keywords
avail$data$keywords
#references for documentation
avail$data$specs
#availability for each site and month
avail$data$siteCodes
#just months
avail$data$siteCodes$availableMonths
#urls for api calls
urls = unlist(avail$data$siteCodes$availableDataUrls)

#get a dataset
brd = GET(urls[grep("WOOD/2015-07", urls)])
brdf = fromJSON(content(brd, as="text"))

# view just the available data files
brdf$data$files

#filename format for manually collected (observational) data
#(sometimes domain and site are omitted):
#**NEON.[domain number].[site code].[data product ID].[file-specific name].
#[date of file creation] **

#filename format for sensor data
#NEON.[domain number].[site code].[data product ID].00000.
#[soil plot number].[depth].[averaging interval].[data table name].
#[year]-[month].[data package].[date of file creation]

#isolate files by name components and read them into a table
brd.count = read.delim(brdf$data$files$url
    [intersect(grep("countdata", brdf$data$files$name),
        grep("basic", brdf$data$files$name))], sep=",")

brd.point = read.delim(brdf$data$files$url
    [intersect(grep("perpoint", brdf$data$files$name),
        grep("basic", brdf$data$files$name))], sep=",")

#plot demo
clusterBySp <- brd.count %>%
    group_by(scientificName) %>%
    summarize(total=sum(clusterSize))

# Reorder so list is ordered most to least abundance
clusterBySp <- clusterBySp[order(clusterBySp$total, decreasing=T),]

# Plot
barplot(clusterBySp$total, names.arg=clusterBySp$scientificName,
    ylab="Total", cex.names=0.5, las=2)

#read the readme
readme = url(d$data$files$url[grep('readme', d$data$files$url)[1]])
r = readLines(readme)
r[1:10] #read a few lines at a time for managability

#for reals ####

#nitrate data

req = GET("http://data.neonscience.org/api/v0/products/DP1.20033.001")
txt = content(req, as="text")
avail = fromJSON(txt, simplifyDataFrame=TRUE, flatten=TRUE)

#availability for each site and month
avail$data$siteCodes
#just months
avail$data$siteCodes$availableMonths
#urls for api calls
urls = unlist(avail$data$siteCodes$availableDataUrls)

sort(unique(substr(urls, 58, 61)))

#get a collection of data files from one site and month
d = GET(urls[1]) #the first one only has a single observation
d = GET(urls[2]) #the first one only has a single observation
d = fromJSON(content(d, as="text"))

# view just the available data file names
d$data$files$name

data = read.delim(d$data$files$url
    [intersect(grep("basic", d$data$files$name),
        grep("15_minute", d$data$files$name))], sep=",")
# data2 = read.delim(d$data$files$url
#     [intersect(grep("expanded", d$data$files$name),
#         grep("15_minute", d$data$files$name))], sep=",")

# sum(is.na(data$surfWaterNitrateMean))/nrow(data)
head(data, 2)
nitr = data[!is.na(data$surfWaterNitrateMean),]
dim(nitr)
nitr
