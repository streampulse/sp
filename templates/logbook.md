#Mike's Logbook

###mon20181008
Input viz improvements:
 + changed interquartile plot interface to buttons, rather than dropdown
 + re-styled plots, colors
 + added tooltip explanations for interquartile plotting buttons
 + added tooltups for each flagged point
 + Bad Data points are no longer plotted
 + changed aggregation bins to 1 day for interquartile plots because 1 hour bins resulted in too-thin overlay polygons. Anything between 1h and 1d would require lots of additional fiddling.
###fri20181005
 + variables not loaded initially can still be retrieved for overlays
 + finished interquartile range frontend with dropdown interface
###thu20181004
 + backend of interquartile range plotter complete
###wed20181003
 + input plot viz shows only most recent year by default
 + full available time range is now displayed beside the date picker
###mon20181001
Input viz improvements:
 + sorted variable checkboxes at top by importance, then alphabetically
 + only variables critical to metab modeling are now checked by default
 + fixed overlay plots so that all variables can be overlain, not just the ones that were selected at the top
###fri20180928
 + completed local version of shiny viz app
 + resolved namespace pollution issue in streampulse R package
###thu20180927
 + added link back to data portal from diagnostic apps
 + built timeout feature into fit_metabolism for http requests
###wed20180926
 + fixed loading screen problem on site that would often result from following an externa link and then returning with the back button
 + added error handers for username/email already in use
 + added data policy links, updated model page text
 + fixed bug in download: if no grab data, notification appears after leaving page
###tue20180925
 + workshop wrapup, help new users
###20180912-21
 + Switzerland workshop
###tue20180911
 + added text to cumulative plot in diagnostic app to show final accumulation
###mon20180910
 + fixed bug in NEON data retrieval that caused duplication of site information
 + fixed bug in timediff calculation in shiny app (difference in behavior between R versions)
###away 20180901-09
###thu20180830
 + talked with Chris Collins at Duke OIT about cloud computing possibilities
 + built discharge portion of NEON ingestion script 
 + duplicated nitrate data for upstream stations, since it's only measured at downstream stations
###wed20180829
 + NEON DO exploration, workshop prep
###tue20180828
 + worked on toy coupled O2-CO2 model for SE workshop
###mon20180827
 + wrote draft proposal to South BD-HUB for Azure credits
###fri20180824
 + made viz and qaqc landing pages more efficient. determined that delays in loading plots are not due to database inefficiency
###thu20180823
 + made download, sitelist, and home pages efficient
 + made info in sitelist table more useful
###wed20180822
 + made report of NEON O2 data availability and coverage
 + made sql reads for upload page a zillion times more efficient. upload page now runs like a dream
###tue20180821
 + created pull request for reaRate, filed issue on github for other errors that need to be addressed before we can use k600 data
###mon20180820
 + researched NEON depth and discharge acquisition possibilities
 + attempted to use NEON's reaRate package to estimate k600 for all available sites. encountered uncaught exceptions in core functions
###vacation 20180810-19
 + hooked up NEON script for synching water quality and nitrate between databases
###20180807-09
 + set up NEON data ingest for water quality and nitrate
###mon20180806
 + set up lter account on streampulse server for hbef data sync
###sun20180805
 + made qaqc demo video
###sat20180804
 + added flag information popups when hovering over flagged data
###thu20180802
 + fixed highlighting of flagged points when "apply to all variables" is selected
 + added warnings to qaqc app
 + fixed alert placement, popup box layout, select placeholder on qaqc app
 + fixed point coloring on brush
 + new button for removing existing flags (works with apply to all)
 + fixed bug with apply to all and flag outliers combo
 + selected point color changes now apply to all point types
 + toggle apply to all and selection colors toggle for all plots
###thu20180726
 + updated diag plots to accommodate gappy data, now that package doesn't interpolate everything by default
###wed20180725
 + added powell sites, adjusted zoom, embedded site map in data portal sitelist page and weebly sites page
