# Mike's Logbook

### 20171113
 + organized notes, meeting recordings, questions, and todo list
 + added Gordon's photo to the site
 + made Bob's document of considerations and instructions more prominent (now linked from the "participate" page, which is also linked from the home page body)  
 + separated download step from format/run step in the model code

### 20171114
 + learned how to do a data portal password reset
 + explored the database, learned how to set user permissions
 + discovered a few bugs in the gapfiller code (added bug list to mike_todo slack channel)
 + changed server password

### 20171115
 + changed server password properly (updating config file and restarting nginx server)
 + modified usgs api query on ~410 in app.py so that it asks for data in UTC, which then matches the time of our datasets and doesnt result in NAs for discharge and level for the first 15 rows of dd (post-spreading); formerly there would also be 20 rows that only contained discharge and level at the end of each dataset. 
   + in so doing, fixed download issue
 + asked everyone to move over to the new slack
 + learned how to restart our web server after making changes and restart our digitalocean server to install updates

### 20171116
 + fixed mle mode (still gotta test it, as well as both bayes modes)
 + first meeting with Alison; she'd like me to focus on model priors and make sure they're reasonable and optimal, especially K
 + customized server bashrc and vimrc last night
 + tested manual upload
 + walked through normal upload for leveraged site so i can help people with that
 + linked github gist to model code on data portal

### 20171117
 + deleted old slack workspace
 + working on variable time intervals
   +   allowed user to specify sample interval (data are then coerced to that interval, but first some checks)
   +   made check for consistent time interval of input
   +   if check fails, picks the most prevalent interval
   +   then checks to see if desired interval is a multiple of that
   +   both of these just give warnings. the model will still work but NAs will be introduced (and later filled) if intervals are coerced
   +   got it all working, but it looks like fill_gaps has been non-functional. k-nearest neighbors code broken.
 + rewriting interpolation functions so we can use the versatility of imputeTS. also simplifying it a lot with rle(diff())

### sat20171118
 + rewrote in-line interpolation bit so that
   +   it works consistently (the other one was not filling in gaps that it should have)
   +   the code should now be quite a bit more decipherable
   +   we can now leverage all the power of na.seasplit()
   +   also faster now that we're using sapply(), which is parallelized

### mon20171120
 + exploring geoknife package made by Jordan (for querying usgs Geo Data Portal)
 + these variables available from UI daily meteorological data for continental us:
[1] "precipitation_amount"                     
[2] "max_relative_humidity"                    
[3] "min_relative_humidity"                    
[4] "specific_humidity"                        
[5] "surface_downwelling_shortwave_flux_in_air"
[6] "min_air_temperature"                      
[7] "max_air_temperature"                      
[8] "wind_speed"
 + but that database yields errors when i try to pull 2016-17
   +   theres a line in metdata_job that includes "REQUIRE_FULL_COVERAGE"
 + database #77 doesnt have the right temporal extent. otherwise might be able to use partial pressure of water vapor to calculate air pressure.
 + see what happened to PRISM. it might have what we need, and should still be externally accessible (just not in the geoknife list)
   +   has vapor pressure defecit. can air presure be calculated from that?
 + also might be able to troubleshoot errors in the UI dataset if i use the api directly.

### tue20171121
 + now acquiring wind speed and air pressure data from noaa
   +   using geoknife package instead of Cathy's code at the moment just because it has test coverage and regular maintenance. it's actually slower though if we continue to use the current database. could be much faster if we can find a better organized one.
 + acknowledge source and send them copy of any publications so they stay free in future: https://www.esrl.noaa.gov/psd/data/gridded/data.ncep.reanalysis.surface.html
 + fixed k nearest neighbors determination (now using sum of squared differences between NA days and full days after standardizing variables)

### wed20171122
 + meeting with Grimm lab. updated their user credentials. added some new sites

### fri20171124
 + standardized flags (Interesting, Questionable, Bad Data)
 + got rid of tagging stuff (flags get the job done by themselves now)
 + updated old flag comments
 + started learning html for d3

