from __future__ import print_function
from builtins import range
import sys
sys.path.insert(0, '/home/mike/git/streampulse/server_copy/sp')
# import rrcf
import pandas as pd
from helpers import email_msg

import numpy as np
# import logging
# logging.getLogger('fbprophet').setLevel(logging.ERROR)
# import warnings
# warnings.filterwarnings("ignore")
import matplotlib.pyplot as plt
# matplotlib.use('TkAgg')
# matplotlib.use('GTKAgg')
import math
import copy
import re

script_name, notificationEmail, tmpcode, region, site = sys.argv

# userID=35; tmpfile='e076b8930278'
# region='NC'; site='FF'; notificationEmail='vlahm13@gmail.com'
# dumpfile = '../spdumps/confirmcolumns' + tmpfile + '.json'
# # dumpfile = '/home/mike/git/streampulse/server_copy/spdumps/confirmcolumns35_AQ_WB_e076b8930278.json'
# with open(dumpfile) as d:
#     up_data = json.load(d)

# %% trained outl detector

q = np.load('/home/mike/Downloads/telemanom_hmm/data/test/F-2.npy')
qq = pd.DataFrame(q)
qq.to_csv('/home/mike/temp/arse.csv')

trainR = pd.read_csv('~/Downloads/telemanom/training_dev/trainMud.csv',
    index_col='solar.time')
testR = pd.read_csv('~/Downloads/telemanom/training_dev/testMud.csv',
    index_col='solar.time')

trainR.head()
dd = pd.concat([trainR, testR])
dd = dd.reset_index().drop(['solar.time', 'light', 'DO.sat', 'depth'], axis=1)
dd = dd.apply(lambda x: x.interpolate(method='linear'))
dd = dd.diff().iloc[1:dd.shape[0],:]
vars = list(dd.columns.values)
vars = [re.sub('\.','_',x) for x in vars]
train = dd.iloc[0:4030,:]
test = dd.iloc[4031:len(dd),:]
from sklearn.preprocessing import MinMaxScaler
scaler = MinMaxScaler(feature_range=(-1, 1))
scaler = scaler.fit(dd)
scaler = scaler.fit(train)
train = pd.DataFrame(scaler.transform(train))
test = pd.DataFrame(scaler.transform(test))
test.iloc[1000:1010,1] = -1
test.iloc[1000:1001,2] = 1
test.iloc[1000:1010,0] = 0
train.columns = vars
test.columns = vars
dd.apply(lambda x: sum(x.isnull()), axis=0)

# trainR = trainR.reset_index().drop(['solar.time'], axis=1)
# testR = testR.reset_index().drop(['solar.time'], axis=1)
# prenp.pop('pH')
# prenp.apply(lambda x: sum(x.isnull()), axis=0)
for i in range(train.shape[1]):
    v = train.columns[i]
    trainSer = train.iloc[:,i]#.interpolate(method='linear')
    testSer = test.iloc[:,i]#.interpolate(method='linear')
    # if ser[0] == np.nan:
    #     ser[0] = ser[1]
    trainSer = pd.concat([trainSer, pd.Series(np.repeat(0, trainR.shape[0]))], axis=1)
    testSer = pd.concat([testSer, pd.Series(np.repeat(0, testR.shape[0]))], axis=1)
    # trn = npy.head(6000)
    # tst = npy.iloc[6001:10000,:].reset_index(drop=True)
    # trn = npy.head(16126)
    # tst = npy.tail(10750).reset_index(drop=True)
    np.save('/home/mike/Downloads/telemanom/data/train/' + v + '.npy', trainSer)
    np.save('/home/mike/Downloads/telemanom/data/test/' + v + '.npy', testSer)
# pd.DataFrame(np.load('/home/mike/temp/npys/1.npy'))

# newcols = x.columns[x.columns != 'DateTime_UTC'].tolist()
# newcols.insert(0, 'DateTime_UTC')
# x = x.reindex(newcols, axis='columns')

odf = pd.read_csv('~/Dropbox/streampulse/data/pipeline/1.csv',
    index_col='DateTime_UTC')
upids = odf.pop('upload_id')

odf = odf.apply(lambda x: x.interpolate(method='linear'), axis=0)
odf.iloc[[10, 20,21,22,23,24], [0,1]] = [5, 10]; odf.iloc[0, 2] = -50
odf.iloc[[10, 20,21,22,23,24], [2,4]] = [-1, 6]; odf.iloc[0, 2] = -50
z = odf.copy()