###tue20180724
 + added markers, popup messages, color, legend to site map
###thu20180719
 + made new site map with Leaflet. added sites and base layer
###wed20180718
 + fixed encoding error (ASCII instead of utf-8) in download tool
###20180713-18
 + synthesis of streampulse metabolism and watershed data
###thu20180712
 + updated package (v 0.0.0.9008) so input data arent automatically interpolated
 + extended interpolation options to the user
 + finished user auth for diagnostic app.
###wed20180711
 + rerunning all models without interpolating gaps > 3 hours
 + building user auth infrastructure for diagnostic app
###tue20180710
 + synthesizing watershed data and model results for all streampulse sites for Jim's paper
###fri20180706
 + learned basics of Leaflet for interactive mapmaking. Seems to be the only way we can avoid the continent-duplication-at-full-zoomout issue, which seems to be common to every user-friendly mapmaking platform in existence (nearly all of which appear to be based on the google engine)
###thu20180705
 + updated API code so that incoming models and model details automatically push previous best models and details to relegated status. details remain in table but are no longer used. model objects get moved to a holding folder and are removed on a 1 month schedule.
 + made fit_model function more customizable in R package
   + pool_K600, err_obs_iid, err_proc_iid, proc_acor_iid, ode_method, deficit_src now adjustable by the user
###wed20180704
 + developed scheme for comparing models, taking into account overall penalty and temporal coverage using piecewise function.
###tue20180703
 + developed schemes for penalizing maximum daily K600 and K600-ER correlation using cubic and linear functions, respectively
###mon20180702
 + added registration link to homepage
   + redid layout for link buttons on homepage
 + logged Q in diag plots
 + site data now included with downloads
###thu20180628
 + built API protocols for uploading model fits and predictions to server
   + built supporting R code
 + built API protocols for uploading model details to database
   + built supporting R code
 + added SQLAlchemy ORM for model table
 + simplified model output RDS filenames and Shiny code that calls them
###wed20180627
 + updated database and R pipeline so that all model specifications can be tracked and the details of how each "best" model was run will not be lost
###mon20180625
 + fixed issue with HOBO parser. unrecognized column
###thu20180621
 + added StreamPULSE API functionality so that model spec data can be requested
###wed20180620
 + fixed problem in download page on data portal where changes to the date range were not being registered
 + added model specs table to the database, so we can track the best model for each site and year
###tue20180619
 + arranging for AZ's East Canal site to be automatically synced with our database
   + API call script is ready for when they update the API in a few weeks
###mon20180618
 + finished NEON data ingester for nitrate data product
   + water quality data product (with DO) not yet available, but nitrate script will be easily adaptable once it is
###fri20180615
 + building NEON data ingester
###thu20180614
 + fixed reactivity chain in shiny app. no unnecessary plotting/herky-jerky transitions
 + no graying of the screen while plots are recalculating
###wed20180613
 + 3 possible plans for handling the updating of "official" model outputs for each site and year
   + manual comparison of model runs by users, visual evaluation (requires building a hierarchy of user credentials, so that only qualified users can update existing models)
   + automatic comparison based on composite model quality score (O2 obs vs. pred GOF test or IC score, CI on GPP and ER, proportion of GPP and ER estimates that go the wrong direction, ER=K600 correlation, data coverage)
   + could maintain top 3-5 best models at all times and combine both approaches
 + time slider conforms to available date range
###tue20180612
 + fixed issue with occasional "wedges" appearing in O2 diagnostic plots
 + system now ready to receive NC Cole Mill logger files
###mon20180611
 + added units to grab sample overlay dropdown on input viz page
 + widened right plot margins so that large labels don't get cut off
 + diagnostic plots with site and year selector dropdowns now at data.streampulse.org:3838/streampulse_diagnostic_plots
###sat20180609
 + tested and revised R package update
 + rerunning NC models now
###fri20180608
 + added warnings about matching units to grab sample uploader
 + updated R package so that out-of-bounds depth or level values (i.e. beyond the rating curve maximum) can be replaced with NA if desired
