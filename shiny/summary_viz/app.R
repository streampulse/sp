
library(shiny)
source('helpers.R')

ui = fluidPage(
    titlePanel(HTML(paste("<h4 style='color:#663399'>Coupled O2 and CO2 diel",
        "metabolism 'toy' model</h3>")), windowTitle='CO2-O2 Toy Model'),

    sidebarLayout(
        sidebarPanel(

            # Input: Sliders
            fluidRow(
                column(4,
                    p(strong('Slope of P-I curve'), '(alpha; umol/m2/hr/uE)',
                        style='font-size:75%')
                    # HTML(paste0("<p style='font-size:75%'>Slope of P-I ",
                    #     "curve<br>(alpha PI; umol/m2/hr/uE)</p>"))
                ),
                column(8,
                    sliderInput(inputId='alphaPI', label=NULL,
                        min=0.1, max=10, value=1)
                )
            ),
            fluidRow(
                column(4,
                    p(strong('ER to std temp'),
                        '(Rstd; mol/m2/day)', style='font-size:75%')
                ),
                column(8,
                    sliderInput(inputId='Rstd', label=NULL,
                        min=0.1, max=10, value=1)
                )
            ),
            fluidRow(
                column(4,
                    p(strong('k of CO2 at std temp'),
                        '(kstd; m/hr)', style='font-size:75%')
                ),
                column(8,
                    sliderInput(inputId='kstd', label=NULL,
                        min=0.01, max=10, value=0.15)
                )
            ),
            fluidRow(
                column(6,
                    p(strong('Avg stream depth'), '(m)', style='font-size:75%'),
                    numericInput(inputId='depth', label=NULL,
                        min=0, max=100, value=0.5),
                    p(strong('Tot alkalinity'), '(umol/L)',
                        style='font-size:75%'),
                    numericInput(inputId='TAlk', label=NULL,
                        min=0, max=10000, value=1000),
                    p(strong('Initial [DIC]'), '(umol/L)',
                        style='font-size:75%'),
                    numericInput(inputId='TCO2_init', label=NULL,
                        min=0, max=10000, value=1200)
                ),
                column(6,
                    p(strong('Init pCO2 aq'), '(uatm)',
                        style='font-size:75%'),
                    numericInput(inputId='pCO2_init', label=NULL,
                        min=0, max=10000, value=2000),
                    p(strong('pCO2 air'), '(uatm)', style='font-size:75%'),
                    numericInput(inputId='pCO2_air', label=NULL,
                        min=0, max=10000, value=410),
                    p(strong('Init [O2]'), '(umol/L)', style='font-size:75%'),
                    numericInput(inputId='O2_init', label=NULL,
                        min=0, max=10000, value=280)
                )
            ),
            fluidRow(
                column(6, align='center',
                    p(strong('Extend to 4 days'), style='font-size:75%'),
                    checkboxInput('extend4days', label=NULL)
                ),
                column(6, align='left',
                    p(strong('Select dataset'), style='font-size:75%'),
                    radioButtons('chooseCreek', label=NULL,
                        choiceNames=list(p('Fish Trap Creek', style='font-size:75%'),
                            p('FLBS Stream', style='font-size:75%')),
                        choiceValues=list('fishTrapCreek', 'FLBS'))
                )
            )
        ),
        mainPanel(

            # Output: Time series plot of dissolved O2 and pCO2 ----
            plotOutput(outputId='plotLegend', height='30px', width='auto'),
            plotOutput(outputId='timeSeriesPlot_O2_CO2',
                height='200px', width='auto'),
            plotOutput(outputId='timeSeriesPlot_pH_DIC',
                height='250px', width='auto'),
            # fluidRow(
            #     column(12, align='center',
            #         p(strong('24 hour averages (mol/m2/day):'),
            #             style='font-size:75%; color:#663399')
            #     )
            # ),
            fluidRow(
                column(2, align='left', offset=1,
                    p(strong('24 hour averages (mol/m2/day):'),
                        style='font-size:75%; color:#663399')
                ),
                column(2, align='center',
                    div(style='outline:solid #663399',
                        p(strong('GPP'), style='font-size:75%'),
                        htmlOutput(outputId='GPP')
                    )
                ),
                column(2, align='center',
                    div(style='outline:solid #663399',
                        p(strong('ER'), style='font-size:75%'),
                        htmlOutput(outputId='ER')
                    )
                ),
                column(2, align='center',
                    div(style='outline:solid #663399',
                        p(strong('G O2'),style='font-size:75%'),
                        htmlOutput(outputId='G_O2')
                    )
                ),
                column(2, align='center',
                    div(style='outline:solid #663399',
                        p(strong('G CO2'),style='font-size:75%'),
                        htmlOutput(outputId='G_CO2')
                    )
                )
            )
        )
    )
)

