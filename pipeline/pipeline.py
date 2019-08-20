import rrcf
import pandas as pd
# import simplejson as json
from helpers import email_msg
from sys import argv

# from fbprophet import Prophet
import numpy as np
# import seaborn as sns
# import logging
# logging.getLogger('fbprophet').setLevel(logging.ERROR)
# import warnings
# warnings.filterwarnings("ignore")
import matplotlib.pyplot as plt
import math
import copy

# import random
q = np.load('/home/mike/Downloads/telemanom_hmm/data/train/F-2.npy')
qq = pd.DataFrame(q)
qq.to_csv('/home/mike/temp/arse.csv')

script_name, notificationEmail, tmpcode, region, site = argv

# userID=35; tmpfile='e076b8930278'
# region='NC'; site='FF'; notificationEmail='vlahm13@gmail.com'
# dumpfile = '../spdumps/confirmcolumns' + tmpfile + '.json'
# # dumpfile = '/home/mike/git/streampulse/server_copy/spdumps/confirmcolumns35_AQ_WB_e076b8930278.json'
# with open(dumpfile) as d:
#     up_data = json.load(d)

origdf = pd.read_csv('~/Dropbox/streampulse/data/pipeline/1.csv',
    index_col='DateTime_UTC')
upids = origdf.pop('upload_id')


trainR = pd.read_csv('~/Downloads/telemanom/training_dev/train.csv',
    index_col='solar.time')
testR = pd.read_csv('~/Downloads/telemanom/training_dev/test.csv',
    index_col='solar.time')
trainR = trainR.reset_index().drop(['solar.time'], axis=1)
testR = testR.reset_index().drop(['solar.time'], axis=1)
# prenp.pop('pH')
# prenp.apply(lambda x: sum(x.isnull()), axis=0)
trainR.head()
for i in range(trainR.shape[1]):
    trainSer = trainR.iloc[:,i]#.interpolate(method='linear')
    testSer = testR.iloc[:,i]#.interpolate(method='linear')
    # if ser[0] == np.nan:
    #     ser[0] = ser[1]
    trainNpy = pd.concat([trainSer, pd.Series(np.repeat(0, trainR.shape[0]))], axis=1)
    testNpy = pd.concat([testSer, pd.Series(np.repeat(0, testR.shape[0]))], axis=1)
    # trn = npy.head(6000)
    # tst = npy.iloc[6001:10000,:].reset_index(drop=True)
    # trn = npy.head(16126)
    # tst = npy.tail(10750).reset_index(drop=True)
    np.save('/home/mike/Downloads/telemanom/data/train/' + str(i) + '.npy', trainNpy)
    np.save('/home/mike/Downloads/telemanom/data/test/' + str(i) + '.npy', testNpy)
# pd.DataFrame(np.load('/home/mike/temp/npys/1.npy'))

# newcols = x.columns[x.columns != 'DateTime_UTC'].tolist()
# newcols.insert(0, 'DateTime_UTC')
# x = x.reindex(newcols, axis='columns')

z = origdf.copy()
z.iloc[0, 2] = -50; z.iloc[400, 4] = 20

zz = origdf.head(100)#.copy()
zz.iloc[0, 2] = -50; zz.iloc[400, 4] = 15
z = zz.copy()
# df = z
26876 * .6
26876 - 16126
flagdf = z.applymap(lambda x: 0)
# flagdf = z.set_index('DateTime_UTC').applymap(lambda x: 0).reset_index()

