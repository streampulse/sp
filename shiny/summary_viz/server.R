# setwd('~/git/streampulse/server_copy/sp/shiny/')

library(shiny)
library(Cairo)
library(ks)
# library(scales)
library(shinyjs)

options(shiny.usecairo=TRUE)

shinyServer(function(input, output, session){

    height70 = reactive({
        ifelse(is.null(input$height70), 0, input$height70)
    })
    height50 = reactive({
        ifelse(is.null(input$height70), 0, input$height50)
    })
    height05 = reactive({
        ifelse(is.null(input$height05), 0, input$height05)
    })

    js$getHeight70()
    js$getHeight50()
    js$getHeight05()

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

    output$kdens_legend = renderPlot({
        kdens_legend()
    }, height=height05)

    output$kdens = renderPlot({
        kdens_plot()
    }, height=height70)

    # }, ignoreNULL=TRUE)

})
