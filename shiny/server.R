# setwd('~/git/streampulse/server_copy/sp/shiny/')

library(shiny)
library(Cairo)
library(ks)
library(scales)
library(shinyjs)

options(shiny.usecairo=TRUE)

shinyServer(function(input, output, session){

    #hacky way to specify div height by % with js
    height50 = reactive({
        ifelse(is.null(input$height50), 0, input$height50)
    })
    height40 = reactive({
        ifelse(is.null(input$height40), 0, input$height40)
    })
    height35 = reactive({
        ifelse(is.null(input$height35), 0, input$height35)
    })
    height10 = reactive({
        ifelse(is.null(input$height10), 0, input$height10)
    })
    height05 = reactive({
        ifelse(is.null(input$height05), 0, input$height05)
    })

    js$getHeight50()
    js$getHeight40()
    js$getHeight35()
    js$getHeight10()
    js$getHeight05()

    #determine which models the user has access to, based on their token
    viewable_mods = reactive({

        input$submit_token
        token = isolate(input$token_input)

        con = dbConnect(RMariaDB::MariaDB(), dbname='sp',
            username='root', password=pw)

        res = dbSendQuery(con,
            paste0("SELECT qaqc FROM user WHERE token = '", token, "';"))
        usersites = dbFetch(res)$qaqc

        dbClearResult(res)

        if(isTruthy(usersites)){
            usersites = strsplit(usersites, ',')[[1]]
            authed_sites = c(sitenames_public, usersites)
            modelnames_authed = intersect(sitenmyr_all[,1], authed_sites)
            sitenmyr = sitenmyr_all[sitenmyr_all[,1] %in% modelnames_authed,]
            sitenames = sitenmyr[,1]
            siteyears = sitenmyr[,2]
            output$token_resp = renderText({
                paste('Authorized for', length(usersites), 'sites.')
            })
            updateSelectizeInput(session, 'MPinput_site', choices=sitenames,
                selected='', options=list(placeholder='No site selected'))
            updateSelectizeInput(session, 'input_site', choices=sitenames,
                selected='', options=list(placeholder='No site selected'))
        } else {
            if(length(usersites) && usersites == ''){
                output$token_resp = renderText({
                    'No private site permissions\nassociated with this token.'
                })
            } else {
                if(input$token_input != ''){
                    output$token_resp = renderText({
                        'Invalid token.'
                    })
                }
            }
        }

        # if(token == ''){
        #     sitenmyr = sitenmyr_all[sitenmyr_all[,1] %in% sitenames_public,]
        #     sitenames = sitenmyr[,1]
        #     siteyears = sitenmyr[,2]
        # }

        dbDisconnect(con)

        out = list(sitenames=sitenames, siteyears=siteyears)
        return(out)
    })

    #trigger updates if user submits a token
    observeEvent(input$submit_token, {
        viewable_mods()

        counter2 = input$hidden_counter2
        updateTextInput(session, 'hidden_counter2', label=NULL,
            value=as.numeric(counter2) + 1)

        MPcounter2 = input$MPhidden_counter2
        updateTextInput(session, 'MPhidden_counter2', label=NULL,
            value=as.numeric(MPcounter2) + 1)
    })

    #update year input and trigger update of slider + plots if site changes (o2 and metab page)
    observeEvent(input$input_site, {

        v = viewable_mods()

        regionsite = input$input_site
        year = input$input_year
        available_years = v$siteyears[v$sitenames == regionsite]
        legit_year = year %in% available_years

        if(regionsite != ''){
            if(year == '' || !legit_year){
                year = max(available_years)
            }

            updateSelectizeInput(session, 'input_year',
                choices=available_years, selected=year)

            #so that ui callback necessetated even when year doesnt change.
            #model output will update if either select box changes
            counter = input$hidden_counter
            updateTextInput(session, 'hidden_counter', label=NULL,
                value=as.numeric(counter) + 1)
        }

    })

    #same as above, but for model performance page
    observeEvent(input$MPinput_site, {

        MPv = viewable_mods()

        MPregionsite = input$MPinput_site
        MPyear = input$MPinput_year
        MPavailable_years = MPv$siteyears[MPv$sitenames == MPregionsite]
        MPlegit_year = MPyear %in% MPavailable_years

        if(MPregionsite != ''){
            if(MPyear == '' || !MPlegit_year){
                MPyear = max(MPavailable_years)
            }

            updateSelectizeInput(session, 'MPinput_year',
                choices=MPavailable_years, selected=MPyear)

            #so that ui callback necessetated even when year doesnt change.
            #model output will update if either select box changes
            MPcounter = input$MPhidden_counter
            updateTextInput(session, 'MPhidden_counter', label=NULL,
                value=as.numeric(MPcounter) + 1)
        }

    })

    #get model fits and predictions for specified siteyear (for o2 and metab page)
    fitpred = eventReactive({
        input$input_year
        input$hidden_counter
    }, {

        v = viewable_mods()

        year = input$input_year
        regionsite = input$input_site
        available_years = v$siteyears[v$sitenames == regionsite]
        legit_year = year %in% available_years

        if(year != '' && legit_year){

            #read in model fit and prediction objects
            modOut_ind = grep(paste0('modOut_', regionsite, '_', year,
                '.*'), fnames)
            predictions_ind = grep(paste0('predictions_', regionsite,
                '_', year, '.*'), fnames)
            mod_out = readRDS(paste0('data/', fnames[modOut_ind[1]]))
            predictions = readRDS(paste0('data/',
                fnames[predictions_ind[1]]))

            return(list('mod_out'=mod_out, 'predictions'=predictions))

        } else {
            return(NULL)
        }

    })

    #get model fits and predictions for specified siteyear (for mod performance page)
    MPfitpred = eventReactive({
        input$MPinput_year
        input$MPhidden_counter
    }, {

        MPv = viewable_mods()

        MPyear = input$MPinput_year
        MPregionsite = input$MPinput_site
        MPavailable_years = MPv$siteyears[MPv$sitenames == MPregionsite]
        MPlegit_year = MPyear %in% MPavailable_years

        if(MPyear != '' && MPlegit_year){

            #read in model fit and prediction objects
            MPmodOut_ind = grep(paste0('modOut_', MPregionsite, '_', MPyear,
                '.*'), fnames)
            MPpredictions_ind = grep(paste0('predictions_', MPregionsite,
                '_', MPyear, '.*'), fnames)
            MPmod_out = readRDS(paste0('data/', fnames[MPmodOut_ind[1]]))
            MPpredictions = readRDS(paste0('data/',
                fnames[MPpredictions_ind[1]]))

            return(list('mod_out'=MPmod_out, 'predictions'=MPpredictions))

        } else {
            return(NULL)
        }

    })

    #this allows incrementing of counter 2 without causing feedback loop
    #inside renderUI below; unfortunately roundabout
    fitpred2 = eventReactive(fitpred(), {

        fitpred = fitpred()

        if(!is.null(fitpred)){
            counter2 = input$hidden_counter2
            updateTextInput(session, 'hidden_counter2', label=NULL,
                value=as.numeric(counter2) + 1)

            return(fitpred)
        } else {
            return(NULL)
        }

    })

    #here's the same thing as above, but for the model performance page
    MPfitpred2 = eventReactive(MPfitpred(), {

        MPfitpred = MPfitpred()

        if(!is.null(MPfitpred)){
            MPcounter2 = input$MPhidden_counter2
            updateTextInput(session, 'MPhidden_counter2', label=NULL,
                value=as.numeric(MPcounter2) + 1)

            return(MPfitpred)
        } else {
            return(NULL)
        }

    })

    #time slider: o2 and metab page
    output$time_slider = renderUI({

        fitpred = fitpred2()

        if(!is.null(fitpred)){

            #convert POSIX time to DOY and UNIX time
            DOY = as.numeric(gsub('^0+', '',
                strftime(fitpred$mod_out$data$solar.time, format="%j")))

            #get DOY bounds for slider
            DOYmin = ifelse(DOY[1] %in% 365:366, 1, DOY[1])
            DOYmax = DOY[length(DOY)]

            sliderInput("range", label=NULL,
                min=DOYmin, max=DOYmax, value=c(DOYmin, DOYmax),
                ticks=TRUE, step=6,
                animate=animationOptions(interval=2000)
            )
        }
    })

    #time slider: model performance page
    output$MPtime_slider = renderUI({

        MPfitpred = MPfitpred2()

        if(!is.null(MPfitpred)){

            #convert POSIX time to DOY and UNIX time
            MPDOY = as.numeric(gsub('^0+', '',
                strftime(MPfitpred$mod_out$data$solar.time, format="%j")))

            #get DOY bounds for slider
            MPDOYmin = ifelse(MPDOY[1] %in% 365:366, 1, MPDOY[1])
            MPDOYmax = MPDOY[length(MPDOY)]

            sliderInput("MPrange", label=NULL,
                min=MPDOYmin, max=MPDOYmax, value=c(MPDOYmin, MPDOYmax),
                ticks=TRUE, step=6,
                animate=animationOptions(interval=2000)
            )
        }
    })

    #o2 and metab plots
    observeEvent({
        input$range
        input$hidden_counter2
    }, {
        fitpred = fitpred()

        start = input$range[1]
        end = input$range[2]

        if(input$input_site == '' && !is.null(start) && !is.null(end)){

            #all blank plots for the rare case in which someone anonymously
            #chooses a model, then enters a token.
            output$metab_legend = renderPlot({
                defpar = par(mar=rep(0,4), oma=rep(0,4))
                plot(1, 1, type='n', axes=FALSE, xlab='', ylab='')
            }, height=height05)

            output$cumul_legend = renderPlot({
                defpar = par(mar=rep(0,4), oma=rep(0,4))
                plot(1, 1, type='n', axes=FALSE, xlab='', ylab='')
            }, height=height05)

            output$metab_plot = renderPlot({
                plot(1, 1, type='n', axes=FALSE, xlab='', ylab='')
            }, height=height35)

            output$cumul_plot = renderPlot({
                plot(1, 1, type='n', axes=FALSE, xlab='', ylab='')
            }, height=height35)

            output$O2_legend = renderPlot({
                defpar = par(mar=rep(0,4), oma=rep(0,4))
                plot(1, 1, type='n', axes=FALSE, xlab='', ylab='')
            }, height=height05)

            output$kernel_legend = renderPlot({
                defpar = par(mar=rep(0,4), oma=rep(0,4))
                plot(1, 1, type='n', axes=FALSE, xlab='', ylab='')
            }, height=height05)

            output$O2_plot = renderPlot({
                plot(1, 1, type='n', axes=FALSE, xlab='', ylab='')
            }, height=height35)

            output$kernel_plot = renderPlot({
                plot(1, 1, type='n', axes=FALSE, xlab='', ylab='')
            }, height=height35)

        } else {
            if(!is.null(start) && !is.null(end)){
                output$metab_legend = renderPlot({
                    metab_legend()
                }, height=height05)

                output$cumul_legend = renderPlot({
                    cumul_legend()
                }, height=height05)

                output$metab_plot = renderPlot({
                    ts_full = processing_func(fitpred$predictions, st=start,
                        en=end)
                    par(mar=c(1,4,0,1), oma=rep(0,4))
                    season_ts_func(ts_full, TRUE, st=start, en=end)
                }, height=height35)

                output$cumul_plot = renderPlot({
                    ts_full = processing_func(fitpred$predictions, st=start,
                        en=end)
                    par(mar=c(3,3.5,0.2,0.5), oma=rep(0,4))
                    cumulative_func(ts_full, st=start, en=end)
                }, height=height35)

                output$O2_legend = renderPlot({
                    O2_legend()
                }, height=height05)

                output$kernel_legend = renderPlot({
                    kernel_legend()
                }, height=height05)

                output$O2_plot = renderPlot({
                    par(mar=c(3,4,0,1), oma=rep(0,4))
                    O2_plot(mod_out=fitpred$mod_out, st=start, en=end,
                        brush=input$O2_brush)
                }, height=height35)

                output$kernel_plot = renderPlot({
                    ts_full = processing_func(fitpred$predictions, st=start,
                        en=end)
                    par(mar=c(3,3.5,0,.5), oma=rep(0,4))
                    kernel_func(ts_full, 'Name and Year')
                }, height=height35)
            }
        }

    })

    #model performance plots
    observeEvent({
        input$MPrange
        input$MPhidden_counter2
    }, {
        MPfitpred = MPfitpred()

        MPstart = input$MPrange[1]
        MPend = input$MPrange[2]

        if(input$MPinput_site == '' && !is.null(MPstart) && !is.null(MPend)){

            #all blank plots for the rare case in which someone anonymously
            #chooses a model, then enters a token.
            output$KvER = renderPlot({
                plot(1, 1, type='n', axes=FALSE, xlab='', ylab='')
            }, height=height50)

            output$KvQ = renderPlot({
                plot(1, 1, type='n', axes=FALSE, xlab='', ylab='')
            }, height=height50)

            output$KvGPP = renderPlot({
                plot(1, 1, type='n', axes=FALSE, xlab='', ylab='')
            }, height=height50)

        } else {
            if(!is.null(MPstart) && !is.null(MPend)){

                output$KvER = renderPlot({
                    if(!is.null(MPfitpred$mod_out)){
                        KvER_plot(mod_out=MPfitpred$mod_out, st=MPstart,
                            en=MPend)
                    }
                }, height=height50)

                output$KvQ = renderPlot({
                    if(!is.null(MPfitpred$mod_out)){
                        KvQ_plot(mod_out=MPfitpred$mod_out, st=MPstart,
                            en=MPend)
                    }
                }, height=height50)

                output$KvGPP = renderPlot({
                    if(!is.null(MPfitpred$mod_out)){
                        KvGPP_plot(mod_out=MPfitpred$mod_out, st=MPstart,
                            en=MPend)
                    }
                }, height=height50)
            }
        }
    })

    #replot KvER when a click is registered
    #(don't react when the click object resets to NULL)
    observeEvent({
        input$KvER_click$x
    }, {
        MPfitpred = MPfitpred()

        MPstart = input$MPrange[1]
        MPend = input$MPrange[2]

        output$KvER = renderPlot({
            KvER_plot(mod_out=MPfitpred$mod_out, st=MPstart,
                en=MPend, click=isolate(input$KvER_click))
        }, height=height50)
    }, ignoreNULL=TRUE)

    #replot KvQ when a click is registered
    #(don't react when the click object resets to NULL)
    observeEvent({
        input$KvQ_click$x
    }, {
        MPfitpred = MPfitpred()

        MPstart = input$MPrange[1]
        MPend = input$MPrange[2]

        output$KvQ = renderPlot({
            KvQ_plot(mod_out=MPfitpred$mod_out, st=MPstart, en=MPend,
                click=isolate(input$KvQ_click))
        }, height=height50)
    }, ignoreNULL=TRUE)

    #replot KvGPP when a click is registered
    #(don't react when the click object resets to NULL)
    observeEvent({
        input$KvGPP_click$x
    }, {
        MPfitpred = MPfitpred()

        MPstart = input$MPrange[1]
        MPend = input$MPrange[2]

        output$KvGPP = renderPlot({
            KvGPP_plot(mod_out=MPfitpred$mod_out, st=MPstart,
                en=MPend, click=isolate(input$KvGPP_click))
        }, height=height50)
    }, ignoreNULL=TRUE)

})