def range_check(df, flagdf):

    ranges = {
        'DO_mgL': (0, 40),
        'DOSecondary_mgL': (0, 40),
        'satDO_mgL': (0, 30),
     	'DOsat_pct': (0, 200),
     	'WaterTemp_C': (-100, 100),
     	'WaterTemp2_C': (-100, 100),
     	'WaterTemp3_C': (-100, 100),
    	'WaterPres_kPa': (0, 1000),
     	'AirTemp_C': (-200, 100),
     	'AirPres_kPa': (0, 110),
     	'Level_m': (-10, 100),
     	'Depth_m': (0, 100),
    	'Discharge_m3s': (0, 250000),
     	'Velocity_ms': (0, 10),
     	'pH': (0, 14),
     	'pH_mV': (-1000, 1000),
     	'CDOM_ppb': (0, 10000),
     	'CDOM_mV': (0, 10000),
     	'FDOM_mV': (0, 10000),
    	'Turbidity_NTU': (0, 500000),
     	'Turbidity_mV': (0, 100000),
     	'Turbidity_FNU': (0, 500000),
     	'Nitrate_mgL': (0, 1000),
     	'SpecCond_mScm': (0, 1000),
    	'SpecCond_uScm': (0, 100000),
     	'CO2_ppm': (0, 100000),
     	'ChlorophyllA_ugL': (0, 1000),
     	'Light_lux': (0, 1000000),
     	'Light_PAR': (0, 100000),
     	'Light2_lux': (0, 1000000),
    	'Light2_PAR': (0, 100000),
     	'Light3_lux': (0, 1000000),
     	'Light3_PAR': (0, 100000),
     	'Light4_lux': (0, 1000000),
     	'Light4_PAR': (0, 100000),
    	'Light5_lux': (0, 1000000),
     	'Light5_PAR': (0, 100000),
     	'underwater_lux': (0, 1000000),
     	'underwater_PAR': (0, 100000),
     	'benthic_lux': (0, 1000000),
    	'benthic_PAR': (0, 100000),
        'Battery_V': (0, 1000)
    }

    cols = list(df.columns)
    for c in cols:
        rmin, rmax = ranges[c]
        not_outl = ( df[c].isnull() ) |\
            ( df[c].between(rmin, rmax, inclusive=True) )
        flagdf[c] = flagdf[c].where(not_outl, 1)
        df[c] = df[c].where(not_outl, np.nan)

    return (df, flagdf)

z2, flagdf = range_check(z, flagdf)


def anomaly_detect(df, flagdf):

    # df = z
    # Set tree parameters for robust random cut forest (rrcf)
    num_trees = 40#40
    shingle_size = 20
    tree_size = 256#256
    codisps = {}
    # i=1
    # pp = list(enumerate(points))
    # index, point = pp[17920]
    # tree=forest[0]
    # np.isnan(xseries)
    # xseries.interpolate(method='linear')
    # all(x.iloc[:,i].isnull())
    # z.iloc[1,3] = np.nan
    # z.pH.interpolate()

    for i in range(df.shape[1]):
        print('var' + str(i))
        varname = df.columns[i]

        xseries = df.iloc[:,i].interpolate(method='linear').to_numpy()

        if all(np.isnan(xseries)):
            continue
        if np.isnan(xseries[0]):
            xseries[0] = xseries[1]

        #create a forest of empty trees
        forest = []
        for _ in range(num_trees):
            tree = rrcf.RCTree()
            forest.append(tree)

        #create rolling window
        points = rrcf.shingle(xseries, size=shingle_size)

        avg_codisp = {}
        for index, point in enumerate(points):
            if index % 2000 == 0:
                # if index > 16000:
                print('point' + str(index))
            # if index == 17920:
            #     raise ValueError('a')
            for tree in forest:
                #drop the oldest point (FIFO) if tree is too big
                if len(tree.leaves) > tree_size:
                    tree.forget_point(index - tree_size)

                tree.insert_point(point, index=index)

                #compute collusive displacement on the inserted point
                new_codisp = tree.codisp(index)

                #take the average codisp across all trees; that's anomaly score
                if not index in avg_codisp:
                    avg_codisp[index] = 0
                avg_codisp[index] += new_codisp / num_trees

        codisps[varname] = avg_codisp

    # c='WaterTemp_C'
    for c in codisps.keys():
        avg_codisp = codisps[c]

        #get top 2% of anomaly scores; flag those points with +2
        avg_codisp_df = pd.DataFrame.from_dict(avg_codisp, orient='index',
            columns=['score'])
        thresh = float(avg_codisp_df.quantile(0.98))
        outl_inds_bool = avg_codisp_df.loc[:,'score'] > thresh
        outl_inds_int = outl_inds_bool[outl_inds_bool].index
        outl_vals = flagdf.loc[flagdf.index[outl_inds_int], c]
        flagdf.loc[flagdf.index[outl_inds_int], c] = outl_vals + 2

        df.loc[df.index[outl_inds_int], varname] = np.nan

        # outl_inds = avg_codisp_df[outl_inds_bool]
        # outl = pd.merge(outl_inds, pd.DataFrame(xseries, columns=['val']), how='left', left_index=True,
        #     right_index=True)

    return (df, flagdf)

