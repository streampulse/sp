# setwd('~/git/streampulse/server_copy/sp/shiny/')

library(shiny)
library(Cairo)
library(ks)
library(scales)
library(shinyjs)

options(shiny.usecairo=TRUE)

shinyServer(function(input, output, session){

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
            updateSelectizeInput(session, 'input_site', choices=sitenames,
                selected='', options=list(placeholder='No site selected'))
            updateSelectizeInput(session, 'input_site2', choices=sitenames,
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

        if(token == ''){
            sitenmyr = sitenmyr_all[sitenmyr_all[,1] %in% sitenames_public,]
            sitenames = sitenmyr[,1]
            siteyears = sitenmyr[,2]
        }

        dbDisconnect(con)

        out = list(sitenames=sitenames, siteyears=siteyears)
        return(out)
    })

    observeEvent(input$submit_token, {
        viewable_mods()
        counter2 = input$hidden_counter2
        updateTextInput(session, 'hidden_counter2', label=NULL,
            value=as.numeric(counter2) + 1)
    })

    observeEvent(input$input_site, {
        v = viewable_mods()
        updateSelectizeInput(session, 'input_year',
            choices=v$siteyears[v$sitenames == input$input_site])
    })

    update_pg1 = reactive({

        v = viewable_mods()

        regionsite = input$input_site
        year = input$input_year

        #input_year depends on input_site, but server must call to ui and
        #hear back before year can update, so the following is needed:
        # legit_year = year %in% siteyears[sitenames == input$input_site]
        legit_year = year %in% v$siteyears[v$sitenames == input$input_site]

        if(regionsite != '' && year != '' && legit_year){
            modOut_ind = grep(paste0('modOut_', regionsite, '_', year,
                '.*'), fnames)
            modOut = readRDS(paste0('data/', fnames[modOut_ind[1]]))
        } else {
            modOut = NULL
        }

        return(modOut)
    })

    # output$time_slider = renderUI({
    #
    #     modpred = update_pg2()
    #     mod_out = modpred$mod_out
    #
    #     slider_toggleA <<- !slider_toggleA
    #     # print(paste('sliderA', slider_toggleA))
    #
    #     if(!is.null(mod_out$data$solar.time[1])){
    #
    #         slider_toggleB <<- !slider_toggleB
    #         # print(paste('sliderB', slider_toggleB))
    #
    #         #convert POSIX time to DOY and UNIX time
    #         DOY = as.numeric(gsub('^0+', '',
    #             strftime(mod_out$data$solar.time, format="%j")))
    #
    #         #get DOY bounds for slider
    #         DOYmin = ifelse(DOY[1] %in% 365:366, 1, DOY[1])
    #         DOYmax = DOY[length(DOY)]
    #
    #         sliderInput("range", label=NULL,
    #             min=DOYmin, max=DOYmax, value=c(DOYmin, DOYmax),
    #             ticks=TRUE, step=6,
    #             animate=animationOptions(interval=2000)
    #         )
    #     }
    # })

    observeEvent(input$input_site2, {

        v = viewable_mods()

        regionsite = input$input_site2
        year = input$input_year2
        available_years = v$siteyears[v$sitenames == regionsite]
        legit_year = year %in% available_years

        if(regionsite != ''){
            if(year == '' || !legit_year){
                year = max(available_years)
            }

            updateSelectizeInput(session, 'input_year2',
                choices=available_years, selected=year)

            #so that ui callback necessetated even when year doesnt change.
            #model output will update if either select box changes
            counter = input$hidden_counter
            updateTextInput(session, 'hidden_counter', label=NULL,
                value=as.numeric(counter) + 1)
        }

    })

    fitpred = eventReactive({
        input$input_year2
        input$hidden_counter
    }, {

        v = viewable_mods()

        year = input$input_year2
        regionsite = input$input_site2
        # available_years = siteyears[sitenames == regionsite]
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

    #this allows incrementing of the counter without causing feedback loop
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

    observeEvent({
        input$range
        input$hidden_counter2
    }, {
        fitpred = fitpred()

        start = input$range[1]
        end = input$range[2]

        if(input$input_site2 == '' && !is.null(start) && !is.null(end)){

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
                        input$O2_brush)
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

    output$KvQvER = renderPlot({
        mod_out = update_pg1()
        if(!is.null(mod_out)){
            KvQvER_plot(mod_out=mod_out)
        }
    }, height=height50)

})


