# setwd('~/git/streampulse/server_copy/sp/shiny/')

library(shiny)
library(Cairo)
library(ks)
library(scales)
library(shinyjs)

options(shiny.usecairo=TRUE)

shinyServer(
    function(input, output, session) {

        # buildDy = function(i){
        #     dygraph(ts$data, group = "powstreams",
        #         periodicity=list(scale='minute',label='minute')) %>%
        #     dyOptions(colors = brewer.pal(max(3,length(names(ts$data))),
        #         "Dark2")) %>%
        #     dyHighlight(highlightSeriesBackgroundAlpha = 0.65,
        #         hideOnMouseOut = TRUE) %>%
        #     dyAxis("y", label = ts$ylab) %>%
        #     dyOptions(labelsUTC = TRUE) %>%
        #     dyRangeSelector(., fillColor='', strokeColor='', height=20)
        # }

        # dy1 <- eventReactive(input$render, {
        #     buildDy(1)
        # })
        # output$GRAPH1 = renderDygraph({
          # ylabel = paste(ylabel1())
          # dygraph1()
        # })

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

        observe({
            updateSelectizeInput(session, 'input_year',
                choices=siteyears[sitenames == input$input_site])
            # updateSelectizeInput(session, 'input_year2',
            #     choices=siteyears[sitenames == input$input_site],
            #     selected=input$input_year)
            # updateSelectizeInput(session, 'input_site2',
            #     choices=unique(sitenames),
            #     selected=input$input_site)
        })
        observe({
            updateSelectizeInput(session, 'input_year2',
                choices=siteyears[sitenames == input$input_site2])
        })

        output$time_slider = renderUI({

            modpred = update_pg2()
            mod_out = modpred$mod_out

            slider_toggleA <<- !slider_toggleA
            # print(paste('sliderA', slider_toggleA))

            if(!is.null(mod_out$data$solar.time[1])){

                slider_toggleB <<- !slider_toggleB
                # print(paste('sliderB', slider_toggleB))

                #convert POSIX time to DOY and UNIX time
                DOY = as.numeric(gsub('^0+', '',
                    strftime(mod_out$data$solar.time, format="%j")))

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

        # output$select_time = renderUI({
        #     selectInput('input_year', label='Select year',
        #         choices=siteyears[sitenames == input$input_site],
        #         selectize=TRUE)
        # })

        update_pg1 = reactive({
            regionsite = input$input_site
            year = input$input_year
            #input_year depends on input_site, but server must call to ui and
            #hear back before year can update, so the following is needed:
            legit_year = year %in% siteyears[sitenames == input$input_site]
            if(regionsite != '' && year != '' && legit_year){
                modOut_ind = grep(paste0('modOut_', regionsite, '_', year,
                    '.*'), fnames)
                # predictions_ind = grep(paste0('predictions_', regionsite,
                #     '_', year, '.*'), fnames)
                modOut = readRDS(paste0('data/', fnames[modOut_ind[1]]))
                # preds = readRDS(paste0('data/', fnames[predictions_ind[1]]))
                # out = list(mod_out=modOut, predictions=preds)
            } else {
                modOut = NULL
                # out = NULL
            }
            return(modOut)
            # return(out)
        })

        update_pg2 = reactive({

            regionsite = input$input_site2
            year = input$input_year2
            # print(paste(regionsite, year))

            #input_year depends on input_site, but server must call to ui and
            #hear back before year can update, so the following is needed:
            legit_year = year %in% siteyears[sitenames == input$input_site2]

            time2_toggleA <<- !time2_toggleA
            # print(paste('time2A', time2_toggleA))

            if(regionsite != '' && year != '' && legit_year){
                time2_toggleB <<- !time2_toggleB
                # print(paste('time2B', time2_toggleB))

                modOut_ind = grep(paste0('modOut_', regionsite, '_', year,
                    '.*'), fnames)
                predictions_ind = grep(paste0('predictions_', regionsite,
                    '_', year, '.*'), fnames)
                modOut = readRDS(paste0('data/', fnames[modOut_ind[1]]))
                preds = readRDS(paste0('data/', fnames[predictions_ind[1]]))
                out = list(mod_out=modOut, predictions=preds)
            } else {
                out = NULL
            }
            return(out)
        })

        output$KvQvER = renderPlot({
            mod_out = update_pg1()
            # mod_out = modpred$mod_out
            if(!is.null(mod_out)){
                KvQvER_plot(mod_out=mod_out)
            }
        # }, height=150)
        }, height=height50)
        # })

        output$O2_plot = renderPlot({
            modpred = update_pg2()
            mod_out = modpred$mod_out
            # mod_out = mod_out()
            if(!is.null(mod_out) & !is.null(input$range) &
                    counter %% 2 == 1 & counter > 1){
                par(mar=c(3,4,0,1), oma=rep(0,4))
                O2_plot(mod_out=mod_out, st=input$range[
                    1], en=input$range[2],
                    input$O2_brush)
            }
        # }, height=150)
        }, height=height40)
        # })

        output$kernel_plot = renderPlot({
            modpred = update_pg2()
            predictions = modpred$predictions
            # predictions = predictions()
            if(!is.null(predictions) & !is.null(input$range)){
                ts_full = processing_func(predictions, st=input$range[1],
                    en=input$range[2])
                par(mar=c(3,3.5,0,.5), oma=rep(0,4))
                kernel_func(ts_full, 'Name and Year')
            }
        # }, height=150)
        }, height=height35)
        # })

        output$metab_plot = renderPlot({
            modpred = update_pg2()
            predictions = modpred$predictions
            print(paste(!is.null(predictions), !is.null(input$range)))
            if(!is.null(predictions) & !is.null(input$range)){
                ts_full = processing_func(predictions, st=input$range[1],
                    en=input$range[2])
                par(mar=c(1,4,0,1), oma=rep(0,4))
                season_ts_func(ts_full, TRUE, st=input$range[1],
                    en=input$range[2])
            }
        # }, height=150)
        }, height=height35)
        # })

        # output$series_plots = renderPlot({
        #     ts_full = processing_func(predictions, st=input$range[1],
        #         en=input$range[2])
        #     series_plots(ts_full, TRUE, st=input$range[1], en=input$range[2],
        #         input$O2_brush)
        # # })
        # })#, height='auto', width='auto')

        output$cumul_plot = renderPlot({
            modpred = update_pg2()
            predictions = modpred$predictions
            if(!is.null(predictions) & !is.null(input$range)){
                ts_full = processing_func(predictions, st=input$range[1],
                    en=input$range[2])
                par(mar=c(3,3.5,0.2,0.5), oma=rep(0,4))
                cumulative_func(ts_full, st=input$range[1],
                    en=input$range[2])
            }
        # }, height=150)
        }, height=height35)
        # })

        output$cumul_legend = renderPlot({
            cumul_legend()
        }, height=height05)

        output$metab_legend = renderPlot({
            metab_legend()
        }, height=height05)

        output$kernel_legend = renderPlot({
            kernel_legend()
        }, height=height05)

        output$O2_legend = renderPlot({
            O2_legend()
        }, height=height05)

        # output$triplot = renderPlot({
        #     diag_plots(predictions, 'Name and Year', TRUE, st=input$range[1],
        #         en=input$range[2])
        # })

        # output$info = renderText({
        #     brush_coords = function(e) {
        #         if(is.null(e)) return("NULL\n")
        #         paste0("xmin=", round(e$xmin, 1), " xmax=", round(e$xmax, 1),
        #             " ymin=", round(e$ymin, 1), " ymax=", round(e$ymax, 1))
        #     }
        #     paste0('brush: ', brush_coords(input$O2_brush))
        # })

    })


