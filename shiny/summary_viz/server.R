# setwd('~/git/streampulse/server_copy/sp/shiny/')

library(shiny)
library(Cairo)
library(ks)
# library(scales)
library(shinyjs)

options(shiny.usecairo=TRUE)

shinyServer(function(input, output, session){

    height90 = reactive({
        ifelse(is.null(input$height90), 0, input$height90)
    })
    height50 = reactive({
        ifelse(is.null(input$height50), 0, input$height50)
    })
    height10 = reactive({
        ifelse(is.null(input$height10), 0, input$height10)
    })

    js$getHeight90()
    js$getHeight50()
    js$getHeight10()

    output$kdens_legend = renderPlot({
        kdens_legend(is_overlay=FALSE)
    }, height=height10)

    output$kdens = renderPlot({
        kdens_plot(overlay='None')
    }, height=height90)

    #replot when button is clicked
    observeEvent({
        input$replot
    }, {
        site_sel = input$input_site

        if(! is.null(site_sel)){
            output$kdens_legend = renderPlot({
                # kdens_legend(is_overlay=ifelse(site_sel != 'None', TRUE, FALSE))
                kdens_legend(is_overlay=ifelse(is.null(site_sel) ||
                        (length(site_sel) == 1 && site_sel == 'None'), FALSE, TRUE))
                # kdens_legend(is_overlay=ifelse(! site_sel %in% c('', 'None'),
                #     TRUE, FALSE))
                # kdens_legend(is_overlay=ifelse(site_sel != 'None' &
                #     ! is.null(site_sel), TRUE, FALSE))
            }, height=height10)

            output$kdens = renderPlot({
                kdens_plot(overlay=site_sel)
            }, height=height90)
        }
    })

    observeEvent({
        input$clear
    }, {
        updateSelectizeInput(session, 'input_site', label='Overlay site(s)',
            choices=list('StreamPULSE sites'=sitenames,
                'Powell Center sites'=sitenm_all_pow))
        # updateSelectizeInput(session, 'input_site')
    })

})
