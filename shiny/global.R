library(stringr)

fnames = dir('data')
modnames = dir('data', pattern='modOut')
sitenmyr = str_match(modnames, 'modOut_(\\w+_\\w+)_([0-9]+)-.*')[,2:3]
sitenames = sitenmyr[,1]
siteyears = sitenmyr[,2]
# time2_toggleA = TRUE
# slider_toggleA = FALSE
# time2_toggleB = TRUE
# slider_toggleB = FALSE
