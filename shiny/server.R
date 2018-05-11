# fit = readRDS(paste0('~/git/streampulse/server_copy/sp/shiny/data/',
#     'fit_WI_BEC_2017-01-26_2018-01-25_bayes_binned_obsproc_trapezoid_',
#     'DO-mod_stan.rds'))
# data_daily = fit@data_daily
# data = fit@data
# fit = fit@fit
# mod_out = list('data_daily'=data_daily, 'data'=data, 'fit'=fit)
# saveRDS(mod_out, paste0('~/git/streampulse/server_copy/sp/shiny/data/',
#     'modOut_WI_BEC_2017-01-26_2018-01-25_bayes_binned_obsproc_trapezoid_',
#     'DO-mod_stan.rds'))

mod_out = readRDS(paste0('~/git/streampulse/server_copy/sp/shiny/data/',
    'modOut_WI_BEC_2017-01-26_2018-01-25_bayes_binned_obsproc_trapezoid_',
    'DO-mod_stan.rds'))
predictions = readRDS(paste0('~/git/streampulse/server_copy/sp/shiny/data/',
    'predictions_WI_BEC_2017-01-26_2018-01-25_bayes_binned_obsproc_trapezoid_',
    'DO-mod_stan.rds'))

library(dplyr)
library(dygraphs)
library(ggplot2)
library(shiny)
library(Cairo)
library(ks)
library(RColorBrewer)
options(shiny.usecairo=TRUE)

shinyServer(
    function(input, output) {

        # buildDy = function(i){
        #     dygraph(ts$data, group = "powstreams",
        #         periodicity=list(scale='minute',label='minute')) %>%
        #     dyOptions(colors = brewer.pal(max(3,length(names(ts$data))),
        #         "Dark2")) %>%
        #     dyHighlight(highlightSeriesBackgroundAlpha = 0.65,
        #         hideOnMouseOut = TRUE) %>%
        #     dyAxis("y", label = ts$ylab) %>%
        #     dyOptions(labelsUTC = TRUE) %>%
        #     dyRangeSelector(., fillColor='', strokeColor='', height=20)
        # }

        # dy1 <- eventReactive(input$render, {
        #     buildDy(1)
        # })
        # output$GRAPH1 = renderDygraph({
          # ylabel = paste(ylabel1())
          # dygraph1()
        # })
        output$KvQvER = renderPlot({
            par(mfrow=c(1,2))
            mod = lm(mod_out$fit$daily$ER_mean ~
                mod_out$fit$daily$K600_daily_mean)
            R2 = sprintf('%1.2f', summary(mod)$adj.r.squared)
            plot(mod_out$fit$daily$K600_daily_mean, mod_out$fit$daily$ER_mean,
                col='darkgreen', ylab='Daily mean ER', xlab='Daily mean K600',
                bty='l', font.lab=2, cex.axis=0.8, las=1)
            mtext(bquote('Adj.' ~ R^2 * ':' ~ .(R2)), side=3, line=0, adj=1,
                cex=0.8, col='gray50')
            abline(mod, lty=2, col='gray50', lwd=2)
            plot(mod_out$fit$daily$K600_daily_mean,
                mod_out$data_daily$discharge.daily,
                col='purple4', ylab='Daily mean Q', xlab='Daily mean K600',
                bty='l', font.lab=2, cex.axis=0.8, las=1)
        })

        output$O2 = renderPlot({
            st = 4800; en = 5800
            dt = as.Date(mod_out$data$date[st:en])
            DOY = gsub('^0+', '', strftime(dt, format="%j"))
            DOY_ind = match(unique(DOY)[seq(1, length(unique(DOY)), 2)], DOY)
            plot.ts(mod_out$data$DO.obs, xlim=c(st,en), xaxt='n', las=1,
                xlab='', ylab='', ylim=c(8,14), lwd=3, col='gray70', bty='l')
            mtext('DOY', 1, font=2, line=2.5)
            mtext('DO (mg/L)', 2, font=2, line=2.5)
            lines(mod_out$data$DO.mod, xlim=c(st,en), col='darkred')
            axis(1, DOY_ind[-1] + st - 1, DOY[DOY_ind[-1]])
            legend(x=5450, y=15.8, xpd=TRUE, legend=c('Obs', 'Pred'), cex=0.8,
                col=c('gray70', 'darkred'), lty=1, bty='n', horiz=TRUE,
                lwd=c(3,1))
        })

        output$triplot = renderPlot({
            diag_plots(predictions[,c('date','GPP','ER')], 'Name Here')
        })
    })