import time
start_time = time.time()
z3, flagdf = anomaly_detect(z2, flagdf)
print(round((time.time() - start_time) / 60, 2))

flagdf.apply(sum, axis=0)

def plot_flags(origdf, df, flagdf):
    # df=z3; i=2
    nplots = df.shape[1]
    sqp = math.sqrt(nplots)
    nr = round(sqp)
    nc = math.ceil(sqp)
    # plt.subplots(nrows=2, ncols=3, sharex='col')

    #view series, anomaly scores, and outliers
    linecol = 'tab:gray'
    fig, ax = plt.subplots(nrows=nr, ncols=nc, figsize=(20, 10))
    ax = [p for sub in ax for p in sub]
    for i in range(df.shape[1]):
        varname = df.columns[i]
        varseries = origdf[varname]
        out_of_range = origdf.loc[flagdf.index[flagdf[varname] == 1], varname]
        outlier = origdf.loc[flagdf.index[flagdf[varname].isin([2, 3])], varname]

        ax[i].set_ylabel(varname, color=linecol, size=14)
        ax[i].plot(varseries, color=linecol)
        ax[i].scatter(out_of_range.index, out_of_range, color='red')
        ax[i].scatter(outlier.index, outlier, color='orange')
        # plt.title('Dissolved O2 (gray) and anomaly score (orange)', size=14)
        ax[i].tick_params(axis='y', labelcolor=linecol, labelsize=12)
        # ax[i].set_xticklabels([])
        # ax[i].xticks([])
        # ax[i].gca().axes.get_xaxis().set_visible(False)
        # cur_axes = ax[i].gca()
        # cur_axes.axes.get_xaxis().set_visible(False)
        ax[i].xaxis.set_visible(False)
        # ax[i].xticks(np.arange(min(x), max(x)+1, 1.0))

# import matplotlib
# matplotlib.use('TkAgg')
# matplotlib.use('GTKAgg')

# plot_flags(origdf, z3, flagdf) #full
plot_flags(zz, z3, flagdf) #subset


import matplotlib.backends.backend_pdf

df = z
num_trees = 40#40
shingle_size = 1
tree_size = 256#256

