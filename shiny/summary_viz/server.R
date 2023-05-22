# setwd('~/git/streampulse/server_copy/sp/shiny/')

library(shiny)
library(Cairo)
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
    KDHeight = reactive({
        ifelse(is.null(input$KDHeight), 0, input$KDHeight)
    })

    js$getHeight90()
    js$getHeight50()
    js$getHeight10()
    js$getKDHeight()

    #handle auth
    observe({

        input$submit_token
        token = isolate(input$token_input)

        #get user's private sites
        con = dbConnect(RMariaDB::MariaDB(), dbname='sp',
            username='root', password=pw)
        res = dbSendQuery(con,
            paste0("SELECT qaqc FROM user WHERE token = '", token, "';"))
        usersites = dbFetch(res)$qaqc
        dbClearResult(res)
        dbDisconnect(con)

        #update select list and print auth result to user
        if(isTruthy(usersites)){
            usersites = strsplit(usersites, ',')[[1]]
            authed_sites = c(sitenames_public, usersites)
            modelnames_authed = intersect(sitenm_all, authed_sites)
            sitenames = sitenm_all[sitenm_all %in% modelnames_authed]
            output$token_resp = renderText({
                paste('Authorized for', length(usersites), 'StreamPULSE sites.')
            })

            updateSelectizeInput(session, 'input_site',
                label='Select site(s) to overlay',
                choices=sitenames)
                # choices=list('StreamPULSE sites'=sitenames,
                #     'Powell Center sites'=sitenm_all_pow))

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
    })

    #generate initial plot and legend with no overlay
    output$kdens_legend = renderPlot({
        kdens_legend(is_overlay=FALSE)
    }, height=height10)

    output$kdens = renderPlot({
        kdens_plot(overlay='None', tmin=1, tmax=366)
    }, height=height90)

    #replot when button is clicked
    observeEvent({
        input$replot
        # input$slider
    }, {
        site_sel = input$input_site

        output$kdens_legend = renderPlot({
            kdens_legend(is_overlay=ifelse(is.null(site_sel) ||
                (length(site_sel) == 1 && site_sel == 'None'),
                FALSE, TRUE))
        }, height=height10)

        output$kdens = renderPlot({
            kdens_plot(overlay=site_sel, tmin=input$slider[1],
                tmax=input$slider[2], recompute_overall_dens=FALSE)
        }, height=height90)
    })

    #replot when time slider is adjusted
    observeEvent({
        input$slider
    }, {
        site_sel = input$input_site

        output$kdens_legend = renderPlot({
            kdens_legend(is_overlay=ifelse(is.null(site_sel) ||
                (length(site_sel) == 1 && site_sel == 'None'),
                FALSE, TRUE))
        }, height=height10)

        output$kdens = renderPlot({
            kdens_plot(overlay=site_sel, tmin=input$slider[1],
                tmax=input$slider[2], recompute_overall_dens=TRUE)
        }, height=height90)
    })

    #clear selections and remove overlay when other button is clicked
    observeEvent({
        input$clear
    }, {
        updateSelectizeInput(session, 'input_site',
            label='Select site(s) to overlay',
            # choices=list('StreamPULSE sites'=sitenames,
            #     'Powell Center sites'=sitenm_all_pow))
            choices=sitenames)

        updateSliderInput(session, 'slider', label='Select DOY range',
            min=1, max=366, value=c(1, 366), step=18)

        output$kdens_legend = renderPlot({
            kdens_legend(is_overlay=FALSE)
        }, height=height10)

        output$kdens = renderPlot({
            kdens_plot(overlay='None', tmin=1,
                tmax=366)
        }, height=height90)
    })

})