### mon20171127
 + end-of-semester goals for next semester:
   + make a call for data from all pis; start running models
   + operationalize gap filling (consider correlations between variables when using some to inform others)
   + automate outlier detection
   + check off 40 to-do list items
 + discovered issue with data upload (AZ_WB_2017-11-08_EM.csv was rejected because it had been manually edited, but the EM suffix specifies that it's coming directly from a logger. instead of failing with an error, it still uploaded the csv to the server and then the user (Sophia) couldnt upload it again, but none of the data actually reached the database.)

### thu20171130
 + still waiting to hear back about flag ids and csv storage
 + got brushing over night regions and points working on qaqc
 + done with most of web visualiation tutorial (html, css, js, svg, d3)

### sun20171203
 + fixed error handling for upload process. now any error will yield a generic message with a link to my email.

### mon20171204
 + set up test site using new server block (virtual host) on streampulse droplet.
 + configured ufw to allow ssh and nginx (both http and https) traffic (and port 5000). still allowing http for now just because the other sites running from this droplet mightneed it

### tue20171205
 + set up https for data.streampulse.org with redirect so that http no longer works
 + we now get an A on ssllabs.com
 + could get A+ by following instructions about port 443 in /etc/nginx/sites-available/default
 + should definitely look into the gzip thing mentioned there

### fri20171208
 + ive breached the walls of passing variables around with flask. now using the session to permit full real-time debugging of the web app.
 + fixed the issue with obsolete variable names remaining behind after replacement files are uploaded. ended up being a huge deal. wrote several dozen lines in a new function called remove_misnamed_cols. it's hooked up but not yet fully tested. also gonna make the user verify before any vars are deleted
 + got the drift chat bubble hooked up to my own account now. added chat bubbles to the upload and upload_columns html templates

### mon20171211
 + abandoned remove_misnamed_cols()
 + attempted to solve derelict variable probem by cross-referencing upload variables with old variables and deleting obsolete variables by date. turns out there are tons of unexpected "obsolete" variables that may be worth keeping. A true fix will require labeling each observation in the database with an ID corresponding to its upload file, which will involve a major overhaul
 + need advanced user permissions for sciencebase

### tue20171226
 + added error handler for when illegal symbols show up in an upoaded cv
 + rpy2==2.8.6 is last version to support python 2.7

### thur20171228
 + PR_RI_2015-12-15_CS.dat gave error 001 when reuploading. may have been because there were flags in the dataset (which i added during testing)
   + this is not a result of flagging
 + fixed flags in downoaded csvs so that their actual values and comments are returned rather than just ids
 + flag data is retained through reupload!

### mon20180108
 + file upload format now enforced (maybe not perfectly)
 + only one logger type can be uploaded at a time now. this could be reinstated later. the merge operation screws up the upoad ID assignment
_XX filetypes must now be merged prior to upload
   +   undid this change, but format is still strictly enforced. XX is required for core sites

### tue20180109
 + done with revamp. some issues may still arise, as not everything has been thoroughly tested. along with this improvement, i've done away with calls to df.to_sql in updatedb, so now changes are not persisted until the whole upload sequence completes successfuy.
 + clarified file naming instructions on upload.html

### mon20180122
 + wi_bec_2015-12-11_xx.csv seems too large to upload. still, it ended up in the database. asking Sam Blackburn to break it 60/40 and try to reupload. let's see if again the resultant data are fewer after reupload. upload size limit seems to be lower on chrome.there are 170219 records in the aforementioned file. removing them manually from database now

### tue20180123
sam was using safari and was able to upload both files (~2MB and ~4MB) after split

nearest neighbors gap fill stuff is super messed up. probaby should do a full rewrite since the data going into those functions wasn't even sensible. 
i commented a bock in fill_missing that disables the neighbors stuff
some specifics in case i continue to use the existing code downstream of that block:
linear_fill is no more, yet it's still called
ive put comments and garbage everywhere. search for print, message, and <<- to find it all. 

### thur20180125
fixed up app.py so that leveraged sites can be uploaded. realize now that the only core regions are NC, AZ, WI, and FL. deleted my requests to MD, CT, VT, RI that they update all their files to _XX extension and uploaded those files myself.
there should no longer be a size limit (effectively) for uploads. to_dict() was the culprit, and it now uses chunking

Miguel Leon wants to set up a direct database link between OSM2 Admin and StreamPULSE

### fri20180126
got rid of manua upload. it was only necessary because data were being lost. upload_id should solve that problem
verified that the to_dict() chunker is working properly
replaced qaqc demo with link to model considerations
still waiting on FL probem file updates (who is their data person?)

### mon20180129
restored flag data
still waiting on florida for probem files
updated two flag vaues so that they fit into the new standard of interesting/questionable/bad
MAKE SURE TO TELL PEOPLE FLAG TYPE DEFAULTS TO "QUESTIONABLE"

### wed20180131
updated site permissions for all users except a few unknowns
api requests now return flag information
r wrappers now hande flag information
    request_data retrieves it if desired
    prep_metab replaces vals with NA for specified flag types
    error handling in place

### thur20180201
fixed phil's processing_func so that it works when model_type='bayes'
wrote diagnostic for evaluating cor between daily K and ER
air pressure automatically retrieved if necessary

### mon20180205
 + finished first round of model runs, not including WI

### tue20180206
 + finished WI and added to zip file
 + fixed 3 errors in pipeline discovered during model round 1.
   + much more intelligent handling of inconsistent time intervals
   + may want to handle interval stuff without user input
   + possible interpolation error introduced. test tomorrow
   + air pressure retrieval error introduced.
 + enhanced many and formatted all errors and warnings. removed calls from these messages

### wed20180207
 + new errors fixed
 + adding new core sites requires manual editing of files and database. should let users do this themselves

###thu20180208
 + made more robust tests for valid LOGGERIDs
 + deleted all FL data so Lily can reupload with new files
 + fixed bash run commands file for user hbef
   + that user's default shell was at some point changed to /bin/sh

###tue20180213
 + modifying pipeline so that rating curves can be used to estimate discharge from level/depth/stage when available, and so that these can be estimated from air and water pressure (and sometimes ensor height) where necessary.
   + the user can supply a small sample of Z and Q data to build a rating curve, or can supply a and b of Q=aZ^b if they want to override that.
 + building all the checks and system messages to guide the user through this now.
 + noticed that level is ignored by the pipeline at the moment, although it's a synonym for depth. depth and discharge are both passed into streamMetabolizer.
 + changing it so that calc_depth(), which uses a stock rating curve to estimate depth from discharge, is only used as a last resort when both depth and level are missing [undid when i found out Depth_m usually refers to level-at-gage]
 + if the user specifies rating curve arguments, any discharge data available from StreamPULSE or USGS will be ignored and the user will be warned.
 + removed AZ_LV_2017-07-11_EM.csv from database (left name in upload table). these file had been marked with "do not send these data to aaron"
 + fixed issue with outlier detector when there are no outliers identified

wed20180214
 + turns out there's little consensus on what "stage", "level", and "depth" mean. seems likely that different sitegroups will be using these terms interchangeably, but they may refer either to depth at a point in the stream, average depth across the stream, or the vertical distance between sensor and surface. gotta add more checks and warnings for this.
 + turns out pretty much any measure of depth or level, averaged or not, can be used to fit a rating curve with discharge. what streamMetabolizer expects though is average depth for an area defined by the width of the stream and the O2 turnover distance. This can be estimated from discharge.
 + finished incorporating rating curves. can now estimate discharge using prefit curve parameters or just fit one on the fly using Z and Q data. still need to test.
 + now estimating mean areal depth by default, rather than assuming Depth_m from StreamPULSE database is adequate. But the user can override and pass this value directly into the model. Looks like it will usually be something like depth-at-gage or, worse, level-at-gage, rather than areal depth as described above.

thu20180215
 + added options for fitting ZQ curve as power, exponential, linear
 + if interpolation by seasonal decomposition fails (e.g. because of too many NAs for a variable), automatically attemps linear interp
 + new option to plot rating curve fit and discharge estimates
 + new option to use depth_m from StreaamPULSE (which may represent many things), or estimate mean areal depth via discharge
 + option to correct for sensor height above bed or not
 + added more warnings, messages, errors, and tests

mon20180219
 + new Sweden data could not be viewed in cleaning tool. traced this back to an error in sunrise/sunset calculations that resulted in an invalid arccosine domain. probably relates to the fact that sun never sets on a few days each year at 68 latitude.

tue20180220
 + fixed sunrise/sunset error.
 + tested pipeline after major changes of last week. fixed a few bugs; added a few messages and comments
 + started running models for Sweden and NC (the ones that require rating curves)
 + started making StreamPULSE R package
 + changed Analytics tab to Sitelist tab on data portal. Now sorting sites by region and sitecode
 + in request_data(), the variabes argument was not hooked up to anything. built this up so that user can select which variables to request from streampulse. if omitted, all vars necessary for metab modeling will be requested. also notifies the user of which requests were successful and which weren't.

wed20180221
 + finished documentation for request_data
 + working on documentation for prep_metabolism
 + finished sweden model runs

thu20180222
 + turns out sweden discharge data were in the wrong units. redoing models
 + pitched raw -> corrected -> derived data management solution. still needs work
 + organizing meetings to discuss model output before all-hands presentation
 + sent out temp version of current pipeline code for students that need it now. package should be done by monday.

fri20180223
 + "Show local night time" disabled by default on website plots. Small speed improvement.
 + switched from geoknife to Cathy's code for air pressure acquisition
 + cleaned up and added date axes to MetaboPlots
 + replotted all round 1 model output (omitting all but one calendar year for each)

sat20180224
 + finished StreamPULSE R package
 + finished NC model runs

mon20180226
 + shipped individual model run results to all PIs
 + worked out R package kinks and published

tue20180227
 + wrote script for running all models in a loop
 + finished SE model runs
 + NCDC database fails when asked for FL airpressure data. NCEP succeeds, so geoknife method for airpressure retrieval is back in place, just secondary

wed20180228
 + working on late-stage scheme for incorporating data levels

thu20180301
 + added error handlers in request_data() for USGS maintenance and generic request failures.
 + sent out PR results

### fri-thur (lost these logs)
 + reran PR models and sent out
 + presented plans for data level management at all-hands
 + added year to initial tickmark on cleaning tool
 + prepared git lecture for Phil, hopefully others

### fri20180309
 + configured automatic archiving of server logs
 + loading icon now appears whenever an ajax request is made
 + can now jump to any 4 week period in cleaning tool
 + cleaned up qaqc code