for i in range(len(df.columns)):
    varname = df.columns[i]

    xseries = df.iloc[:,i].interpolate(method='linear').to_numpy()

    if all(np.isnan(xseries)):
        continue
    if np.isnan(xseries[0]):
        xseries[0] = xseries[1]

    #create a forest of empty trees
    forest = []
    for _ in range(num_trees):
        tree = rrcf.RCTree()
        forest.append(tree)

    #create rolling window
    points = rrcf.shingle(xseries, size=shingle_size)

    avg_codisp = {}
    for index, point in enumerate(points):
        if index % 2000 == 0:
            # if index > 16000:
            print('point' + str(index))
        # if index == 17920:
        #     raise ValueError('a')
        for tree in forest:
            #drop the oldest point (FIFO) if tree is too big
            if len(tree.leaves) > tree_size:
                tree.forget_point(index - tree_size)

            tree.insert_point(point, index=index)

            #compute collusive displacement on the inserted point
            new_codisp = tree.codisp(index)

            #take the average codisp across all trees; that's anomaly score
            if not index in avg_codisp:
                avg_codisp[index] = 0
            avg_codisp[index] += new_codisp / num_trees








    # #extras
    # nplots = z3.shape[1]
    # sqp = math.sqrt(nplots)
    # nr = round(sqp)
    # nc = math.ceil(sqp)
    # xseries = z3.iloc[:,5].interpolate(method='linear').to_numpy()
    fig, ax1 = plt.subplots(nrows=1, ncols=1, figsize=(20, 10))
    color = 'tab:gray'
    ax1.set_ylabel('Dissolved Oxygen', color=color, size=14)
    ax1.plot(xseries, color=color, marker='.')
    # ax1.scatter(outl.index, outl['val'], color='red')
    ax1.tick_params(axis='y', labelcolor=color, labelsize=12)
    # ax1.set_ylim(0,2)
    # ax1.set_xlim(23300,23400)
    ax2 = ax1.twinx()
    color = 'tab:blue'
    ax2.set_ylabel('CoDisp', color=color, size=14)
    ax2.plot(pd.Series(avg_codisp).sort_index(), color=color)
    avg_codisp_df = pd.DataFrame.from_dict(avg_codisp, orient='index',
        columns=['score'])
    thresh = float(avg_codisp_df.quantile(0.99))
    potential_outl = avg_codisp_df[avg_codisp_df['score'] > thresh]
    ax2.scatter(potential_outl.index, potential_outl['score'], color='black')
    flect = np.median(potential_outl) + 1 * np.std(potential_outl)
    potential_outl2 = potential_outl[potential_outl['score'] > list(flect)[0]]
    ax2.scatter(potential_outl2.index, potential_outl2['score'], color='yellow')
    flect = np.median(potential_outl) + 2 * np.std(potential_outl)
    potential_outl3 = potential_outl[potential_outl['score'] > list(flect)[0]]
    ax2.scatter(potential_outl3.index, potential_outl3['score'], color='orange')
    flect = np.median(potential_outl) + 3 * np.std(potential_outl)
    potential_outl4 = potential_outl[potential_outl['score'] > list(flect)[0]]
    ax2.scatter(potential_outl4.index, potential_outl4['score'], color='red')
    ax2.tick_params(axis='y', labelcolor=color, labelsize=12)
    ax2.grid(False)
    # ax2.set_ylim(0, 140)
    # ax1.set_xlim(750,850)
    plt.title('Dissolved O2 (gray) and anomaly score (orange)', size=14)
    plt.savefig('/home/mike/Desktop/pyfigs/' + str(i) + '_full.png',  bbox_inches='tight')


    pdf = matplotlib.backends.backend_pdf.PdfPages('/home/mike/Desktop/pyfigs/' + str(i) + '_outl.pdf')
    #flip through
    for j in potential_outl4.itertuples():
        fig, ax1 = plt.subplots(nrows=1, ncols=1, figsize=(20, 10))
        color = 'tab:gray'
        ax1.set_ylabel('Dissolved Oxygen', color=color, size=14)
        ax1.plot(xseries, color=color, marker='.')
        # ax1.scatter(outl.index, outl['val'], color='red')
        ax1.tick_params(axis='y', labelcolor=color, labelsize=12)
        ax1.set_ylim(min(xseries), max(xseries))
        ax1.set_xlim(j.Index - 10, j.Index + 10)
        # ax1.set_xlim(max([i.Index - 50, potential_outl4.index[0]]),
        #     min([i.Index + 50, potential_outl4.index[-1]]))
        ax2 = ax1.twinx()
        color = 'tab:blue'
        ax2.set_ylabel('CoDisp', color=color, size=14)
        ax2.plot(pd.Series(avg_codisp).sort_index(), color=color)
        avg_codisp_df = pd.DataFrame.from_dict(avg_codisp, orient='index',
            columns=['score'])
        thresh = float(avg_codisp_df.quantile(0.99))
        potential_outl = avg_codisp_df[avg_codisp_df['score'] > thresh]
        ax2.scatter(potential_outl.index, potential_outl['score'], color='black')
        flect = np.median(potential_outl) + 1 * np.std(potential_outl)
        potential_outl2 = potential_outl[potential_outl['score'] > list(flect)[0]]
        ax2.scatter(potential_outl2.index, potential_outl2['score'], color='yellow')
        flect = np.median(potential_outl) + 2 * np.std(potential_outl)
        potential_outl3 = potential_outl[potential_outl['score'] > list(flect)[0]]
        ax2.scatter(potential_outl3.index, potential_outl3['score'], color='orange')
        flect = np.median(potential_outl) + 3 * np.std(potential_outl)
        potential_outl4 = potential_outl[potential_outl['score'] > list(flect)[0]]
        ax2.scatter(potential_outl4.index, potential_outl4['score'], color='red')
        ax2.tick_params(axis='y', labelcolor=color, labelsize=12)
        ax2.grid(False)
        pane = fig.get_figure()
        pdf.savefig(pane)
        plt.close()
    pdf.close()
        # ax2.set_ylim(0, 140)
        # ax1.set_xlim(750,850)
