# Define server logic required to time seroes plot of model output ----
server = function(input, output) {

    getModRes = reactive({

        # set background data for selected dataset
        if(input$chooseCreek == 'fishTrapCreek'){
            x.lt = as.POSIXlt(FishtrapCr$dateTime)
            temperature = FishtrapCr$Temp_C
            PAR = FishtrapCr$PAR_uE
            lat = 48.93861111
            long = -122.47861111
            tz = -8
        } else {
            x.lt = as.POSIXlt(RoysCr$dateTime)
            temperature = RoysCr$Temp_C
            PAR = RoysCr$lux
            lat = 47.887404
            long = -114.117811
            tz = -6
        }

        masl = 1
        salinity = 0

        #extend time and temperature time series if box is checked,
        #then determine local hour and DOY
        extnd = input$extend4days
        if(extnd){
            x.lt = as.POSIXlt(seq(x.lt[1], by='10 min', length.out=96 * 6))
            # localHour = seq(localHour[1], by=1/6, length.out=96 * 6)
            temperature = c(temperature, rep(10, 96 * 6 - length(temperature)))
            PAR = c(PAR, rep(mean(PAR, na.rm=TRUE), 96 * 6 - length(PAR)))
        }
        localHour = x.lt$hour + x.lt$min/60 + x.lt$sec/3600
        DOY = x.lt$yday

        # Static variable inputs (single value) from user interface
        depth = input$depth
        TAlk = input$TAlk
        TCO2_init = input$TCO2_init      # Units of umol/L
        pCO2_init = input$pCO2_init     # Units of uatm
        O2_init = input$O2_init     # Units of umol
        pCO2_air = input$pCO2_air     # Units of uatm

        # Dynamic variable inputs (sliders) from user interface
        alphaPI_hr = input$alphaPI    # Units are umol/m2/hr/uE
        Rstd_day = input$Rstd        # Units are mol/m2/day
        kstd_hr = input$kstd      # Units are m/hr

        modelResults = main(temperature=temperature, localHour=localHour,
            DOY=DOY, PAR=PAR, TAlk=TAlk, pCO2_init=pCO2_init,
            pCO2_air=pCO2_air, alphaPI_hr=alphaPI_hr, Rstd_day=Rstd_day,
            kstd_hr=kstd_hr, referenceT=20, lat=lat, long=long,
            depth=depth, salinity=0, masl=1, O2_init=O2_init)

        return(modelResults)
    })

    # 2. Output is two plots and numberic values for 24 hr GPP, ER, and G
    output$plotLegend = renderPlot({
        plotLegend()
    })
    output$timeSeriesPlot_O2_CO2 = renderPlot({
        modres = getModRes()
        # mm <<- modres
        plotO2_CO2(modres)
    })
    output$timeSeriesPlot_pH_DIC = renderPlot({
        modres = getModRes()
        plotpH_DIC(modres)
    })
    #Add numeric outputs
    output$GPP = renderText({
        modres = getModRes()
        gppout = paste("<p style='color:#663399'>", round(modres$GPP, 3), '</p>')
        return(HTML(gppout))
    })
    output$ER = renderText({
        modres = getModRes()
        erout = paste("<p style='color:#663399'>", round(modres$ER, 3), '</p>')
        return(HTML(erout))
    })
    output$G_O2 = renderText({
        modres = getModRes()
        gO2out = paste("<p style='color:#663399'>",
            round(modres$G_O2_24hr, 3), '</p>')
        return(HTML(gO2out))
    })
    output$G_CO2 = renderText({
        modres = getModRes()
        gCO2out = paste("<p style='color:#663399'>",
            round(modres$G_CO2_24hr, 3), '</p>')
        return(HTML(gCO2out))
    })
}

shinyApp(ui=ui, server=server)
