
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
            windowTitle='StreamPULSE Diagnostics',
            tabPanel('User Authentication',
                p(paste('Use this tool to visualize models fit by StreamPULSE',
                    'users. The best available model fits and metabolism',
                    'estimates for each site and calendar year are stored here.')),
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
            tabPanel('Metabolism by region',
                sidebarLayout(
                    sidebarPanel(
                        # selectizeInput('input_site', label='Overlay site(s)',
                        #     choices=c('None', unique(sitenames)),
                        #     selected='None', multiple=TRUE,
                        #     options=list('allowEmptyOption'=TRUE))
                        selectInput('input_site', label='Overlay site(s)',
                            choices=list('StreamPULSE sites'=sitenames,
                                'Powell Center sites'=sitenm_all_pow),
                            selectize=TRUE, multiple=TRUE),
                        actionButton('replot', label='Replot'),
                        actionButton('clear', label='Clear overlay')
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