# zz = z.head(1000).copy()
# zz.iloc[[10, 20,21,22,23,24], [0,1]] = [15, 20]; zz.iloc[0, 2] = -50
# z = zz.copy()

flagdf = z.applymap(lambda x: 0)
# flagdf = z.set_index('DateTime_UTC').applymap(lambda x: 0).reset_index()

def range_check(df, flagdf):

    ranges = {
        'DO_mgL': (-0.5, 40),
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




import time
start_time = time.time()
# z3, flagdf, potential_outl = anomaly_detect2(z2, flagdf, 200, 1024)
z3, flagdf = anomaly_detect(z2, flagdf, 200, 20, 256)
print(round((time.time() - start_time) / 60, 2))

flagdf.apply(sum, axis=0)
z.apply(lambda x: sum(x.isnull()), axis=0)

# origdf = odf; df = z3; i=5
def plot_flags(origdf, df, flagdf, potential_outl=None, xlim=None, ylim=None):
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
        if potential_outl is not None:
            if not isinstance(potential_outl[varname], pd.DataFrame):
                ax[i].plot([1, 2, 3], [1, 2, 3])
                continue
        origdf.index = list(range(len(origdf)))
        flagdf.index = list(range(len(flagdf)))
        varseries = origdf[varname]
        out_of_range = origdf.loc[flagdf.index[flagdf[varname] == 1], varname]
        outlier = origdf.loc[flagdf.index[flagdf[varname].isin([2, 3])], varname]
        ax[i].set_ylabel(varname, color=linecol, size=14)
        ax[i].plot(varseries, color=linecol, marker='.')
        # p = potential_outl[varname]

        # ax[i].scatter(p.index, p['score'], color='black')
        # flect = np.median(p) + 1 * np.std(p)
        # p2 = p[p['score'] > list(flect)[0]]
        # ax[i].scatter(p2.index, p2['score'], color='yellow')
        # flect = np.median(p) + 2 * np.std(p)
        # p3 = p[p['score'] > list(flect)[0]]
        # ax[i].scatter(p3.index, p3['score'], color='orange')
        # flect = np.median(p) + 3 * np.std(p)
        # p4 = p[p['score'] > list(flect)[0]]
        # ax[i].scatter(p4.index, p4['score'], color='red')

        ax[i].scatter(out_of_range.index, out_of_range, color='green')
        ax[i].scatter(outlier.index, outlier, color='blue')
        # plt.title('Dissolved O2 (gray) and anomaly score (orange)', size=14)
        if xlim is not None:
            ax[i].set_xlim(xlim[0], xlim[1])
        if ylim is not None:
            ax[i].set_ylim(ylim[0], ylim[1])
        ax[i].tick_params(axis='y', labelcolor=linecol, labelsize=12)
        # ax[i].set_xticklabels([])
        # ax[i].xticks([])
        # ax[i].gca().axes.get_xaxis().set_visible(False)
        # cur_axes = ax[i].gca()
        # cur_axes.axes.get_xaxis().set_visible(False)
        # ax[i].xticks(np.arange(min(x), max(x)+1, 1.0))
        ax[i].xaxis.set_visible(False)

# plot_flags(odf, z3, flagdf, xlim=[1600,1700], ylim=[300,700]) #full
# plot_flags(odf, z3, flagdf, xlim=[1500,2000])
plot_flags(odf, z3, flagdf) #full
# plot_flags(zz, z3, flagdf, potential_outl, [0,1000]) #subset

# %% lstm tuning

from pandas import DataFrame
from pandas import Series
from pandas import concat
from pandas import read_csv
from pandas import datetime
from sklearn.metrics import mean_squared_error
from sklearn.preprocessing import MinMaxScaler
from keras.models import Sequential
from keras.layers import Dense
from keras.layers import LSTM
from math import sqrt
import matplotlib
# be able to save images on server
matplotlib.use('Agg')
from matplotlib import pyplot
import numpy

# date-time parsing function for loading the dataset
def parser(x):
	return datetime.strptime('190'+x, '%Y-%m')

# frame a sequence as a supervised learning problem
def timeseries_to_supervised(data, lag=1):
	df = DataFrame(data)
	columns = [df.shift(i) for i in range(1, lag+1)]
	columns.append(df)
	df = concat(columns, axis=1)
	df = df.drop(0)
	return df

# create a differenced series
def difference(dataset, interval=1):
	diff = list()
	for i in range(interval, len(dataset)):
		value = dataset[i] - dataset[i - interval]
		diff.append(value)
	return Series(diff)

# scale train and test data to [-1, 1]
def scale(train, test):
	# fit scaler
	scaler = MinMaxScaler(feature_range=(-1, 1))
	scaler = scaler.fit(train)
	# transform train
	train = train.reshape(train.shape[0], train.shape[1])
	train_scaled = scaler.transform(train)
	# transform test
	test = test.reshape(test.shape[0], test.shape[1])
	test_scaled = scaler.transform(test)
	return scaler, train_scaled, test_scaled

# inverse scaling for a forecasted value
def invert_scale(scaler, X, yhat):
	new_row = [x for x in X] + [yhat]
	array = numpy.array(new_row)
	array = array.reshape(1, len(array))
	inverted = scaler.inverse_transform(array)
	return inverted[0, -1]

# evaluate the model on a dataset, returns RMSE in transformed units
def evaluate(model, raw_data, scaled_dataset, scaler, offset, batch_size):
	# separate
	X, y = scaled_dataset[:,0:-1], scaled_dataset[:,-1]
	# reshape
	reshaped = X.reshape(len(X), 1, 1)
	# forecast dataset
	output = model.predict(reshaped, batch_size=batch_size)
	# invert data transforms on forecast
	predictions = list()
	for i in range(len(output)):
		yhat = output[i,0]
		# invert scaling
		yhat = invert_scale(scaler, X[i], yhat)
		# invert differencing
		yhat = yhat + raw_data[i]
		# store forecast
		predictions.append(yhat)
	# report performance
	rmse = sqrt(mean_squared_error(raw_data[1:], predictions))
	return rmse

# fit an LSTM network to training data
def fit_lstm(train, test, raw, scaler, batch_size, nb_epoch, neurons):
	X, y = train[:, 0:-1], train[:, -1]
	X = X.reshape(X.shape[0], 1, X.shape[1])
	# prepare model
	model = Sequential()
	model.add(LSTM(neurons, batch_input_shape=(batch_size, X.shape[1], X.shape[2]), stateful=True))
	model.add(Dense(1))
	model.compile(loss='mean_squared_error', optimizer='adam')
	# fit model
	train_rmse, test_rmse = list(), list()
	for i in range(nb_epoch):
		model.fit(X, y, epochs=1, batch_size=batch_size, verbose=0, shuffle=False)
		model.reset_states()
		# evaluate model on train data
		raw_train = raw[-(len(train)+len(test)+1):-len(test)]
		train_rmse.append(evaluate(model, raw_train, train, scaler, 0, batch_size))
		model.reset_states()
		# evaluate model on test data
		raw_test = raw[-(len(test)+1):]
		test_rmse.append(evaluate(model, raw_test, test, scaler, 0, batch_size))
		model.reset_states()
	history = DataFrame()
	history['train'], history['test'] = train_rmse, test_rmse
	return history

# run diagnostic experiments
def run():
	# load dataset
	series = read_csv('shampoo-sales.csv', header=0, parse_dates=[0], index_col=0, squeeze=True, date_parser=parser)
	# transform data to be stationary
	raw_values = series.values
	diff_values = difference(raw_values, 1)
	# transform data to be supervised learning
	supervised = timeseries_to_supervised(diff_values, 1)
	supervised_values = supervised.values
	# split data into train and test-sets
	train, test = supervised_values[0:-12], supervised_values[-12:]
	# transform the scale of the data
	scaler, train_scaled, test_scaled = scale(train, test)
	# fit and evaluate model
	train_trimmed = train_scaled[2:, :]
	# config
	repeats = 10
	n_batch = 4
	n_epochs = 500
	n_neurons = 1
	# run diagnostic tests
	for i in range(repeats):
		history = fit_lstm(train_trimmed, test_scaled, raw_values, scaler, n_batch, n_epochs, n_neurons)
		pyplot.plot(history['train'], color='blue')
		pyplot.plot(history['test'], color='orange')
		print('%d) TrainRMSE=%f, TestRMSE=%f' % (i, history['train'].iloc[-1], history['test'].iloc[-1]))
	pyplot.savefig('epochs_diagnostic.png')

# entry point
run()


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
