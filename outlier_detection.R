#! /usr/bin/Rscript

#TODO: make this work with any sample interval

# df = commandArgs(trailingOnly=TRUE)
# print(head(df))


setwd('/home/mike/Dropbox/streampulse/data/NC_download/')
# site_files = dir()
# d_chili = read.csv(site_files[1], stringsAsFactors=FALSE,
#     colClasses=c('DateTime_UTC'='POSIXct'))
# sitevars = unique(d_chili$variable)
#
# v=1
# d = d_chili[d_chili$variable == sitevars[v],]

# df = read.csv('../test_outl.csv', stringsAsFactors=FALSE)
df = read.csv('../test_outl2.csv', stringsAsFactors=FALSE)



# seq_map = function(inds, x_advance=0, y_advance=0){
#     seq_list = mapply(function(x, y){ seq(x+x_advance, y+y_advance, 1) },
#         inds[,1], inds[,2],
#         SIMPLIFY=FALSE)
#     seq_vec = unlist(seq_list)
#
#     return(seq_vec)
# }

find_outliers = function(df){

    library(imputeTS)
    library(plotrix)
    library(accelerometry)

    df = subset(df, select=-c(DateTime_UTC)) #remove datetime col

    outlier_list = list()

    for(col in 1:ncol(df)){

        # print(colnames(df)[col])

        if(sum(is.na(df[,col])) / nrow(df) > 0.98){ #if almost all NA
            outlier_list[[col]] = 'NONE'
            print(paste(1, names(outlier_list), colnames(df)[col]))
            names(outlier_list)[col] = colnames(df)[col]
            next
        }

        tm = ts(df[,col], deltat = 1/96)
        tm = na.seadec(tm, algorithm='interpolation')

        #real stuff
        diffs = diff(tm)
        # x11()
        u = mean(diffs, na.rm=TRUE)
        sd = sd(diffs, na.rm=TRUE)

        sd_scaler = 1.8
        big_jump_prop = Inf
        while(big_jump_prop > 0.03){
            sd_scaler = sd_scaler + 0.2
            big_jump_prop = sum(diffs > sd_scaler * sd) / length(diffs)
        }

        pos_jumps = which(diffs > sd_scaler * sd)
        neg_jumps = which(diffs < -sd_scaler * sd)

        jump_inds = sort(c(pos_jumps, neg_jumps))

        runs = rle2(as.numeric(jump_inds %in% pos_jumps), indices=TRUE)
        lr = runs[,'lengths'] > 3
        long_runs = runs[lr, 2:3, drop=FALSE]

        keep = numeric()
        if(length(long_runs)){
            for(i in 1:nrow(long_runs)){
                r = long_runs[i,]
                j = jump_inds[unique(c(r[1], r[1] + 1, r[2] - 1, r[2]))]
                if(abs(j[2]-j[1]) < 8 & abs(j[length(j)]-j[length(j)-1]) < 9) next
                t = time(tm)[j + 1] #+1 to convert from diff indices to original ts indices
                left_jump_interv = t[2] - t[1]
                right_jump_interv = t[length(t)] - t[length(t)-1]
                not_outlier = which.min(c(left_jump_interv, right_jump_interv))
                keep = append(keep, r[-not_outlier])
            }
        }

        posNeg_jump_pairs = sort(unique(c(keep, as.vector(runs[!lr,2:3]))))
        outlier_inds = jump_inds[posNeg_jump_pairs]

        n_outlier_pieces = Inf
        counter = 0
        if(length(outlier_inds) == 1){
            outlier_ts = 'NONE'
        } else {
            while(length(outlier_inds) > 1 & n_outlier_pieces > 50 & counter < 5){
                outdif = diff(outlier_inds)
                rm_multjump = rm_oneway = NULL

                short_jumps = outdif < 15
                if(!short_jumps[1]){
                    outlier_inds = outlier_inds[-1]
                    counter = counter + 1
                    next
                }

                jump_runs = rle2(as.numeric(short_jumps), indices=TRUE,
                    return.list=FALSE)
                multijumps = jump_runs[jump_runs[,'lengths'] > 1, 2:3, drop=FALSE]
                if(length(multijumps)){
                    multijumps = multijumps[short_jumps[multijumps[,'starts']], ,
                        drop=FALSE]
                    seq_list = mapply(function(x, y){ seq(x, y+1, 1) },
                        multijumps[,1], multijumps[,2],
                        SIMPLIFY=FALSE)
                    rm_multjump = unlist(seq_list)
                    # rm_multjump = seq_map(multijumps, y_advance=1)
                }

                big_outdif = outdif > 15
                if(big_outdif[length(big_outdif)]){
                    outlier_inds = outlier_inds[-length(outlier_inds)]
                    counter = counter + 1
                    next
                }

                if(all(big_outdif)){
                    outlier_ts = 'NONE'
                    break
                } else {
                    same_sign_runs = rle2(as.numeric(big_outdif), indices=TRUE,
                        return.list=TRUE)

                    if(length(same_sign_runs)){
                        l = same_sign_runs$lengths
                        one_way_jumps = numeric()
                        for(i in 1:length(l)){
                            if(l[i] > 1){
                                s = same_sign_runs$starts[i]
                                one_way_jumps = append(one_way_jumps,
                                    seq(s, s + (l[i] - 2), 1))
                            }
                        }
                    }

                    if(length(one_way_jumps)){
                        one_way_jumps = one_way_jumps[big_outdif[one_way_jumps]]
                        outdif_filt = outdif
                        outdif_filt[-one_way_jumps] = 0
                        rm_oneway = which(outdif_filt > 0) + 1
                    }
                }
                removals = unique(c(rm_multjump, rm_oneway))
                if(!is.null(removals)){
                    outlier_inds = outlier_inds[-removals]
                }

                if(length(outlier_inds) %% 2 == 0){
                    outlier_inds = matrix(outlier_inds, ncol=2, byrow=TRUE)
                    seq_list = mapply(function(x, y){ seq(x+1, y, 1) },
                        outlier_inds[,1], outlier_inds[,2],
                        SIMPLIFY=FALSE)
                    outlier_ts = unlist(seq_list)
                    # outlier_ts = seq_map(outlier_inds, x_advance=1)
                } else {
                    smallest_diff = which.min(abs(diffs[outlier_inds]))
                    outlier_inds = outlier_inds[-smallest_diff]
                    counter = counter + 1
                    next
                }
                n_outlier_pieces = length(outlier_ts)
                counter = counter + 1
            }
        }
        if(n_outlier_pieces > 50 | is.null(outlier_ts)){
            outlier_ts = 'NONE'
            print('argh2')
        }
        # print(paste('sd_scaler =', sd_scaler))
        # print(paste('big_jump_prop =', big_jump_prop))

        outlier_list[[col]] = outlier_ts
        print(paste(2, names(outlier_list), colnames(df)[col]))
        names(outlier_list)[col] = colnames(df)[col]
    }

    return(outlier_list)
}

find_outliers(df)