df = z
num_trees = 40#40
shingle_size = 20
tree_size = 256#256

for i in range(len(df.columns)):
    varname = df.columns[i]

    xseries = df.iloc[:,i].interpolate(method='linear').to_numpy()

    if all(np.isnan(xseries)):
        continue
    if np.isnan(xseries[0]):
        xseries[0] = xseries[1]

    #create a forest of empty trees
    forest = []
    for _ in range(num_trees):
        tree = rrcf.RCTree()
        forest.append(tree)

    #create rolling window
    points = rrcf.shingle(xseries, size=shingle_size)

    avg_codisp = {}
    for index, point in enumerate(points):
        if index % 2000 == 0:
            # if index > 16000:
            print('point' + str(index))
        # if index == 17920:
        #     raise ValueError('a')
        for tree in forest:
            #drop the oldest point (FIFO) if tree is too big
            if len(tree.leaves) > tree_size:
                tree.forget_point(index - tree_size)

            tree.insert_point(point, index=index)

            #compute collusive displacement on the inserted point
            new_codisp = tree.codisp(index)

            #take the average codisp across all trees; that's anomaly score
            if not index in avg_codisp:
                avg_codisp[index] = 0
            avg_codisp[index] += new_codisp / num_trees








    # #extras
    # nplots = z3.shape[1]
    # sqp = math.sqrt(nplots)
    # nr = round(sqp)
    # nc = math.ceil(sqp)
    # xseries = z3.iloc[:,5].interpolate(method='linear').to_numpy()
    fig, ax1 = plt.subplots(nrows=1, ncols=1, figsize=(20, 10))
    color = 'tab:gray'
    ax1.set_ylabel('Dissolved Oxygen', color=color, size=14)
    ax1.plot(xseries, color=color, marker='.')
    # ax1.scatter(outl.index, outl['val'], color='red')
    ax1.tick_params(axis='y', labelcolor=color, labelsize=12)
    # ax1.set_ylim(0,2)
    # ax1.set_xlim(23300,23400)
    ax2 = ax1.twinx()
    color = 'tab:blue'
    ax2.set_ylabel('CoDisp', color=color, size=14)
    ax2.plot(pd.Series(avg_codisp).sort_index(), color=color)
    avg_codisp_df = pd.DataFrame.from_dict(avg_codisp, orient='index',
        columns=['score'])
    thresh = float(avg_codisp_df.quantile(0.99))
    potential_outl = avg_codisp_df[avg_codisp_df['score'] > thresh]
    ax2.scatter(potential_outl.index, potential_outl['score'], color='black')
    flect = np.median(potential_outl) + 1 * np.std(potential_outl)
    potential_outl2 = potential_outl[potential_outl['score'] > list(flect)[0]]
    ax2.scatter(potential_outl2.index, potential_outl2['score'], color='yellow')
    flect = np.median(potential_outl) + 2 * np.std(potential_outl)
    potential_outl3 = potential_outl[potential_outl['score'] > list(flect)[0]]
    ax2.scatter(potential_outl3.index, potential_outl3['score'], color='orange')
    flect = np.median(potential_outl) + 3 * np.std(potential_outl)
    potential_outl4 = potential_outl[potential_outl['score'] > list(flect)[0]]
    ax2.scatter(potential_outl4.index, potential_outl4['score'], color='red')
    ax2.tick_params(axis='y', labelcolor=color, labelsize=12)
    ax2.grid(False)
    # ax2.set_ylim(0, 140)
    # ax1.set_xlim(750,850)
    plt.title('Dissolved O2 (gray) and anomaly score (orange)', size=14)
    plt.savefig('/home/mike/Desktop/pyfigs/' + str(i) + '_full20.png',  bbox_inches='tight')


    pdf = matplotlib.backends.backend_pdf.PdfPages('/home/mike/Desktop/pyfigs/' + str(i) + '_outl20.pdf')
    #flip through
    for j in potential_outl4.itertuples():
        fig, ax1 = plt.subplots(nrows=1, ncols=1, figsize=(20, 10))
        color = 'tab:gray'
        ax1.set_ylabel('Dissolved Oxygen', color=color, size=14)
        ax1.plot(xseries, color=color, marker='.')
        # ax1.scatter(outl.index, outl['val'], color='red')
        ax1.tick_params(axis='y', labelcolor=color, labelsize=12)
        ax1.set_ylim(min(xseries), max(xseries))
        ax1.set_xlim(j.Index - 10, j.Index + 10)
        # ax1.set_xlim(max([i.Index - 50, potential_outl4.index[0]]),
        #     min([i.Index + 50, potential_outl4.index[-1]]))
        ax2 = ax1.twinx()
        color = 'tab:blue'
        ax2.set_ylabel('CoDisp', color=color, size=14)
        ax2.plot(pd.Series(avg_codisp).sort_index(), color=color)
        avg_codisp_df = pd.DataFrame.from_dict(avg_codisp, orient='index',
            columns=['score'])
        thresh = float(avg_codisp_df.quantile(0.99))
        potential_outl = avg_codisp_df[avg_codisp_df['score'] > thresh]
        ax2.scatter(potential_outl.index, potential_outl['score'], color='black')
        flect = np.median(potential_outl) + 1 * np.std(potential_outl)
        potential_outl2 = potential_outl[potential_outl['score'] > list(flect)[0]]
        ax2.scatter(potential_outl2.index, potential_outl2['score'], color='yellow')
        flect = np.median(potential_outl) + 2 * np.std(potential_outl)
        potential_outl3 = potential_outl[potential_outl['score'] > list(flect)[0]]
        ax2.scatter(potential_outl3.index, potential_outl3['score'], color='orange')
        flect = np.median(potential_outl) + 3 * np.std(potential_outl)
        potential_outl4 = potential_outl[potential_outl['score'] > list(flect)[0]]
        ax2.scatter(potential_outl4.index, potential_outl4['score'], color='red')
        ax2.tick_params(axis='y', labelcolor=color, labelsize=12)
        ax2.grid(False)
        pane = fig.get_figure()
        pdf.savefig(pane)
        plt.close()
    pdf.close()















