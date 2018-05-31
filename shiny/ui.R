#load plot functions
source("helpers.R")

get_plotheight = "
shinyjs.init = function() {
  $(window).resize(shinyjs.getHeight50);
}

//shinyjs.calcHeight = function(propHeight) {
//  var h = $(window).height() * propHeight;
//  Shiny.onInputChange('plotHeight', Number(h.toFixed(0)));

shinyjs.getHeight50 = function() {
  Shiny.onInputChange('height50', $(window).height() * .5);
}
shinyjs.getHeight40 = function() {
  Shiny.onInputChange('height40', $(window).height() * .4);
}
"

shinyUI(
    fluidPage(
        shinyjs::useShinyjs(),
        shinyjs::extendShinyjs(text=get_plotheight,
            functions=c('getHeight50', 'getHeight40', 'init')),
        # navbarPage(title=tags$a(href='https://data.streampulse.org/',
        #     'StreamPULSE'),
        #     tabPanel(HTML("<a href=\"https://data.streampulse.org/sitelist\">Sitelist</a>"))
        #     # tabPanel(tags$a(href='https://data.streampulse.org/upload_choice/',
        #     # 'Upload'))
        # ),
        navbarPage(title=p(strong('Diagnostics')), inverse=TRUE,
            tabPanel('Model Performance',
                sidebarLayout(
                    sidebarPanel(
                        # selectInput(
                        #     "SOLUTES1",
                        #     label = "Solute",
                        #     choices = c('d','e','f'),
                        #     selected = "Ca"),
                        # helpText(
                        #     textOutput("LIMITS1"),
                        #     style = "color:#fc9272; font-size:85%;"),
                        # hr(),
                        # p(strong("Additional Options:")),
                        p(paste("Sample plots from streamMetabolizer model of",
                            "StreamPULSE's Black Earth",
                            "Creek site in Wisconsin. This app still under",
                            "development."), style='color:gray'),
                        # checkboxInput("HYDROLOGY1",
                        #     label = "Hydrology",
                        #     value = FALSE),
                        # conditionalPanel(
                        #     condition = "input.HYDROLOGY1 == true",
                        #     p(radioButtons("GAGEHT_or_Q1",
                        #         "Select data source:",
                        #         choices = c("Gage Height (mm)" = "GageHt",
                        #             "Q (L/s)" = "Q"),
                        #         selected = "GageHt",
                        #         inline = FALSE)),
                        #     style = "color:#3182bd;"),
                        width = 3
                    ),
                    mainPanel(
                        # fluidRow(
                        #     column(width = 9, tags$h4(textOutput("TITLE1"))),
                        #     column(width = 3,
                        #         downloadButton("PRINT1", "Print Graph"),
                        #         class='rightAlign')),
                        # hr(),
                        # plotOutput('KvQvER', height='300px')
                        plotOutput('KvQvER', height='auto')
                        # dygraphOutput("GRAPH1")
                    )
                )
            ),
            tabPanel(HTML('O<sub>2</sub> and Metabolism'),
                fluidRow(
                    column(9, align='left',
                        div(align='center', style=paste0(
                                'display: inline-block;',
                                'vertical-align:middle;',
                                'margin-right:2em'),
                            p(strong('Select DOY range:')),
                            p('Drag blue bar to move fixed range',
                                style=paste0(
                                    'color:gray; font-size:80%;',
                                    'padding:0; margin:0')),
                            p('Press play to autoscroll',
                                style='color:gray; font-size:80%')
                        ),
                        div(align='left', style=paste0(
                                'display: inline-block;',
                                'vertical-align:middle;'),
                            sliderInput("range", label=NULL,
                                min=1, max=366, value=c(1, 366),
                                ticks=TRUE, step=6,
                                animate=animationOptions(interval=2000)
                            )
                        )
                    ),
                    column(3, align='right',
                        div(align='right', style=paste0(
                            # 'display: inline-block;',
                            'vertical-align:bottom;'),
                            plotOutput('cumul_legend', height='60px')
                        )
                    )
                ),
                fluidRow(
                    column(9, align='center',
                        # plotOutput('metab_plot', height='200px'),
                        plotOutput('metab_plot', height='auto', width='auto'),
                        plotOutput('O2_plot', brush='O2_brush',
                        #     # height='200px')),
                            height='auto', width='auto')
                    ),
                # ),
                # fluidRow(
                    column(3, align='center',
                        plotOutput('cumul_plot', height='auto', width='auto'),
                        # plotOutput('cumul_plot', height='200px'),
                        plotOutput('kernel_plot', height='auto', width='auto')
                        # plotOutput('kernel_plot', height='200px'))),
                    )
                )
            )
        )
    )
)

