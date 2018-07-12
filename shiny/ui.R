

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
shinyjs.getHeight05 = function() {
  Shiny.onInputChange('height05', $(window).height() * .05);
}
"

shinyUI(
    fluidPage(

        #screen shouldn't go gray when plots are updating.
        tags$style(type="text/css", ".recalculating { opacity: 1.0; }" ),
        # tags$style(type='text/css', ".selectize-input:nth-child(3) { padding: 0px; min-height: 0;}"),
        shinyjs::useShinyjs(),
        shinyjs::extendShinyjs(text=get_plotheight,
            functions=c('getHeight50', 'getHeight40', 'getHeight35',
                'getHeight10', 'getHeight10', 'getHeight05', 'init')),
        # navbarPage(title=tags$a(href='https://data.streampulse.org/',
        #     'StreamPULSE'),
        #     tabPanel(HTML("<a href=\"https://data.streampulse.org/sitelist\">Sitelist</a>"))
        #     # tabPanel(tags$a(href='https://data.streampulse.org/upload_choice/',
        #     # 'Upload'))
        # ),
        navbarPage(title=p(strong('Diagnostics')), inverse=TRUE,
            tabPanel('User Authentication',
                p(paste('Use this tool to visualize models fit by StreamPULSE',
                    'users. The best available model fits and metabolism',
                    'estimates for each site and calendar year are stored here.')),
                p('To view private results, enter a valid user token.'),
                br(),
                div(style='display: inline-block; vertical-align:top',
                    textInput('token_input', label=NULL, value='',
                        placeholder='Enter token here', width='300px')
                ),
                div(style='display: inline-block; vertical-align:top',
                    actionButton('submit_token', 'Submit')
                ),
                br(),
                div(style='width:300px',
                    conditionalPanel(condition=paste0("input.token_input != ''",
                        " && input.submit_token > 0 && input.hidden_bool == 'T'"),
                        verbatimTextOutput('token_resp')
                    )
                ),
                span('If you do not have your token, email Mike at ',
                    a('streampuse.info@gmail.com',
                        href='mailto:streampulse.info@gmail.com'), '.'),
                div(style='display:none;',
                    textInput('hidden_bool', label=NULL, value='F')
                )
            ),
            tabPanel('Model Performance',
                sidebarLayout(
                    sidebarPanel(
                        selectInput('input_site', label='Select site',
                            choices=c('No site selected' = '',
                                unique(sitenames)),
                            selected='', selectize=TRUE),
                        conditionalPanel(condition="input.input_site != ''",
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
                                'display:none;'),
                            textInput('hidden_counter', label=NULL, value=0),
                            textInput('hidden_counter2', label=NULL, value=0)
                        ),
                        div(align='center', style=paste0(
                                'display: inline-block;',
                                'vertical-align:middle;'),

                            # div(align='left', style=paste0(
                            #     'margin:0; padding:0; top:0px; left:0px; bottom:0px; right:0px;'),

                            selectInput('input_site2', label='Select site',
                                choices=c('No site selected' = '',
                                    unique(sitenames)),
                                selected='', selectize=TRUE, width='170px')
                        ),
                            # div(align='left', style=paste0(
                            #     'margin:0; padding:0; top:0px; left:0px; bottom:0px; right:0px;'),

                        div(align='center', style=paste0(
                                'display: inline-block;',
                                'vertical-align:middle;',
                                'margin-right:2em'),
                            conditionalPanel(condition="input.input_site2 != ''",
                                # htmlOutput('select_time')
                                selectInput('input_year2', label='Select year',
                                    choices=c('No year selected' = ''),
                                    selectize=TRUE, width='100px')
                            )
                        ),
                        div(align='center', style=paste0(
                                'display: inline-block;',
                                'vertical-align:middle;',
                                'margin-right:1em'),
                            conditionalPanel(condition="input.input_site2 != ''",
                                div(align='center', style=paste0(
                                        'display: inline-block;',
                                        'vertical-align:middle;',
                                        'margin-right:1em'),
                                    p(strong('Select DOY range:')),
                                    p('Drag blue bar to move fixed range',
                                        style=paste0(
                                            'color:gray; font-size:80%;',
                                            'padding:0; margin:0')),
                                    p('Press play to autoscroll*',
                                        style='color:gray; font-size:80%')
                                ),
                                div(align='left', style=paste0(
                                        'display: inline-block;',
                                        'vertical-align:middle;'),
                                        # 'margin-right:2em'),
                                    htmlOutput('time_slider')
                                    # sliderInput("range", label=NULL,
                                    #     min=1, max=366, value=c(1, 366),
                                    #     ticks=TRUE, step=6,
                                    #     animate=animationOptions(interval=2000)
                                    # )
                                )
                            )
                        ),
                        hr()
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
                        conditionalPanel(condition="input.input_site2 != ''",
                            plotOutput('metab_legend', height='auto',
                                width='auto')
                        ),
                        # plotOutput('metab_plot', height='200px'),
                        plotOutput('metab_plot', height='auto', width='auto'),
                        # hr(),
                        conditionalPanel(condition="input.input_site2 != ''",
                            plotOutput('O2_legend', height='auto',
                                width='auto')
                        ),
                        plotOutput('O2_plot', brush='O2_brush',
                        #     # height='200px')),
                            height='auto', width='auto')
                    ),
                # ),
                # fluidRow(
                    column(3, align='center',
                        conditionalPanel(condition="input.input_site2 != ''",
                            plotOutput('cumul_legend', height='auto',
                                width='auto')
                        ),
                        plotOutput('cumul_plot', height='auto', width='auto'),
                        # hr(),
                        # plotOutput('cumul_plot', height='200px'),
                        conditionalPanel(condition="input.input_site2 != ''",
                            plotOutput('kernel_legend', height='auto',
                                width='auto')
                        ),
                        plotOutput('kernel_plot', height='auto', width='auto')
                        # plotOutput('kernel_plot', height='200px'))),
                    )
                ),
                br(),
                conditionalPanel(condition="input.input_site2 != ''",
                    p(paste("*If something doesn't look right, try",
                        "adjusting your browser's zoom level."),
                        style='color:gray; font-size:100%')
                )
            )
        )
    )
)
