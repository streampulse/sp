Wql_040850_Probe1

library(httr)
library(jsonlite)
# library(dplyr)
# library(downloader)
library(RMariaDB)
library(DBI)
library(stringr)
library(accelerometry)

https://environmental.srpnet.com/TreatmentPlantViewer/api/WaterQuality/
GetDailyAverageTemperatureByTreatmentPlant?apikey={your api key}
&TreatmentPlantName=Phoenix%2024th%20St.&fromDate=5-28-2016&toDate=6-1-2016

req = GET(paste0("https://environmental.srpnet.com/TreatmentPlantViewer/",
    "api/CanalMix/GetLatestPumpInfo?apikey=9a3fe1eb-a533-4f96-9f57-9021ee50bcdf"))
txt = content(req, as="text")
data = fromJSON(txt)

req = GET(paste0("https://environmental.srpnet.com/TreatmentPlantViewer/api",
    "/CanalMix/GetEasternCanalMixDataByDate?apikey=9a3fe1eb-a533-4f96-9f57-",
    "9021ee50bcdf&date=5-28-2016"))
txt = content(req, as="text")
data = fromJSON(txt)

req = GET(paste0("https://environmental.srpnet.com/TreatmentPlantViewer/api/",
    "WaterQuality/GetConcentrationsByAdwr?apikey=9a3fe1eb-a533-4f96-9f57-",
    "9021ee50bcdf&adwrNumber=55222004&fromDate=5-28-2016"))
txt = content(req, as="text")
data = fromJSON(txt)