#
#           tabPanel("Multiple Solutes", # Multiple Solutes (Panel 2) ####
#           sidebarLayout(
#           # Sidebar with tabs for Solute, Sites, Options
#             sidebarPanel(
#                        selectInput(
#                           "WATERYEAR2",
#                           label = "Water Year",
#                           choices = wateryears,
#                           selected = 2014),
#                        selectInput("SITES2",
#                                    label = "Site",
#                                    choices = c(sites_streams, sites_precip),
#                                    selected = "W1"),
#                        p(strong(checkboxInput("HYDROLOGY2",
#                                      label = "Hydrology",
#                                      value = FALSE))),
#                        conditionalPanel(
#                           # this panel only appears when discharge/precipitation button is clicked
#                           condition = "input.HYDROLOGY2 == true",
#                           p(radioButtons("GAGEHT_or_Q2",
#                                          "Select data source:",
#                                          choices = c("Gage Height (mm)" = "GageHt",
#                                                      "Q (L/s)" = "Q"),
#                                          selected = "GageHt",
#                                          inline = FALSE)),
#                           style = "color:#3182bd;"),
#                        p("Hydrology shows discharge for watershed sites, and precipitation for rain gage sites." ,
#                          style = "color:#666666; font-size:85%;"),
#                        checkboxGroupInput("SOLUTES2",
#                                           label = "Solutes",
#                                           choices = c(solutes_cations, solutes_anions, solutes_other),
#                                           selected = "Ca"),
#                        width = 3
#             ), # closes sidebarPanel
#
#             # Plot
#             mainPanel(
#
#               tags$h4(textOutput("TITLE2")),
#               hr(),
#               dygraphOutput("GRAPH2"),
#               #plotOutput("GRAPH")
#
#               hr(),
#
#               h4("Table of Selected Data"),
#               HTML("<p>Search bar finds specific values within selected data (e.g. '2014-06', '5.'). <br> Arrows (to the right of column names) sort data in ascending or descending order.</p>"),
#
#               # used when testing data sorting, but requested to keep
#               dataTableOutput("TABLE2")
#
#             ) # closes mainPanel
#
#           ) # closes sidebarLayout
#         ),# END of Panel 2 tabPanel
#
#           tabPanel("Multiple Sites", # Multiple Sites (Panel 3) ####
#                  sidebarLayout(
#                     # Sidebar with tabs for Solute, Sites, Options
#                     sidebarPanel(
#                        selectInput(
#                           "WATERYEAR3",
#                           label = "Water Year",
#                           choices = wateryears,
#                           selected = 2014),
#                        selectInput("SOLUTES3",
#                                    label = "Solute",
#                                    choices = c(solutes_cations, solutes_anions, solutes_other),
#                                    selected = "Ca"),
#                        helpText(textOutput("LIMITS3"), style = "color:#fc9272; font-size:85%;"),
#                        radioButtons("HYDROLOGY3",
#                                      label = "Hydrology (median):",
#                                      choices = c("Discharge", "Precipitation", "None"),
#                                      selected = "None"),
#                        conditionalPanel(
#                          # this panel only appears when discharge/precipitation button is clicked
#                          condition = "input.HYDROLOGY3 == 'Discharge' || input.HYDROLOGY3 == 'Precipitation'",
#                          p(radioButtons("GAGEHT_or_Q3",
#                                         "Select hydrology data source:",
#                                         choices = c("Gage Height (mm)" = "GageHt",
#                                                     "Q (L/s)" = "Q"),
#                                         selected = "GageHt",
#                                         inline = FALSE)), style = "color:#3182bd;"),
#                        p("Discharge shows daily median of all watershed sites." ,
#                          style = "color:#666666; font-size:85%;"),
#                        p("Precipitation shows daily median of all rain gage sites." ,
#                          style = "color:#666666; font-size:85%;"),
#                        checkboxGroupInput("SITES3",
#                                           label = "Sites",
#                                           choices = c(sites_streams, sites_precip),
#                                           selected = "W1"),
#                        width = 3
#                     ), # closes sidebarPanel
#
#                     # Plot
#                     mainPanel(
#
#                        tags$h4(textOutput("TITLE3")),
#                        hr(),
#                        dygraphOutput("GRAPH3"),
#                        #plotOutput("GRAPH")
#
#                        hr(),
#
#                        h4("Table of Selected Data"),
#                        HTML("<p>Search bar finds specific values within selected data (e.g. '2014-06', '5.'). <br> Arrows (to the right of column names) sort data in ascending or descending order.</p>"),
#
#                        # used when testing data sorting
#                        dataTableOutput("TABLE3")
#                        #textOutput("TEST3.TEXT")
#
#                     ) # closes mainPanel
#
#                   ) # closes sidebarLayout
#
#                 ), # END of Panel 3 tabPanel
#
#            tabPanel("Free-for-all", # Free-for-all (Panel 4) ####
#                     sidebarLayout(
#                        # Sidebar with tabs for Solute, Sites, Options
#                        sidebarPanel(
#                           sliderInput("DATE4", label = h4("Date Range"),
#                                       min = as.Date("1962-01-01"),
#                                       max = as.Date("2014-01-01"),
#                                       value = c(as.Date("1962-01-01"), as.Date("2014-01-01")), timeFormat = "%b %Y"),
#                           selectInput("SOLUTES4",
#                                       label = "Solute",
#                                       choices = c(solutes_cations, solutes_anions, solutes_other),
#                                       selected = "Ca"),
#                           helpText(textOutput("LIMITS4"), style = "color:#fc9272; font-size:85%;"),
#                           radioButtons("HYDROLOGY4",
#                                        label = "Hydrology (median):",
#                                        choices = c("Discharge", "Precipitation", "None"),
#                                        selected = "None"),
#                           conditionalPanel(
#                              # this panel only appears when discharge/precipitation button is clicked
#                              condition = "input.HYDROLOGY4 == 'Discharge' || input.HYDROLOGY4 == 'Precipitation'",
#                              p(radioButtons("GAGEHT_or_Q4",
#                                             "Select hydrology data source:",
#                                             choices = c("Gage Height (mm)" = "GageHt",
#                                                         "Q (L/s)" = "Q"),
#                                             selected = "GageHt",
#                                             inline = FALSE)), style = "color:#3182bd;"),
#                           p("Discharge shows daily median of all watershed sites." ,
#                             style = "color:#666666; font-size:85%;"),
#                           p("Precipitation shows daily median of all rain gage sites." ,
#                             style = "color:#666666; font-size:85%;"),
#                           checkboxGroupInput("SITES4",
#                                              label = "Sites",
#                                              choices = c(sites_streams, sites_precip),
#                                              selected = "W1"),
#                           checkboxInput("FIELDCODE4",
#                                         label = "Show field codes",
#                                         value = FALSE),
#                           checkboxInput("HYDROLIMB4",
#                                         label = "Hydrograph limb",
#                                         value = FALSE),
#                           width = 3
#                        ), # closes sidebarPanel
#
#                        # Plot
#                        mainPanel(
#
#                           tags$h4(textOutput("TITLE4")),
#                           hr(),
#                           dygraphOutput("GRAPH4"),
#                           #plotOutput("GRAPH")
#
#                           hr(),
#
#                           h4("Table of Selected Data"),
#                           HTML("<p>Search bar finds specific values within selected data (e.g. '2014-06', '5.'). <br> Arrows (to the right of column names) sort data in ascending or descending order.</p>"),
#
#                           # used when testing data sorting
#                           dataTableOutput("TABLE4")
#                           #textOutput("TEST4.TEXT")
#
#                        ) # closes mainPanel
#
#                      ) # closes sidebarLayout
#                     ), # Closes Panel 4 tabPanel
#
#            tabPanel("Summary Table", # Data Table (Panel 5) ####
#                     rHandsontableOutput("HOT5") # HOT = HandsOnTable
#                     )
#
#           ),# END of QA/QC navbarMenu
#
#         # DATA TABLE tab #########################################
#
#
#         # DATA DOWNLOAD tab #########################################
#         tabPanel("Data Download"),
#
#         # DATA DOWNLOAD tab #########################################
#         tabPanel("Approve Data")
#
#       ) # END of navbarPage()
#
#    ) # closes fluidPage()
# ) # closes shinyUI()
#
