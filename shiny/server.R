# fit = readRDS(paste0('~/git/streampulse/server_copy/sp/shiny/data/fit_MD_DRKR_2016-02-18_2016-11-19_bayes_binned_obsproc_trapezoid_DO-mod_stan.rds'))
# library(streamMetabolizer)
# library(StreamPULSE)
# predictions = predict_metabolism(fit)
# data_daily = fit@data_daily
# data = fit@data
# fit = fit@fit
# mod_out = list('data_daily'=data_daily, 'data'=data, 'fit'=fit)
# saveRDS(mod_out, paste0('~/git/streampulse/server_copy/sp/shiny/data/modOut_MD_DRKR_2016-02-18_2016-11-19_bayes_binned_obsproc_trapezoid_DO-mod_stan.rds'))
# saveRDS(predictions, paste0('~/git/streampulse/server_copy/sp/shiny/data/predictions_MD_DRKR_2016-02-18_2016-11-19_bayes_binned_obsproc_trapezoid_DO-mod_stan.rds'))

# mod_out = readRDS(paste0('~/git/streampulse/server_copy/sp/shiny/data/',
#     'modOut_WI_BEC_2017-01-26_2018-01-25_bayes_binned_obsproc_trapezoid_',
#     'DO-mod_stan.rds'))
# predictions = readRDS(paste0('~/git/streampulse/server_copy/sp/shiny/data/',
#     'predictions_WI_BEC_2017-01-26_2018-01-25_bayes_binned_obsproc_trapezoid_',
#     'DO-mod_stan.rds'))

mod_out = readRDS(paste0('~/git/streampulse/server_copy/sp/shiny/data/modOut_MD_DRKR_2016-02-18_2016-11-19_bayes_binned_obsproc_trapezoid_DO-mod_stan.rds'))
predictions = readRDS(paste0('~/git/streampulse/server_copy/sp/shiny/data/predictions_MD_DRKR_2016-02-18_2016-11-19_bayes_binned_obsproc_trapezoid_DO-mod_stan.rds'))

# library(dplyr)
# library(dygraphs)
# library(ggplot2)
library(shiny)
library(Cairo)
library(ks)
# library(RColorBrewer)
library(scales)
options(shiny.usecairo=TRUE)

shinyServer(
    function(input, output) {

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
        output$KvQvER = renderPlot({
            KvQvER_plot(mod_out=mod_out)
        })

        # output$O2_plot = renderPlot({
        #     O2_plot(mod_out=mod_out, st=input$range[1], en=input$range[2],
        #         input$O2_brush)
        # }, height=250)

        output$kernel_plot = renderPlot({
            ts_full = processing_func(predictions, st=input$range[1],
                en=input$range[2])
            kernel_func(ts_full, 'Name and Year')
        }, height=300, width=300)

        # output$metab_plot = renderPlot({
        #     ts_full = processing_func(predictions, st=input$range[1],
        #         en=input$range[2])
        #     season_ts_func(ts_full, TRUE, st=input$range[1],
        #         en=input$range[2])
        # }, height=250)

        output$series_plots = renderPlot({
            ts_full = processing_func(predictions, st=input$range[1],
                en=input$range[2])
            series_plots(ts_full, TRUE, st=input$range[1], en=input$range[2],
                input$O2_brush)
        # })
        }, height=300)

        output$cumul_plot = renderPlot({
            ts_full = processing_func(predictions, st=input$range[1],
                en=input$range[2])
            cumulative_func(ts_full, st=input$range[1],
                en=input$range[2])
        }, height=300, width=300)

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


