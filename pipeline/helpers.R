range_check = function(df, flagdf){

    ranges = list(
        'DO_mgL'=c(-0.5, 40),
        'DOSecondary_mgL'=c(0, 40),
        'satDO_mgL'=c(0, 30),
        'DOsat_pct'=c(0, 200),
        'WaterTemp_C'=c(-100, 100),
        'WaterTemp2_C'=c(-100, 100),
        'WaterTemp3_C'=c(-100, 100),
        'WaterPres_kPa'=c(0, 1000),
        'AirTemp_C'=c(-200, 100),
        'AirPres_kPa'=c(0, 110),
        'Level_m'=c(-10, 100),
        'Depth_m'=c(0, 100),
        'Discharge_m3s'=c(0, 250000),
        'Velocity_ms'=c(0, 10),
        'pH'=c(0, 14),
        'pH_mV'=c(-1000, 1000),
        'CDOM_ppb'=c(0, 10000),
        'CDOM_mV'=c(0, 10000),
        'FDOM_mV'=c(0, 10000),
        'Turbidity_NTU'=c(0, 500000),
        'Turbidity_mV'=c(0, 100000),
        'Turbidity_FNU'=c(0, 500000),
        'Nitrate_mgL'=c(0, 1000),
        'SpecCond_mScm'=c(0, 1000),
        'SpecCond_uScm'=c(0, 100000),
        'CO2_ppm'=c(0, 100000),
        'ChlorophyllA_ugL'=c(0, 1000),
        'Light_lux'=c(0, 1000000),
        'Light_PAR'=c(0, 100000),
        'Light2_lux'=c(0, 1000000),
        'Light2_PAR'=c(0, 100000),
        'Light3_lux'=c(0, 1000000),
        'Light3_PAR'=c(0, 100000),
        'Light4_lux'=c(0, 1000000),
        'Light4_PAR'=c(0, 100000),
        'Light5_lux'=c(0, 1000000),
        'Light5_PAR'=c(0, 100000),
        'underwater_lux'=c(0, 1000000),
        'underwater_PAR'=c(0, 100000),
        'benthic_lux'=c(0, 1000000),
        'benthic_PAR'=c(0, 100000),
        'Battery_V'=c(0, 1000))

    for(c in colnames(df)){
        if(all(is.na(df[[c]]))) next
        rmin = ranges[[c]][1]
        rmax = ranges[[c]][2]
        flagdf[[c]] = as.numeric(df[[c]] < rmin | df[[c]] > rmax)
    }

    return(list('df'=df, 'flagdf'=flagdf))
}

basic_outlier_detect = function(df, flagdf){

    diffs = as.data.frame(apply(df, 2, diff))

    diffs$dt = dtcol[-1]
    df$dt = dtcol

    for(c in colnames(diffs)){

        alpha = 0.01
        if(c %in% c('Level_m', 'Depth_m', 'Discharge_m3s')) alpha = 0.0001
        if(sum(is.na(diffs[, c])) / nrow(diffs) > 0.99) next

        #find extreme points
        anom_df = as_tibble(df) %>%
            time_decompose(c, method='twitter') %>%
            anomalize(remainder, max_anoms=0.01, alpha=alpha, method='gesd')
        outls1 = which(anom_df$anomaly == 'Yes')

        #find extreme jumps
        anom_df = as_tibble(diffs) %>%
            time_decompose(c, method='twitter') %>%
            anomalize(remainder, max_anoms=0.01, alpha=alpha, method='gesd')
        outls2 = which(anom_df$anomaly == 'Yes') + 1

        #find super extreme points
        anom_df = as_tibble(df) %>%
            time_decompose(c, method='twitter') %>%
            anomalize(remainder, max_anoms=0.001, alpha=alpha, method='gesd')
        outls3 = which(anom_df$anomaly == 'Yes')

        #outliers are overlap of extreme points+jumps, or just super extreme points
        outls = union(intersect(outls1, outls2), outls3)

        flagdf[outls, c] = flagdf[outls, c] + 2
    }

    return(list('df'=df, 'flagdf'=flagdf))
}
