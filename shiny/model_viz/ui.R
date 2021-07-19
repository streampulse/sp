

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
        navbarPage(title=p(strong(a('StreamPULSE',
            href='https://data.streampulse.org/'))), inverse=TRUE,
            windowTitle='StreamPULSE Diagnostics',
            tabPanel('User Authentication',
                h2('Visualize individual model results'),
                h3('User authentication'),
                p(paste('Use this tool to visualize individual models fit by StreamPULSE',
                    'users. The best available model fits and metabolism',
                    'estimates for each site and calendar year are stored here.',
                    'You can also use this tool to explore model results from',
                    'the Powell Center metabolism synthesis and the NWQP Regional Stream Quality Assessments.')),
                p('To view private results, enter a valid user token. You do',
                    'not need a token to view public results.'),
                br(),
                div(style='display: inline-block; vertical-align:top',
                    textInput('token_input', label=NULL, value='',
                        placeholder='Enter token here', width='350px')
                ),
                div(style='display: inline-block; vertical-align:top',
                    actionButton('submit_token', 'Submit')
                ),
                br(),
                div(style='width:350px',
                    conditionalPanel(condition=paste0("input.token_input != ''",
                        " && input.submit_token > 0"),
                        verbatimTextOutput('token_resp')
                    )
                ),
                span('Find your token on your ', a('user account page',
                        href='https://data.streampulse.org/account'), '.')
            ),
            tabPanel('Model Performance',
                sidebarLayout(
                    sidebarPanel(
                        div(style=paste0(style='display:none;'),
                            textInput('MPhidden_counter', label=NULL, value=0),
                            textInput('MPhidden_counter2', label=NULL, value=0)
                            # textInput('MPhidden_counter3', label=NULL, value=0)
                        ),
                        radioButtons('datasourceMP', 'Choose data source',
                            list('StreamPULSE', 'Powell Center Synthesis', 'NWQP'),
                            selected='StreamPULSE'),
                        selectInput('MPinput_site', label='Select site',
                            choices=c('No site selected' = '',
                                unique(sitenames)),
                            selected='', selectize=TRUE),
                        conditionalPanel(condition="input.MPinput_site != ''",
                            # htmlOutput('select_time')
                            selectInput('MPinput_year', label='Select year',
                                choices=c('No year selected' = ''),
                                selected='', selectize=TRUE)
                        ),
                        conditionalPanel(condition="input.MPinput_site != ''",
                            p(strong('Select DOY range:')),
                            p('Drag blue bar to move fixed range',
                                style=paste0('color:gray; font-size:80%;',
                                    'padding:0; margin:0')),
                            p('Press play to autoscroll*',
                                style='color:gray; font-size:80%'),
                            htmlOutput('MPtime_slider')
                        ),
                        p('Click any point to view its date (a bit finicky at the moment).',
                            style=paste0('color:gray; font-size:80%;')),
                        conditionalPanel(condition="input.MPinput_site != ''",
                            p(paste('*Residuals based on linear relationship',
                                'between daily mean K600 and log daily mean Q.'),
                                style=paste0('color:gray; font-size:80%;'))
                        ),
                        width = 3
                    ),
                    mainPanel(
                        fluidRow(
                            column(6, align='left',
                                plotOutput('KvER', height='auto',
                                    click='KvER_click'),
                                plotOutput('KvGPP', height='auto',
                                    click='KvGPP_click')
                            ),
                            column(6, align='left',
                                plotOutput('KvQ', height='auto',
                                    click='KvQ_click'),
                                plotOutput('QvKres', height='auto',
                                    click='QvKres_click')
                            )
                        )
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

                            radioButtons('datasource', 'Choose data source',
                                list('StreamPULSE', 'Powell Center Synthesis', 'NWQP'),
                                selected='StreamPULSE')
                        ),
                        div(align='center', style=paste0(
                                'display: inline-block;',
                                'vertical-align:middle;'),

                            # div(align='left', style=paste0(
                            #     'margin:0; padding:0; top:0px; left:0px; bottom:0px; right:0px;'),
                            selectInput('input_site', label='Select site',
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
                            conditionalPanel(condition="input.input_site != ''",
                                # htmlOutput('select_time')
                                selectInput('input_year', label='Select year',
                                    choices=c('No year selected' = ''),
                                    selectize=TRUE, width='100px')
                            )
                        ),
                        div(align='center', style=paste0(
                                'display: inline-block;',
                                'vertical-align:middle;',
                                'margin-right:1em'),
                            conditionalPanel(condition="input.input_site != ''",
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
                ),
                fluidRow(
                    column(9, align='center',
                        conditionalPanel(condition="input.input_site != ''",
                            plotOutput('metab_legend', height='auto',
                                width='auto')
                        ),
                        plotOutput('metab_plot', height='auto', width='auto'),
                        conditionalPanel(condition="input.input_site != ''",
                            plotOutput('O2_legend', height='auto', width='auto')
                        ),
                        plotOutput('O2_plot', brush='O2_brush',
                            height='auto', width='auto')
                    ),
                    column(3, align='center',
                        conditionalPanel(condition="input.input_site != ''",
                            p(strong(HTML('Cumulative O<sub>2</sub> (gm<sup>-2</sup>d<sup>-1</sup>)'))),
                            tableOutput('cumul_metab'),
                            br()
                        ),
                        conditionalPanel(condition="input.input_site != ''",
                            plotOutput('kernel_legend', height='auto',
                                width='auto')
                        ),
                        plotOutput('kernel_plot', height='auto', width='auto'),
                        conditionalPanel(condition="input.input_site != ''",
                            # plotOutput('cumul_legend', height='auto',
                            #     width='auto')
                            # plotOutput('cumul_plot', height='auto', width='auto'),
                            br(),
                            selectInput('metab_overlay', 'Model param overlay',
                                list('None', 'mean daily K600'), selected='None'),
                            selectInput('O2_overlay', 'Input data overlay',
                                list('None'), selected='None'),
                            radioButtons('xformat', 'Series x-axis', inline=TRUE,
                                list('DOY', 'Date'), selected='DOY')
                        )
                    )
                ),
                br(),
                conditionalPanel(condition="input.input_site != ''",
                    p(paste("*Plots may take a few moments to load.",
                        "If something doesn't look right, try",
                        "adjusting your browser's zoom level."),
                        style='color:gray; font-size:100%')
                )
            )
        )
    )
)
