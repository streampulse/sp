
library(stringr)

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
shinyjs.getHeight35 = function() {
  Shiny.onInputChange('height35', $(window).height() * .35);
}
shinyjs.getHeight10 = function() {
  Shiny.onInputChange('height10', $(window).height() * .1);
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
                        selectInput('input_site', label='Select site',
                            choices=c('No site selected' = '',
                                unique(sitenames)),
                            selected='', selectize=TRUE),
                        conditionalPanel(
                            condition = "input.input_site != ''",
                            # htmlOutput('select_time')
                            selectInput('input_year', label='Select year',
                                choices=c('No year selected' = ''),
                                selected='', selectize=TRUE)
                        ),
                        # helpText(
                        #     textOutput("LIMITS1"),
                        #     style = "color:#fc9272; font-size:85%;"),
                        # hr(),
                        # p(strong("Additional Options:")),

                        # p(paste("Sample plots from streamMetabolizer model of",
                        #     "StreamPULSE's Black Earth",
                        #     "Creek site in Wisconsin. This app still under",
                        #     "development."), style='color:gray'),

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
                    column(12, align='left',
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
                        ),
                        div(align='center', style=paste0(
                                'display: inline-block;',
                                'vertical-align:middle;'),
                            selectInput('input_site2', label='Select site',
                                choices=c('No site selected' = '',
                                    unique(sitenames)),
                                selected='', selectize=TRUE, width='100%')
                        ),
                        div(align='center', style=paste0(
                                'display: inline-block;',
                                'vertical-align:middle;'),
                            conditionalPanel(
                                condition = "input.input_site != ''",
                                # htmlOutput('select_time')
                                selectInput('input_year2', label='Select year',
                                    choices=c('No year selected' = ''),
                                    selected='', selectize=TRUE, width='100%')
                            )
                        )
                    )
                    # column(3, align='right',
                    #     div(align='right', style=paste0(
                    #         # 'display: inline-block;',
                    #         'vertical-align:bottom;'),
                    #         plotOutput('cumul_legend', height='60px')
                    #     )
                    # )
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
                        plotOutput('cumul_legend', height='auto', width='auto'),
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