avg_codisp_df = pd.DataFrame.from_dict(avg_codisp, orient='index',
    columns=['score'])
thresh = float(avg_codisp_df.quantile(0.95))
potential_outl = avg_codisp_df[avg_codisp_df['score'] > thresh]
flect = np.median(potential_outl) + np.std(potential_outl)
import seaborn as sns
plt = sns.distplot(potential_outl)
plt.axvline(list(flect)[0], 0, 99999, linestyle='--')
potential_outl = potential_outl[potential_outl > flect]
plt.scatter(potential_outl)


outl_inds_bool = avg_codisp_df.loc[:,'score'] > thresh
outl_inds_int = outl_inds_bool[outl_inds_bool].index
outl_vals = flagdf.loc[flagdf.index[outl_inds_int], c]
flagdf.loc[flagdf.index[outl_inds_int], c] = outl_vals + 2

df.loc[df.index[outl_inds_int], varname] = np.nan


#put upload id column back on


#notify user that it's done
email_template = 'static/email_templates/pipeline_complete.txt'
# email_template = '/home/mike/git/streampulse/server_copy/sp/static/email_templates/pipeline_complete.txt'
with open(email_template, 'r') as e:
    email_body = e.read()

tmpurl = 'https://data.streampulse.org/pipeline-complete/' + tmpcode
email_body = email_body % (region, site, tmpurl, tmpurl)

email_msg(email_body, 'StreamPULSE upload complete', notificationEmail,
    header=False, render_html=True)
