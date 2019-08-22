# %% markdown
# # Results
# - Plot training/test telemetry values, predictions, smoothed errors, and predicted and actual anomalies
# - A specified results file from the `results` dir is used to highlight anomalous regions and read in data from the `data` dir
# %%
import sys
import numpy as np
import csv
import os
os.chdir('/home/mike/Downloads/telemanom/results')
sys.path.insert(0, '..')
# sys.path.insert(0, '/home/mike/Downloads/telemanom')
from telemanom._globals import Config
# sys.path.remove('/home/mike/Downloads/telemanom')
# sys.path.insert(0, '/home/mike/Downloads/telemanom/telemanom')
import telemanom.helpers as helpers
import pandas as pd
import plotly as py
from plotly.offline import download_plotlyjs, init_notebook_mode
import cufflinks as cf
import glob
cf.go_offline()
init_notebook_mode(connected=True)

# load in current system configs
config = Config("../config.yaml")
# %%
%%javascript
IPython.OutputArea.prototype._should_scroll = function(lines) {
    return false;
}
# %% markdown
# ## Select set of results to visualize
# %%
# results_fn = '2018-05-18_16.17.03.csv'
# print("Prior run: %s" %results_fn)

# Default to most recent
results_fn = glob.glob('*.csv')[-1]
print("Using most recent run: %s" %results_fn)
# %% markdown
# ## Parameters
# - See `config.yaml` for parameter explanations
# %%
with open('../data/%s/params.log' %results_fn[:-4], 'r') as f:
    for i,row in enumerate(f.readlines()):
        if len(row) < 2:
            break
        if i > 0:
            print(' '.join(row.split(' ')[3:]).replace('\n',''))
# %% markdown
# ## Summary of results
# %%
with open('../data/%s/params.log' %results_fn[:-4], 'r') as f:
    print_row = False
    for row in f.readlines():
        if 'Final' in row:
            print_row = True
        if print_row:
            print(' '.join(row.split(' ')[3:]).replace('\n',''))
# %% markdown
# ## Interactive inline Plotly charts for viewing `y_test`, `y_hat`, and `smoothed errors (e_s)`
# - **Blue** highlighted regions indicate anomalous sequences detected by the system
# - **Red** highlighted regions indicate true anomalous regions
# - Can also optionally plot training data by setting `plot_train=True`
# - Plots can be limited by specifying start and end rows in the results file to plot via `run=(<start row>, <end row>)`
# %%

helpers.view_results(results_fn, plot_errors=True, plot_train=False, rows=(0,10))
# %%