###thu20180607
 + fine-tuning diagnostic app backend connections and appearance
###wed20180606
 + still rerunning models. added completed outputs to diagnostic app and built user inputs for selecting sites, years to view
###tue20180605
 + set up slack digest, will soon go out to streampulse team every friday
###mon20180604
 + added protocols for upload, clean, model to streampulse.org (works in progress)
###sat20180602
 + rerunning models for all sites, for all years, separated into calendar year chunks. done in preparation for new visualization app.
###fri20180601
 + got season start and end from eMODIS NDVI data for all Powell Center sites in 2016
###thu20180531
 + user credentials now automatically updated with new sites as they are uploaded, so that users can immediately download, clean, and visualize their data.
 + hbef app connected to database on server
###wed20180530
 + hbef app migrated to server
###20180522-29
 + vacation
###mon20180521
 + rather than embedding the app in a data portal template page, looking into solutions that would let it remain a standalone app, while still fitting the styles and themes of the data portal
###fri20180518
 + can't embed shiny app (unencrypted unless we get absurdly expensive pro version) in site, which is encrypted. attempting workarounds involving web server config
###thu20180517
 + app improvements, site config
###wed20180516
 + page 1 arranged; app embedded in data portal locally
###tue20180515
 + app page 2 plots now arranged and enhanced
###mon20180514
 + got page 2 time sider connected, enabled brushing and point highlighting on O2 plot
###fri20180511
 + built shell of Shiny app and got plots inside, static currently
###thu20180510
 + buiding new viz app for model diagnostics and iterative fitting
###wed20180509
 + finished SFS poster
###tue20180508
 + worked on StreamPULSE SFS poster
###mon20180507
 + made new diagnostic plots: K v Q, K v ER, obs O2 v modeled O2
###20180428-0505
 + Durham visit
###fri20180427
 + added secondary axes for overlaid variables
 + series and grab overlay dropdowns communicate with each other
 + made outline of SFS poster
 + downloaded grab data now include methods details
###thu20180426
 + grab data can now be overlaid on sensor data
###tue20180424
 + built functions for responsively requesting grab data when grabvar overlay dropdown changes
###mon20180423
 + finished and tested grab upload interface
 + hooked interface up to database and added columns for methods, write-in methods, and additional methods details (so far just filter pore size)
 + grab variable dropdown on viz page refreshes when site and daterange change
###fri20180420
 + added comment boxes for user-specified methods
 + added dropdowns for filters
 + grabsamp interface front and back ends are hooked up
###thu20180419
 + visibility toggle done
 + fixed old bug in API that produced error when there was no USGS discharge or level data for a requested date range
###wed20180418
 + done with method auto-population for previous selections
 + done with responsive method auto-selection as users make choices
 + halfway done with dropdown visibility toggle
###tue20180417
 + building new interface for grab upload. got units incorporated; working on methods dropdowns.
###mon20180416
 + created site, variable, and metadata report for all locations
 + investigating HBEF site issues in preparation for new wave of development 
###thu20180412
 + completed powell review
###wed20180411
 + powell review
###tue20180410
 + powell review
###mon20180409
 + powell review
###fri20180406
 + clarified CSV datetime formatting
 + powell review
###thu20180405
 + added tooltip to reinforce the necessity of putting the datetime column in the first position for manually formatted files
 + running model for AZ. streamMetabolizer works on as few as 4 days of data, but only returned one point estimate of GPP and ER in this case.
###wed20180404
 + testing database improvements (additional indices, column type changes, foreign keys, etc.)
 + explored ODM2. It's looking like the benefits of adopting the core schema of ODM2 will not be so great as to warrant the weeks (and potentially months) of effort necessary to implement a new database backend, modify all I/O, build a translation layer, etc. It's difficult to foresee all obstacles we might face by sticking with the current, flat schema, but after some research I feel more confident in my ability to adapt what we've got as needed. 
 + fixed error that results from attempts to upload an _XX file with two datetime columns
