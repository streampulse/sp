
#load plot functions
source("helpers.R")

get_plotheight = "
shinyjs.init = function() {
    $(window).resize(shinyjs.getHeight50);
}
shinyjs.getHeight90 = function() {
    Shiny.onInputChange('height90', $(window).height() * .9);
}
shinyjs.getHeight50 = function() {
    Shiny.onInputChange('height50', $(window).height() * .5);
}
shinyjs.getHeight10 = function() {
    Shiny.onInputChange('height10', $(window).height() * .1);
}
"

shinyUI(
    fluidPage(

        #screen shouldn't go gray when plots are updating.
        tags$style(type="text/css", ".recalculating { opacity: 1.0; }" ),
        shinyjs::useShinyjs(),
        shinyjs::extendShinyjs(text=get_plotheight,
            functions=c('getHeight90', 'getHeight10', 'getHeight50', 'init')),
        navbarPage(title=p(strong(a('StreamPULSE',
            href='https://data.streampulse.org/'))), inverse=TRUE,
            windowTitle='Compiled results',
            tabPanel('User Authentication',
                h2('Visualize compiled model results'),
                h3('User authentication'),
                p(paste('Use this tool to visualize cumulative results of models fit by StreamPULSE',
                    'users, as well as results from the Powell Center metabolism synthesis.',
                    'Additional visualizations are coming soon.')),
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
            tabPanel('Overall GPP vs. ER (kernel density)',
                sidebarLayout(
                    sidebarPanel(
                        selectInput('input_site', label='Select site(s) to overlay',
                            choices=list('StreamPULSE sites'=sitenames,
                                'Powell Center sites'=sitenm_all_pow),
                            selectize=TRUE, multiple=TRUE),
                        fluidRow(
                            column(6,
                                actionButton('replot', label='Render', width='100%')
                            ),
                            column(6,
                                actionButton('clear', label='Reset', width='100%')
                            )
                        ),
                        hr(),
                        sliderInput('slider', label='Select DOY range',
                            min=1, max=366, value=c(1, 366), step=6,
                            animate=animationOptions(interval=2000))
                    ),
                    mainPanel(
                        fluidRow(
                            plotOutput('kdens_legend', height='auto'),
                            plotOutput('kdens', height='auto')
                        )
                    )
                )
            )
        )
    )
)
