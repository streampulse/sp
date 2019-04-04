# setwd('~/git/streampulse/server_copy/sp/shiny/')

library(shiny)
library(Cairo)
library(ks)
# library(scales)
# library(shinyjs)

options(shiny.usecairo=TRUE)

shinyServer(function(input, output, session){

    #replot when a click is registered; don't react when click handler flushes
    # observeEvent({
    #     if (! is.null(input$KvER_click$x) ||
    #         ! is.null(input$KvQ_click$x) ||
    #         ! is.null(input$QvKres_click$x) ||
    #         ! is.null(input$KvGPP_click$x)) TRUE
    #     else NULL
    # }, {
    #
    #     slices = get_slices()
    #     mod_out = slices$mod_out
    #     MPstart = input$MPrange[1]
    #     MPend = input$MPrange[2]

    output$kdens = renderPlot({
        kdens_plot()
    })

    # }, ignoreNULL=TRUE)

})