###tue20180403
 + drafted 6 month work plan
 + researched database speed and organizational improvements
###mon20180402
 + raw data files are now archived on sciencebase. when a folder fills (100 files per folder, max), a new one is automatically created, for both metadata and data
 + looking into possibility of direct connection to CUAHSI-HIS. retracing steps toward CUAHSI connection taken in 2016
###fri20180330
 + clarified sensor upload language to match new grab upload language, added instructions for data revision
###thur20180329
 + fixed issue with R package data download
 + sent variable level accounting templates to WI group
 + Powell review
 + adding tons of instructions on how to do data revision via upload. suddenly aware of how unintuitive it is
###wed20180328
 + fixed issue with Manta data file parser
 + reforged bond with CUAHSI HIS
 + Powell review
###tue20180327
 + Powell Center Synthesis data and metadata review
###mon20180326
 + assembled list of grab variables, units, methods, associated series variables; sent to group for supplementation
###thu20180322
 + rewrote instructions for grab upload
 + finished grab download
### wed20180321
 + finished grab upload
 + clarified cleaning tool terminology
### tue20180320
 + met with Miguel Leon to discuss possibility of adopting ODM2 (Corinna Gries' suggestion)
 + many small improvements to variable matching and the following machinery
 + fixed SOP link on streampulse.org/products
### mon20180319
 + met with Emily Stanley about data levels, revision tracking
 + working through database updating and backend after variable matching
### sun20180318
 + restructured variable name matching page for grab uploads
   + can now add multiple new sites at once
   + not saving intermediate temp files, so no possibility of derelict csvs accumulating
   + clarified language
### sat20180317
 + we now have separate pages for series upload and grab sample upload. restructured the latter
### fri20180316
 + met with AZ team about data levels, revision tracking
 + meeting and git tutorial for Phil
 + made form for data leads to fill out, to account for existing variable levels
### thu20180315
 + modeled PR_prieta data for three years
 + met with Corinna Gries to discuss database structuring for data level project
 + started conversation with Bob, Alison, PR team about negative GPP, positive PR
### wed20180314
 + ran Maria's SE sites. working out several issues with file formatting, variable units, datetime conversion
 + met with NH/PR team about data levels, revision tracking
### tue20180313
 + made new landing page for upload tools. "upload" is now "series upload." rewired everything accordingly
### mon20180312
 + met with Carolina about plotting series and spot sample data simultaneously
 + met with Carl from USGS to talk about database structuring in preparation for data level implementation
### sun20180311
 + selected date range in dropdown now updates as range changes

### fri20180309
 + configured automatic archiving of server logs (broke website, must revisit)
 + loading icon now appears whenever an ajax request is made
 + can now jump to any 4 week period in cleaning tool
 + cleaned up qaqc code
 + panback and panforward now only appear if applicable

### fri-thur (lost these logs)
 + reran PR models and sent out
 + presented plans for data level management at all-hands
 + added year to initial tickmark on cleaning tool
 + prepared git lecture for Phil, hopefully others

###thu20180301
 + added error handlers in request_data() for USGS maintenance and generic request failures.
 + sent out PR results

###wed20180228
 + working on late-stage scheme for incorporating data levels

###tue20180227
 + wrote script for running all models in a loop
 + finished SE model runs
 + NCDC database fails when asked for FL airpressure data. NCEP succeeds, so geoknife method for airpressure retrieval is back in place, just secondary

###mon20180226
 + shipped individual model run results to all PIs
 + worked out R package kinks and published

###sat20180224
 + finished StreamPULSE R package
 + finished NC model runs

###fri20180223
 + "Show local night time" disabled by default on website plots. Small speed improvement.
 + switched from geoknife to Cathy's code for air pressure acquisition
 + cleaned up and added date axes to MetaboPlots
 + replotted all round 1 model output (omitting all but one calendar year for each)

###thu20180222
 + turns out sweden discharge data were in the wrong units. redoing models
 + pitched raw -> corrected -> derived data management solution. still needs work
 + organizing meetings to discuss model output before all-hands presentation
 + sent out temp version of current pipeline code for students that need it now. package should be done by monday.

###wed20180221
 + finished documentation for request_data
 + working on documentation for prep_metabolism
 + finished sweden model runs

###tue20180220
 + fixed sunrise/sunset error.
 + tested pipeline after major changes of last week. fixed a few bugs; added a few messages and comments
 + started running models for Sweden and NC (the ones that require rating curves)
 + started making StreamPULSE R package
 + changed Analytics tab to Sitelist tab on data portal. Now sorting sites by region and sitecode
 + in request_data(), the variabes argument was not hooked up to anything. built this up so that user can select which variables to request from streampulse. if omitted, all vars necessary for metab modeling will be requested. also notifies the user of which requests were successful and which weren't.

###mon20180219
 + new Sweden data could not be viewed in cleaning tool. traced this back to an error in sunrise/sunset calculations that resulted in an invalid arccosine domain. probably relates to the fact that sun never sets on a few days each year at 68 latitude.

###thu20180215
 + added options for fitting ZQ curve as power, exponential, linear
 + if interpolation by seasonal decomposition fails (e.g. because of too many NAs for a variable), automatically attemps linear interp
 + new option to plot rating curve fit and discharge estimates
 + new option to use depth_m from StreaamPULSE (which may represent many things), or estimate mean areal depth via discharge
 + option to correct for sensor height above bed or not
 + added more warnings, messages, errors, and tests

###wed20180214
 + turns out there's little consensus on what "stage", "level", and "depth" mean. seems likely that different sitegroups will be using these terms interchangeably, but they may refer either to depth at a point in the stream, average depth across the stream, or the vertical distance between sensor and surface. gotta add more checks and warnings for this.
 + turns out pretty much any measure of depth or level, averaged or not, can be used to fit a rating curve with discharge. what streamMetabolizer expects though is average depth for an area defined by the width of the stream and the O2 turnover distance. This can be estimated from discharge.
 + finished incorporating rating curves. can now estimate discharge using prefit curve parameters or just fit one on the fly using Z and Q data. still need to test.
 + now estimating mean areal depth by default, rather than assuming Depth_m from StreamPULSE database is adequate. But the user can override and pass this value directly into the model. Looks like it will usually be something like depth-at-gage or, worse, level-at-gage, rather than areal depth as described above.

###tue20180213
 + modifying pipeline so that rating curves can be used to estimate discharge from level/depth/stage when available, and so that these can be estimated from air and water pressure (and sometimes ensor height) where necessary.
   + the user can supply a small sample of Z and Q data to build a rating curve, or can supply a and b of Q=aZ^b if they want to override that.
 + building all the checks and system messages to guide the user through this now.
 + noticed that level is ignored by the pipeline at the moment, although it's a synonym for depth. depth and discharge are both passed into streamMetabolizer.
 + changing it so that calc_depth(), which uses a stock rating curve to estimate depth from discharge, is only used as a last resort when both depth and level are missing [undid when i found out Depth_m usually refers to level-at-gage]
 + if the user specifies rating curve arguments, any discharge data available from StreamPULSE or USGS will be ignored and the user will be warned.
 + removed AZ_LV_2017-07-11_EM.csv from database (left name in upload table). these file had been marked with "do not send these data to aaron"
 + fixed issue with outlier detector when there are no outliers identified

###thu20180208
 + made more robust tests for valid LOGGERIDs
 + deleted all FL data so Lily can reupload with new files
 + fixed bash run commands file for user hbef
   + that user's default shell was at some point changed to /bin/sh

### wed20180207
 + new errors fixed
 + adding new core sites requires manual editing of files and database. should let users do this themselves

### tue20180206
 + finished WI and added to zip file
 + fixed 3 errors in pipeline discovered during model round 1.
   + much more intelligent handling of inconsistent time intervals
   + may want to handle interval stuff without user input
   + possible interpolation error introduced. test tomorrow
   + air pressure retrieval error introduced.
 + enhanced many and formatted all errors and warnings. removed calls from these messages

### mon20180205
 + finished first round of model runs, not including WI

### thur20180201
 + fixed phil's processing_func so that it works when model_type='bayes'
 + wrote diagnostic for evaluating cor between daily K and ER
 + air pressure automatically retrieved if necessary

### wed20180131
 + updated site permissions for all users except a few unknowns
 + api requests now return flag information
 + r wrappers now handle flag information
   + request_data retrieves it if desired
   + prep_metab replaces vals with NA for specified flag types
   + error handling in place

### mon20180129
 + restored flag data
 + still waiting on florida for probem files
 + updated two flag vaues so that they fit into the new standard of interesting/questionable/bad

### fri20180126
 + got rid of manua upload. it was only necessary because data were being lost. upload_id should solve that problem
 + verified that the to_dict() chunker is working properly
 + replaced qaqc demo with link to model considerations

### thur20180125
 + fixed up app.py so that leveraged sites can be uploaded. realize now that the only core regions are NC, AZ, WI, and FL. deleted my requests to MD, CT, VT, RI that they update all their files to _XX extension and uploaded those files myself.
 + there should no longer be a size limit (effectively) for uploads. to_dict() was the culprit, and it now uses chunking
 + Miguel Leon wants to set up a direct database link between OSM2 Admin and StreamPULSE

### tue20180123
 + sam was using safari and was able to upload both files (~2MB and ~4MB) after split
 + nearest neighbors gap fill stuff is super messed up. probaby should do a full rewrite since the data going into those functions wasn't even sensible.
 + commented a bock in fill_missing that disables the neighbors stuff
 + some specifics in case i continue to use the existing code downstream of that block:
   + linear_fill is no more, yet it's still called
   + ive put comments and garbage everywhere. search for print, message, and <<- to find it all.

### mon20180122
 + wi_bec_2015-12-11_xx.csv seems too large to upload. still, it ended up in the database. asking Sam Blackburn to break it 60/40 and try to reupload. let's see if again the resultant data are fewer after reupload. upload size limit seems to be lower on chrome.there are 170219 records in the aforementioned file. removing them manually from database now

### tue20180109
 + done with revamp. some issues may still arise, as not everything has been thoroughly tested. along with this improvement, i've done away with calls to df.to_sql in updatedb, so now changes are not persisted until the whole upload sequence completes successfuy.
 + clarified file naming instructions on upload.html

### mon20180108
 + file upload format now enforced (maybe not perfectly)
 + only one logger type can be uploaded at a time now. this could be reinstated later. the merge operation screws up the upoad ID assignment
_XX filetypes must now be merged prior to upload
   +   undid this change, but format is still strictly enforced. XX is required for core sites

### thur20171228
 + PR_RI_2015-12-15_CS.dat gave error 001 when reuploading. may have been because there were flags in the dataset (which i added during testing)
   + this is not a result of flagging
 + fixed flags in downoaded csvs so that their actual values and comments are returned rather than just ids
 + flag data is retained through reupload!

### tue20171226
 + added error handler for when illegal symbols show up in an upoaded cv
 + rpy2==2.8.6 is last version to support python 2.7

### mon20171211
 + abandoned remove_misnamed_cols()
 + attempted to solve derelict variable probem by cross-referencing upload variables with old variables and deleting obsolete variables by date. turns out there are tons of unexpected "obsolete" variables that may be worth keeping. A true fix will require labeling each observation in the database with an ID corresponding to its upload file, which will involve a major overhaul
 + need advanced user permissions for sciencebase

### fri20171208
 + ive breached the walls of passing variables around with flask. now using the session to permit full real-time debugging of the web app.
 + fixed the issue with obsolete variable names remaining behind after replacement files are uploaded. ended up being a huge deal. wrote several dozen lines in a new function called remove_misnamed_cols. it's hooked up but not yet fully tested. also gonna make the user verify before any vars are deleted
 + got the drift chat bubble hooked up to my own account now. added chat bubbles to the upload and upload_columns html templates

### tue20171205
 + set up https for data.streampulse.org with redirect so that http no longer works
 + we now get an A on ssllabs.com
 + could get A+ by following instructions about port 443 in /etc/nginx/sites-available/default
 + should definitely look into the gzip thing mentioned there

### mon20171204
 + set up test site using new server block (virtual host) on streampulse droplet.
 + configured ufw to allow ssh and nginx (both http and https) traffic (and port 5000). still allowing http for now just because the other sites running from this droplet mightneed it

### sun20171203
 + fixed error handling for upload process. now any error will yield a generic message with a link to my email.

### thu20171130
 + still waiting to hear back about flag ids and csv storage
 + got brushing over night regions and points working on qaqc
 + done with most of web visualiation tutorial (html, css, js, svg, d3)

### mon20171127
 + end-of-semester goals for next semester:
   + make a call for data from all pis; start running models
   + operationalize gap filling (consider correlations between variables when using some to inform others)
   + automate outlier detection
   + check off 40 to-do list items
 + discovered issue with data upload (AZ_WB_2017-11-08_EM.csv was rejected because it had been manually edited, but the EM suffix specifies that it's coming directly from a logger. instead of failing with an error, it still uploaded the csv to the server and then the user (Sophia) couldnt upload it again, but none of the data actually reached the database.)

### fri20171124
 + standardized flags (Interesting, Questionable, Bad Data)
 + got rid of tagging stuff (flags get the job done by themselves now)
 + updated old flag comments
 + started learning html for d3

### wed20171122
 + meeting with Grimm lab. updated their user credentials. added some new sites

### tue20171121
 + now acquiring wind speed and air pressure data from noaa
   +   using geoknife package instead of Cathy's code at the moment just because it has test coverage and regular maintenance. it's actually slower though if we continue to use the current database. could be much faster if we can find a better organized one.
 + acknowledge source and send them copy of any publications so they stay free in future: https://www.esrl.noaa.gov/psd/data/gridded/data.ncep.reanalysis.surface.html
 + fixed k nearest neighbors determination (now using sum of squared differences between NA days and full days after standardizing variables)

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

### sat20171118
 + rewrote in-line interpolation bit so that
   +   it works consistently (the other one was not filling in gaps that it should have)
   +   the code should now be quite a bit more decipherable
   +   we can now leverage all the power of na.seasplit()
   +   also faster now that we're using sapply(), which is parallelized

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

### 20171116
 + fixed mle mode (still gotta test it, as well as both bayes modes)
 + first meeting with Alison; she'd like me to focus on model priors and make sure they're reasonable and optimal, especially K
 + customized server bashrc and vimrc last night
 + tested manual upload
 + walked through normal upload for leveraged site so i can help people with that
 + linked github gist to model code on data portal

### 20171115
 + changed server password properly (updating config file and restarting nginx server)
 + modified usgs api query on ~410 in app.py so that it asks for data in UTC, which then matches the time of our datasets and doesnt result in NAs for discharge and level for the first 15 rows of dd (post-spreading); formerly there would also be 20 rows that only contained discharge and level at the end of each dataset.
   + in so doing, fixed download issue
 + asked everyone to move over to the new slack
 + learned how to restart our web server after making changes and restart our digitalocean server to install updates

### 20171114
 + learned how to do a data portal password reset
 + explored the database, learned how to set user permissions
 + discovered a few bugs in the gapfiller code (added bug list to mike_todo slack channel)
 + changed server password

### 20171113
 + organized notes, meeting recordings, questions, and todo list
 + added Gordon's photo to the site
 + made Bob's document of considerations and instructions more prominent (now linked from the "participate" page, which is also linked from the home page body)
 + separated download step from format/run step in the model code

