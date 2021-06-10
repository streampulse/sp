# os.chdir('/home/mike/git/streampulse/server_copy/sp')
# import timeit
from __future__ import print_function
from builtins import zip
from builtins import str
from builtins import range
from flask import (Flask, Markup, session, flash, render_template, request,
    jsonify, url_for, make_response, send_file, redirect, g, send_from_directory)
from flask_login import LoginManager, login_user, logout_user, current_user, login_required
from werkzeug.security import generate_password_hash, check_password_hash
from sunrise_sunset import SunriseSunset as suns
from werkzeug.utils import secure_filename
from flask_sqlalchemy import SQLAlchemy
import sqlalchemy
# from sqlalchemy.ext import serializer
from itsdangerous import URLSafeTimedSerializer
from datetime import datetime, timedelta
from dateutil import parser as dtparse
from math import log, sqrt, floor
import simplejson as json
from sklearn import svm
from operator import itemgetter
import itertools
# import copy
import pandas as pd
import numpy as np
import requests
import binascii
import tempfile
import zipfile
import shutil
#import pysb
import os
import re
import sys
import config as cfg
# import logging
import readline #needed for rpy2 import in conda env
from functools import reduce
os.environ['R_HOME'] = '/usr/lib/R' #needed for rpy2 to find R. has to be a better way
import rpy2.robjects as robjects
from rpy2.robjects import pandas2ri
import markdown
import time
import traceback
import regex
# import smtplib
# from email.mime.text import MIMEText
# from email.mime.application import MIMEApplication
# from email.mime.multipart import MIMEMultipart
import subprocess
from helpers import *
# import feather

pandas2ri.activate() #for converting pandas df to R df

app = Flask(__name__)

#allow use of more python methods in Jinja2 templates
# app.jinja_env.filters['zip'] = zip
# app.jinja_env.filters['dict'] = dict
# app.jinja_env.filters['list'] = list
#app.jinja_env.globals.update(zip=zip)
# app.jinja_env.filters['values'] = values
# app.jinja_env.globals.update(zip=zip)

# app.session_interface = RedisSessionInterface()

app.config['SECRET_KEY'] = cfg.SECRET_KEY
app.config['SQLALCHEMY_DATABASE_URI'] = cfg.SQLALCHEMY_DATABASE_URI
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = cfg.SQLALCHEMY_TRACK_MODIFICATIONS
app.config['UPLOAD_FOLDER'] = cfg.UPLOAD_FOLDER
# app.config['UPLOAD_ORIG_FOLDER'] = "/home/mike/git/streampulse/server_copy/spuploads_original"
app.config['META_FOLDER'] = cfg.META_FOLDER
app.config['REACH_CHAR_FOLDER'] = cfg.REACH_CHAR_FOLDER
app.config['GRAB_FOLDER'] = cfg.GRAB_FOLDER
app.config['BULK_DNLD_FOLDER'] = cfg.BULK_DNLD_FOLDER
app.config['RESULTS_FOLDER'] = cfg.RESULTS_FOLDER
app.config['ERRFILE_FOLDER'] = cfg.ERRFILE_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 700 * 1024 * 1024 # originally set to 16 MB; now 700
app.config['SECURITY_PASSWORD_SALT'] = cfg.SECURITY_PASSWORD_SALT
#app.config['PROPAGATE_EXCEPTIONS'] = True

#error logging
logfile = os.getcwd() + '/../logs_etc/app.log'
# logfile = '/home/mike/git/streampulse/server_copy/logs_etc/app.log'
# logging.basicConfig(filename='/home/aaron/logs_etc/app.log',
# logging.basicConfig(filename='/home/mike/git/streampulse/server_copy/logs_etc/app.log',
#     level=logging.DEBUG)#, format='%(asctime)s - %(levelname)s - %(message)s')
#handler = logging.FileHandler('/home/aaron/logs_etc/app.log')
#handler.setLevel(logging.NOTSET)
#app.logger.addHandler(handler)

#sb.login(cfg.SB_USER,cfg.SB_PASS)
#sbupf = sb.get_item(cfg.SB_UPFL)
########## DATABASE
db = SQLAlchemy(app)
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

#classes for SQLAlchemy's ORM
class Data(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    region = db.Column(db.String(10))
    site = db.Column(db.String(50))
    DateTime_UTC = db.Column(db.DateTime)
    variable = db.Column(db.String(50))
    value = db.Column(db.Float)
    flag = db.Column(db.Integer)
    upload_id = db.Column(db.Integer)

    def __init__(self, region, site, DateTime_UTC, variable, value, flag, upid):
        self.region = region
        self.site = site
        self.DateTime_UTC = DateTime_UTC
        self.variable = variable
        self.value = value
        self.flag = flag
        self.upload_id = upid

    def __repr__(self):
        return '<Data %r, %r, %r, %r, %r>' % (self.region, self.site,
        self.DateTime_UTC, self.variable, self.upload_id)

class Data0(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    region = db.Column(db.String(10))
    site = db.Column(db.String(50))
    DateTime_UTC = db.Column(db.DateTime)
    variable = db.Column(db.String(50))
    value = db.Column(db.Float)
    flag = db.Column(db.Integer)
    upload_id = db.Column(db.Integer)

    def __init__(self, region, site, DateTime_UTC, variable, value, flag, upid):
        self.region = region
        self.site = site
        self.DateTime_UTC = DateTime_UTC
        self.variable = variable
        self.value = value
        self.flag = flag
        self.upload_id = upid

    def __repr__(self):
        return '<Data0 %r, %r, %r, %r, %r>' % (self.region, self.site,
        self.DateTime_UTC, self.variable, self.upload_id)

class Autoqaqc(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    region = db.Column(db.String(10))
    site = db.Column(db.String(50))
    DateTime_UTC = db.Column(db.DateTime)
    variable = db.Column(db.String(50))
    qaqc = db.Column(db.String(7))

    def __init__(self, region, site, DateTime_UTC, variable, qaqc):
        self.region = region
        self.site = site
        self.DateTime_UTC = DateTime_UTC
        self.variable = variable
        self.qaqc = qaqc

    def __repr__(self):
        return '<Data %r, %r, %r, %r, %r>' % (self.region, self.site,
        self.DateTime_UTC, self.variable, self.qaqc)

class Grabdata(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    region = db.Column(db.String(10))
    site = db.Column(db.String(50))
    DateTime_UTC = db.Column(db.DateTime)
    variable = db.Column(db.String(50))
    value = db.Column(db.Float)
    method = db.Column(db.String(40))
    write_in = db.Column(db.String(40))
    addtl = db.Column(db.String(40))
    flag = db.Column(db.Integer)
    upload_id = db.Column(db.Integer)

    def __init__(self, region, site, DateTime_UTC, variable, value, method,
        write_in, addtl, flag, upid):
        self.region = region
        self.site = site
        self.DateTime_UTC = DateTime_UTC
        self.variable = variable
        self.value = value
        self.method = method
        self.write_in = write_in
        self.addtl = addtl
        self.flag = flag
        self.upload_id = upid

    def __repr__(self):
        return '<Grabdata %r, %r, %r, %r, %r>' % (self.region, self.site,
            self.DateTime_UTC, self.variable, self.method, self.write_in,
            self.addtl, self.upload_id)

class Flag(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    region = db.Column(db.String(10))
    site = db.Column(db.String(50))
    startDate = db.Column(db.DateTime)
    endDate = db.Column(db.DateTime)
    variable = db.Column(db.String(50))
    flag = db.Column(db.String(50))
    comment = db.Column(db.String(255))
    by = db.Column(db.Integer) # user ID
    def __init__(self, region, site, startDate, endDate, variable, flag, comment, by):
        self.region = region
        self.site = site
        self.startDate = startDate
        self.endDate = endDate
        self.variable = variable
        self.flag = flag
        self.comment = comment
        self.by = by
    def __repr__(self):
        return '<Flag %r, %r, %r>' % (self.flag, self.comment, self.startDate)

class Grabflag(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    region = db.Column(db.String(10))
    site = db.Column(db.String(50))
    startDate = db.Column(db.DateTime)
    endDate = db.Column(db.DateTime)
    variable = db.Column(db.String(50))
    flag = db.Column(db.String(50))
    comment = db.Column(db.String(255))
    by = db.Column(db.Integer) # user ID
    def __init__(self, region, site, startDate, endDate, variable, flag, comment, by):
        self.region = region
        self.site = site
        self.startDate = startDate
        self.endDate = endDate
        self.variable = variable
        self.flag = flag
        self.comment = comment
        self.by = by
    def __repr__(self):
        return '<Grabflag %r, %r, %r>' % (self.flag, self.comment, self.startDate)

class Site(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    region = db.Column(db.String(10))
    site = db.Column(db.String(50))
    name = db.Column(db.String(100))
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)
    datum = db.Column(db.String(50))
    usgs = db.Column(db.String(20))
    addDate = db.Column(db.DateTime)
    embargo = db.Column(db.Integer)
    by = db.Column(db.Integer)
    contact = db.Column(db.String(50))
    contactEmail = db.Column(db.String(255))
    def __init__(self, region, site, name, latitude, longitude, datum, usgs, addDate, embargo, by, contact, contactEmail):
        self.region = region
        self.site = site
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.datum = datum
        self.usgs = usgs
        self.addDate = addDate
        self.embargo = embargo
        self.by = by
        self.contact = contact
        self.contactEmail = contactEmail
    def __repr__(self):
        return '<Site %r, %r>' % (self.region, self.site)

class Cols(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    region = db.Column(db.String(10))
    site = db.Column(db.String(50))
    rawcol = db.Column(db.String(100))
    dbcol = db.Column(db.String(100))
    level = db.Column(db.String(50))
    notes = db.Column(db.String(200))
    def __init__(self, region, site, rawcol, dbcol, level, notes):
        self.region = region
        self.site = site
        self.rawcol = rawcol
        self.dbcol = dbcol
        self.level = level
        self.notes = notes
    def __repr__(self):
        return '<Cols %r, %r, %r, %r, %r>' % (self.region, self.site, self.dbcol,
            self.level, self.notes)

class Notificationemail(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    region = db.Column(db.String(10))
    site = db.Column(db.String(50))
    email = db.Column(db.String(255))
    def __init__(self, region, site, email):
        self.region = region
        self.site = site
        self.email = email
    def __repr__(self):
        return '<Notificationemail %r, %r, %r>' % (self.region, self.site, self.email)

class Grabcols(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    region = db.Column(db.String(10))
    site = db.Column(db.String(50))
    rawcol = db.Column(db.String(100))
    dbcol = db.Column(db.String(100))
    method = db.Column(db.String(40))
    write_in = db.Column(db.String(40))
    addtl = db.Column(db.String(40))

    def __init__(self, region, site, rawcol, dbcol, method, write_in, addtl):
        self.region = region
        self.site = site
        self.rawcol = rawcol
        self.dbcol = dbcol
        self.method = method
        self.write_in = write_in
        self.addtl = addtl

    def __repr__(self):
        return '<Grabcols %r, %r, %r>' % (self.region, self.site, self.dbcol)

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(55), unique=True, index=True)
    password = db.Column(db.String(255))
    token = db.Column(db.String(100), nullable=False, server_default='')
    email = db.Column(db.String(255), unique=True)
    registered_on = db.Column(db.DateTime())
    confirmed = db.Column(db.Boolean)
    qaqc = db.Column(db.Text) # which qaqc sites can they save, comma separated?
    def __init__(self, username, password, email):
        self.username = username
        self.set_password(password)
        self.token = binascii.hexlify(os.urandom(10)).decode('utf-8')
        self.email = email
        self.registered_on = datetime.utcnow()
        self.confirmed = True # do they agree to the policy?
        self.qaqc = ""
    def set_password(self, password):
        self.password = generate_password_hash(password)
    def check_password(self, password):
        return check_password_hash(self.password, password)
    def is_authenticated(self):
        return True
    def is_active(self):
        return True
    def is_anonymous(self):
        return False
    def get_id(self):
        return str(self.id)
    def qaqc_auth(self):
        return self.qaqc.split(",") # which tables can they edit
    def __repr__(self):
        return '<User %r>' % self.username

class Downloads(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    timestamp = db.Column(db.DateTime)
    userID = db.Column(db.Integer)
    email = db.Column(db.String(255))
    dnld_sites = db.Column(db.String(500))
    dnld_date0 = db.Column(db.DateTime)
    dnld_date1 = db.Column(db.DateTime)
    dnld_vars = db.Column(db.String(500))
    def __init__(self, timestamp, userID, email, dnld_sites, dnld_date0, dnld_date1, dnld_vars):
        self.timestamp = timestamp
        self.userID = userID
        self.email = email
        self.dnld_sites = dnld_sites
        self.dnld_date0 = dnld_date0
        self.dnld_date1 = dnld_date1
        self.dnld_vars = dnld_vars
    def __repr__(self):
        return '<Download %r>' % (self.id)

class Upload(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(100))
    uploadtime_utc = db.Column(db.DateTime)
    user_id = db.Column(db.Integer)
    # version = db.Column(db.Integer)

    def __init__(self, filename, uploadtime_utc, user_id):
        self.filename = filename
        self.uploadtime_utc = uploadtime_utc
        self.user_id = user_id

    def __repr__(self):
        return '<Upload %r>' % (self.filename)

class Model(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    region = db.Column(db.String(2))
    site = db.Column(db.String(50))
    start_date = db.Column(db.DateTime)
    end_date = db.Column(db.DateTime)
    requested_variables = db.Column(db.String(200))
    year = db.Column(db.Integer)
    run_finished = db.Column(db.DateTime)
    model = db.Column(db.String(17))
    method = db.Column(db.String(5))
    engine = db.Column(db.String(4))
    rm_flagged = db.Column(db.String(35))
    used_rating_curve = db.Column(db.Boolean)
    pool = db.Column(db.String(7))
    proc_err = db.Column(db.Boolean)
    obs_err = db.Column(db.Boolean)
    proc_acor = db.Column(db.Boolean)
    ode_method = db.Column(db.String(9))
    deficit_src = db.Column(db.String(13))
    interv = db.Column(db.String(12))
    fillgaps = db.Column(db.String(13))
    estimate_areal_depth = db.Column(db.Boolean)
    O2_GOF = db.Column(db.Float)
    GPP_95CI = db.Column(db.Float)
    ER_95CI = db.Column(db.Float)
    prop_pos_ER = db.Column(db.Float)
    prop_neg_GPP = db.Column(db.Float)
    ER_K600_cor = db.Column(db.Float)
    coverage = db.Column(db.Integer)
    kmax = db.Column(db.Float)
    current_best = db.Column(db.Boolean)

    def __init__(self, region, site, start_date, end_date,
        requested_variables, year, run_finished, model, method, engine,
        rm_flagged, used_rating_curve, pool, proc_err, obs_err, proc_acor,
        ode_method, deficit_src, interv, fillgaps, estimate_areal_depth,
        O2_GOF, GPP_95CI, ER_95CI, prop_pos_ER, prop_neg_GPP, ER_K600_cor,
        coverage, kmax, current_best):

        self.region = region
        self.site = site
        self.start_date = start_date
        self.end_date = end_date
        self.requested_variables = requested_variables
        self.year = year
        self.run_finished = run_finished
        self.model = model
        self.method = method
        self.engine = engine
        self.rm_flagged = rm_flagged
        self.used_rating_curve = used_rating_curve
        self.pool = pool
        self.proc_err = proc_err
        self.obs_err = obs_err
        self.proc_acor = proc_acor
        self.ode_method = ode_method
        self.deficit_src = deficit_src
        self.interv = interv
        self.fillgaps = fillgaps
        self.estimate_areal_depth = estimate_areal_depth
        self.O2_GOF = O2_GOF
        self.GPP_95CI = GPP_95CI
        self.ER_95CI = ER_95CI
        self.prop_pos_ER = prop_pos_ER
        self.prop_neg_GPP = prop_neg_GPP
        self.ER_K600_cor = ER_K600_cor
        self.coverage = coverage
        self.kmax = kmax
        self.current_best = current_best

    def __repr__(self):
        return '<Data %r, %r, %r, %r>' % (self.region, self.site, self.year, self.current_best)

class Grabupload(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(100))
    uploadtime_utc = db.Column(db.DateTime)
    user_id = db.Column(db.Integer)

    def __init__(self, filename, uploadtime_utc, user_id):
        self.filename = filename
        self.uploadtime_utc = uploadtime_utc
        self.user_id = user_id

    def __repr__(self):
        return '<Grabupload %r>' % (self.filename)

class Grdo(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(50))
    email = db.Column(db.String(50))
    addDate = db.Column(db.DateTime)
    embargo = db.Column(db.Integer)
    notes = db.Column(db.String(5000))
    dataFiles = db.Column(db.String(5000))
    metaFiles = db.Column(db.String(5000))

    def __init__(self, name, email, addDate, embargo, notes, dataFiles, metaFiles):
        self.name = name
        self.email = email
        self.addDate = addDate
        self.embargo = embargo
        self.notes = notes
        self.dataFiles = dataFiles
        self.metaFiles = metaFiles

    def __repr__(self):
        return '<Data %r, %r, %r>' % (self.name, self.email, self.addDate)

class Reachfiles(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(100))
    uploader = db.Column(db.String(50))
    email = db.Column(db.String(50))
    addDate = db.Column(db.DateTime)

    def __init__(self, filename, uploader, email, addDate):
        self.filename = filename
        self.uploader = uploader
        self.email = email
        self.addDate = addDate

    def __repr__(self):
        return '<Data %r, %r, %r>' % (self.filename, self.email, self.addDate)

db.create_all()

@login_manager.user_loader
def load_user(id):
    return User.query.get(int(id))

@app.before_request
def before_request():
    g.user = current_user

###########
# #mysqldb eg
# cur = db.connection.cursor()
# cur.execute("SELECT * FROM articles")
# cur.execute("select distinct concat(region,'_',site) from data")
# x = cur.fetchall()
####################
########### FUNCTIONS
# Load core data sites
core = pd.read_csv('static/sitelist.csv')
core['SITECD'] = list(core["REGIONID"].map(str) + "_" + core["SITEID"])
core = core.set_index('SITECD')

#load leveraged sites that can upload logger files directly
pseudo_core = pd.read_csv('static/sitelist_pseudo_core.csv')
pseudo_core['SITECD'] = list(pseudo_core["REGIONID"].map(str) + "_" + pseudo_core["SITEID"])
pseudo_core = pseudo_core.set_index('SITECD')

#DateTime_UTC must remain in the first position
variables = ['DateTime_UTC', 'DO_mgL', 'DOSecondary_mgL', 'satDO_mgL', 'DOsat_pct', 'WaterTemp_C', 'WaterTemp2_C', 'WaterTemp3_C',
'WaterPres_kPa', 'AirTemp_C', 'AirPres_kPa', 'Level_m', 'Depth_m',
'Discharge_m3s', 'Velocity_ms', 'pH', 'pH_mV', 'RedoxPotential_mV', 'CDOM_ppb', 'CDOM_mV', 'FDOM_mV',
'Turbidity_NTU', 'Turbidity_mV', 'Turbidity_FNU', 'Nitrate_mgL', 'SpecCond_mScm',
'SpecCond_uScm', 'EC_uScm', 'CO2_ppm', 'ChlorophyllA_ugL', 'Light_lux', 'Light_PAR', 'Light2_lux',
'Light2_PAR', 'Light3_lux', 'Light3_PAR', 'Light4_lux', 'Light4_PAR',
'Light5_lux', 'Light5_PAR', 'underwater_lux', 'underwater_PAR', 'benthic_lux',
'benthic_PAR', 'Battery_V']
# O2GasTransferVelocity_ms

o = 'other'
# fltr_methods = ['IC', 'FIA', 'TOC-TN', 'spectrophotometer']
# fltr_opts = ['filtered-45mm', 'filtered-other', 'unfiltered']
grab_variables = [
{'var': 'Br', 'unit': 'Bromide', 'method': ['IC',o]},
{'var': 'Ca', 'unit': 'Calcium', 'method': ['IC',o]},
{'var': 'Cl', 'unit': 'Chloride', 'method': ['IC',o]},
{'var': 'K', 'unit': 'Potassium', 'method': ['IC',o]},
{'var': 'Mg', 'unit': 'Magnesium', 'method': ['IC',o]},
{'var': 'Na', 'unit': 'Sodium', 'method': ['IC',o]},
{'var': 'NH4', 'unit': 'Ammonium', 'method': ['FIA',o]},
{'var': 'NO3', 'unit': 'Nitrate (+nitrite if FIA)', 'method': ['IC','FIA',o]},
{'var': 'PO4', 'unit': 'Phosphate', 'method': ['IC','FIA',o]},
{'var': 'SiO2', 'unit': 'Silica', 'method': ['FIA','spectrophotometer',o]},
{'var': 'SO4', 'unit': 'Sulfate', 'method': ['IC',o]},
{'var': 'Total_Fe', 'unit': 'Total Fe (molar)', 'method': ['spectroscopy','FIA',o]},
{'var': 'Total_Mn', 'unit': 'Total Mn (molar)', 'method': ['spectroscopy','FIA',o]},
{'var': 'TOC', 'unit': 'TOC (ppm)', 'method': ['TOC-TN',o]},
{'var': 'TN', 'unit': 'TN (ppm)', 'method': ['TOC-TN',o]},
{'var': 'TP', 'unit': 'TP (ppm)', 'method': ['Ascorbic Acid Method',o]},
{'var': 'TDN', 'unit': 'TDN (mg/L)', 'method': ['TOC-TN',o]},
{'var': 'TDP', 'unit': 'TDP (mg/L)', 'method': ['Ascorbic Acid Method',o]},
{'var': 'SRP', 'unit': 'SRP (mg/L)', 'method': ['Ascorbic Acid Method',o]},
{'var': 'DOC', 'unit': 'DOC (ppm)', 'method': ['combustion','oxidation',o]},
{'var': 'DIC', 'unit': 'DIC (ppm)', 'method': ['combustion','oxidation',o]},
{'var': 'TSS', 'unit': 'TSS (ppm)', 'method': ['dry mass','backscatter',o]},
{'var': 'fDOM', 'unit': 'fDOM (ppb)', 'method': ['sonde',o]},
{'var': 'CO2', 'unit': 'Carbon dioxide (ppm)', 'method': ['sonde','GC',o]},
{'var': 'CH4', 'unit': 'Methane (ug/L)', 'method': ['GC',o]},
{'var': 'N2O', 'unit': 'Nitrous oxide (ug/L)', 'method': ['GC',o]},
{'var': 'DO', 'unit': 'DO (mg/L)', 'method': ['sensor',o]},
{'var': 'DO_Sat', 'unit': 'DO Sat (%)', 'method': ['sensor',o]},
{'var': 'Chlorophyll-a', 'unit': 'Chlorophyll-a (mg/L)', 'method': ['spectrophotometer',o]},
{'var': 'Alkalinity', 'unit': 'Alkalinity (meq/L)', 'method': ['FIA','titration',o]},
{'var': 'pH', 'unit': 'pH', 'method': ['ISFET',o]},
{'var': 'Spec_Cond', 'unit': 'Spec Cond (mS/cm)', 'method': ['sonde',o]},
{'var': 'Turbidity', 'unit': 'Turbidity (NTU)', 'method': ['turbidimeter',o]},
{'var': 'Light_Atten', 'unit': 'Light Atten. (1/m)', 'method': ['pyranometer',o]},
{'var': 'Illuminance', 'unit': 'Illuminance (lux)', 'method': ['lux meter',o]},
{'var': 'PAR', 'unit': 'PAR (W/m^2)', 'method': ['pyranometer',o]},
{'var': 'UV_Absorbance', 'unit': 'UV Absorbance (1/cm)', 'method': ['spectrophotometer',o]},
{'var': 'Canopy_Cover', 'unit': 'Canopy Cover (LAI)', 'method': ['field measurement','remote sensing','model',o]},
{'var': 'Width', 'unit': 'Width (m)', 'method': ['field measurement',o]},
{'var': 'Depth', 'unit': 'Depth (m)', 'method': ['field measurement',o]},
{'var': 'Distance', 'unit': 'Distance (m)', 'method': ['field measurement',o]},
{'var': 'Discharge', 'unit': 'Discharge (m^3/s)', 'method': ['flow meter','salt slug',o]},
{'var': 'k', 'unit': 'k (1/min)', 'method': ['argon','propane','SF6','radon','floating chamber',o]},
{'var': 'Water_Temp', 'unit': 'Water Temp (C)', 'method': ['sonde',o]},
{'var': 'Air_Temp', 'unit': 'Air Temp (C)', 'method': ['sonde',o]},
{'var': 'Water_Pres', 'unit': 'Water Pres (kPa)', 'method': ['sonde',o]},
{'var': 'Air_Pres', 'unit': 'Air Pres (kPa)', 'method': ['sonde',o]}
]
# #'Substrate',  Bed_Cover?, Flow,

#R code for outlier detection
with open('find_outliers.R', 'r') as f:
    find_outliers_string = f.read()
find_outliers = robjects.r(find_outliers_string)

# def log_exception(e, excID, traceback):
def log_exception(excID, traceback):

    cur_user = str(current_user.get_id()) if current_user else 'anonymous'
    with open(logfile, 'a') as lf:
        lf.write(datetime.now().strftime('%Y-%m-%d %H:%M:%S') +\
            '; ' + excID + '; userID=' + cur_user +\
            # '; ' + excID + '; userID=' + cur_user + ';\nerror: ' + e.__str__() +\
            ';\ntraceback:\n ' + traceback.__str__() + '\n\n')

def log_message(msgID):
    cur_user = str(current_user.get_id()) if current_user else 'NA'
    with open(logfile, 'a') as lf:
        lf.write(datetime.now().strftime('%Y-%m-%d %H:%M:%S') +\
            '; ' + msgID + '; userID=' + cur_user + ';\n')

ALLOWED_EXTENSIONS = set(['txt', 'dat', 'csv'])
def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1] in ALLOWED_EXTENSIONS

def read_hobo(f):

    # f = '~/Downloads/MD_BARN2_2018-09-20_HP.csv'
    # f = '~/Downloads/MD_BARN2_2018-09-20_HP2.csv'
    # f = '~/Downloads/NC_Eno_2016-10-17_HP.csv'

    xt = pd.read_csv(f, nrows=1, header=None)
    if len(xt.loc[0,:].dropna()) == 1:
        xt = pd.read_csv(f, skiprows=[0])
    else:
        xt = pd.read_csv(f)
    cols = [x for x in xt.columns.tolist() if re.match("^(?: +)?#.*$|Coupler|File|" +\
        "Host|Connected|Attached|Stopped|End|Unnamed|Good|Bad|Expired|Sensor" +\
        "|Missing|New", x) is None]
    xt = xt[cols]

    tzoff = re.sub('^(?:.*)?GMT(.[0-9]{2}).*$', '\\1', xt.columns[0])
    regex1 = '(.*?),([^\(]+)'
    regex2 = '([^\(]+)\(?([^\)]+)?'
    mch = [re.match(regex1, x) for x in xt.columns.tolist()]
    if not all(mch):
        mch = [re.match(regex2, x) for x in xt.columns.tolist()]
    headerPt1 = [re.sub(' ', '', x.group(1)) for x in mch]
    headerPt2 = [re.sub(' ', '', x.group(2)) for x in mch]

    # m = [re.sub(" ", "", x.split(",")[0]) for x in xt.columns.tolist()]
    # u = [x.split(",")[1].split(" ")[1] for x in xt.columns.tolist()]
    # tzoff = re.sub("GMT(.[0-9]{2}):([0-9]{2})", "\\1", u[0])
    logger_regex = ".*/\\w+_\\w+_[0-9]{4}-[0-9]{2}-[0-9]{2}_([A-Z]{2}" +\
        "(?:[0-9]+)?)(?:v[0-9]+)?\\.\\w{3}"
    ll = re.sub(logger_regex, "\\1", f)
    # ll = f.split("_")[3].split(".")[0].split("v")[0]
    inum = re.sub("[A-Z]{2}", "", ll)
    headerPt2Clean = [re.sub("\\ |\\/|°", "", x) for x in headerPt2[1:]]
    headerPt2Clean = [re.sub(r'[^\x00-\x7f]', r'', x) for x in headerPt2Clean] # get rid of unicode
    newcols = ['DateTime'] + [nme + unit for unit,
        nme in zip(headerPt2Clean, headerPt1[1:])]
    xt = xt.rename(columns=dict(list(zip(xt.columns.tolist(), newcols))))
    xt = xt.dropna(subset=['DateTime'])
    xt['DateTimeUTC'] = [dtparse.parse(x)-timedelta(hours=int(tzoff)) for x in xt.DateTime]
    # xt = xt.rename(columns={'HWAbsPreskPa':'WaterPres_kPa','HWTempC':'WaterTemp_C','HAAbsPreskPa':'AirPres_kPa','HATempC':'AirTemp_C',})
    if "_HW" in f:
        xt = xt.rename(columns={'AbsPreskPa':'WaterPres_kPa','TempC':'WaterTemp_C'})
    if "_HA" in f:
        xt = xt.rename(columns={'AbsPreskPa':'AirPres_kPa','TempC':'AirTemp_C'})
    if "_HD" in f:
        xt = xt.rename(columns={'TempC':'DOLoggerTemp_C'})
    if "_HP" in f:
        xt = xt.rename(columns={'TempC':'LightLoggerTemp_C'})
    if "_HC" in f:
        xt = xt.rename(columns={'TempC':'CondLoggerTemp_C'})
    xt.columns = [cc + inum for cc in xt.columns]
    cols = xt.columns.tolist()
    xx = xt[cols[-1:] + cols[1:-1]]

    return xx

def read_csci(f, gmtoff):

    # xt = pd.read_csv('~/Downloads/NC_ColeMill_2020-09-10_CS.csv', header=0, skiprows=[0,2,3])
    # gmtoff = -5
    try:
        xt = pd.read_csv(f, header=0, skiprows=[0,2,3])
    except:
        xt = pd.read_csv(f, header=0, skiprows=[0,2,3], sep='\t')

    #handle multiple potential date formats
    if re.match('^[0-9]{2}/[0-9]{1,2}/[0-9]{1,2} [0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}$', xt.TIMESTAMP.loc[1]):
        xt['DateTimeUTC'] = [datetime.strptime(x, '%y/%m/%d %H:%M:%S')-timedelta(hours=int(gmtoff)) for x in xt.TIMESTAMP]
    elif re.match('^[0-9]{2}/[0-9]{1,2}/[0-9]{1,2} [0-9]{1,2}:[0-9]{1,2}$', xt.TIMESTAMP.loc[1]):
        xt['DateTimeUTC'] = [datetime.strptime(x, '%y/%m/%d %H:%M')-timedelta(hours=int(gmtoff)) for x in xt.TIMESTAMP]
    else :
        xt['DateTimeUTC'] = [dtparse.parse(x)-timedelta(hours=int(gmtoff)) for x in xt.TIMESTAMP]

    cols = xt.columns.tolist()
    return xt[cols[-1:]+cols[1:-1]]

def read_manta(f, gmtoff):

    #manta has a weird custom of repeating two header rows every time the power
    #cycles. these additional headers get removed below.
    #this will fail if the first header row is incomplete. just tell users to
    #remove those rows when they see them

    xt = pd.read_csv(f, skiprows=[0]) #skip the first row that just has site name
    if 'Eureka' in xt.columns[0]:#if the wrong header row is first, replace it
        xt.columns = xt.loc[0].tolist()
    xt = xt[xt.DATE.str.contains('[0-9]+/[0-9]+/[0-9]{4}')] #drop excess header/blank rows
    xt['DateTime'] = xt['DATE'] + " " + xt['TIME']
    xt['DateTimeUTC'] = [dtparse.parse(x) - timedelta(hours=int(gmtoff)) \
        for x in xt.DateTime]
    xt.drop(["DATE","TIME","DateTime"], axis=1, inplace=True)
    xt = xt[[x for x in xt.columns.tolist() if " ." not in x and x != " "]]
    xt.columns = [re.sub("\/|%","",x) for x in xt.columns.tolist()]
    splitcols = [x.split(" ") for x in xt.columns.tolist()]
    xt.columns = [x[0]+"_"+x[-1] if len(x)>1 else x[0] for x in splitcols]
    cols = xt.columns.tolist()
    xt = xt.set_index('DateTimeUTC').apply(lambda x: pd.to_numeric(x, errors='coerce')).reset_index()
    return xt

def load_file(f, gmtoff, logger):
    filenamesNoV = session.get('filenamesNoV')

    #format data from file
    if "CS" in logger:
        xtmp = read_csci(f, gmtoff)
    elif "H" in logger:
        xtmp = read_hobo(f)
    elif "EM" in logger:
        xtmp = read_manta(f, gmtoff)
    else: #must be "XX"
        xtmp = pd.read_csv(f, parse_dates=[0])
        xtmp = xtmp.rename(columns={xtmp.columns.values[0]:'DateTimeUTC'})

    #get list of all filenames on record
    all_fnames = list(pd.read_sql('select distinct filename from upload',
        db.engine).filename)

    #see if this one is among them
    fn = re.sub(".*/(\\w+_\\w+_[0-9]{4}-[0-9]{2}-[0-9]{2}_[A-Z]{2}" +\
        "(?:[0-9]+)?)(?:v[0-9]+)?(\\.\\w{3})", "\\1\\2", f)

    if fn not in all_fnames:

        #find the last upload_id that was added to the database
        last_upID = pd.read_sql("select max(id) as m from upload", db.engine)
        last_upID = list(last_upID.m)

        #reset auto increment for upload table if necessary
        #if not last_upID[0]:
        #    db.engine.execute('alter table upload auto_increment=1')
        #    last_upID[0] = 0

        #find out what the next upload_id will be and update working list
        pending_upIDs = [i[1] for i in filenamesNoV]
        maxpend = max(pending_upIDs) if all([x is not None for x in pending_upIDs]) else -1
        upID = max(last_upID[0], maxpend) + 1
        filenamesNoV[filenamesNoV.index([fn, None])][1] = upID #update
        session['filenamesNoV'] = filenamesNoV

    else:

        #retrieve upload_id
        upID = pd.read_sql("select id from upload where filename='" +\
            fn + "'", db.engine)
        upID = list(upID.id)[0]

    #append column of upload_ids to df
    xtmp['upload_id'] = upID
    return xtmp

def load_multi_file(ff, gmtoff, logger):

    #get list of uploaded files with a particular logger extension
    f = [fi for fi in ff if "_" + logger in fi]
    if len(f) > 1:
        xx = [load_file(x, gmtoff, logger) for x in f]
        xx = reduce(lambda x, y: x.append(y), xx)
    else: # only one file for the logger, load it
        xx = load_file(f[0], gmtoff, logger)

    #clean up resultant df
    xx = wash_ts(xx)
    return xx

def sp_in(ff, gmtoff): # ff must be a list
    # read and munge files for a site and date

    logger_regex = ".*/\\w+_\\w+_[0-9]{4}-[0-9]{2}-[0-9]{2}_([A-Z]{2})" +\
        "(?:[0-9]+)?(?:v[0-9]+)?\\.\\w{3}"

    if len(ff) == 1: # only one file, load
        logger = re.sub(logger_regex, "\\1", ff[0])
        xx = load_file(ff[0], gmtoff, logger)
        xx = wash_ts(xx)
    else: # list by logger
        logger = list(set([re.sub(logger_regex, "\\1", f) for f in ff]))

        # if multiple loggers, map over loggers
        if len(logger) > 1:
            xx = [load_multi_file(ff, gmtoff, x) for x in logger]
            xx = reduce(lambda x,y: x.merge(y, how='outer', left_index=True,
                right_index=True), xx)

            #combine upoad_id cols into one
            upid_cols = xx.columns[xx.columns.str.contains('upload_id')]
            upid_cols = [xx.pop(i) for i in upid_cols] #remove upload id cols
            upid_col = reduce(lambda x, y: x.fillna(y), upid_cols)
            xx = pd.concat([xx, upid_col], axis=1) #put upid col last
            xx = xx.rename(columns={xx.columns.tolist()[-1]: 'upload_id'})

        else: #just one logger type being uploaded
            logger = logger[0]
            xx = load_multi_file(ff, gmtoff, logger)

    xx['upload_id'] = xx['upload_id'].astype(int)
    xx = xx.reset_index()

    return xx

def sp_in_lev(f):

    filenamesNoV = session.get('filenamesNoV')
    # print(os.stat(f).st_size)
    xx = pd.read_csv(f, parse_dates=[0])

    #get list of all filenames on record
    all_fnames = list(pd.read_sql('select distinct filename from upload',
        db.engine).filename)

    #see if this one is among them
    fn = re.sub(".*/(\\w+_\\w+_[0-9]{4}-[0-9]{2}-[0-9]{2})" +\
        "(?:v[0-9]+)?(\\.\\w{3})", "\\1\\2", f)

    if fn not in all_fnames:

        #find out what the next upload_id will be and update session variable
        last_upID = pd.read_sql("select max(id) as m from upload", db.engine)
        last_upID = list(last_upID.m)[0]
        filenamesNoV[0][1] = last_upID + 1

        #append column of upload_ids to df
        xx['upload_id'] = last_upID + 1

    else:

        #retrieve upload_id
        upID = pd.read_sql("select id from upload where filename='" +\
            fn + "'", db.engine)
        upID = list(upID.id)[0]

        #append column of upload_ids to df
        xx['upload_id'] = upID

    #if not last_upID[0]: #reset auto increment for upload table if necessary
    #    db.engine.execute('alter table upload auto_increment=1')
    #    last_upID[0] = 0

    xx = wash_ts(xx).reset_index()

    return xx

def wash_ts(x):

    cx = list(x.select_dtypes(include=['datetime64']).columns)
    dt_col = [x.pop(i) for i in cx] #remove datetime col(s)

    if len(cx) > 1: #more than one dataset, so merge datetime cols
        dt_col = reduce(lambda x, y: x.fillna(y), dt_col)
    else:
        dt_col = dt_col[0]

    x = pd.concat([dt_col, x], axis=1) #put datetime col first
    x = x.rename(columns={x.columns.tolist()[0]:'DateTime_UTC'})

    #average and bin values by 15 min increments
    x = x.set_index("DateTime_UTC").sort_index().apply(lambda x: pd.to_numeric(x,
        errors='coerce')).resample('15Min').mean().dropna(how='all')

    return x

def panda_usgs(x,jsof):
    ts = jsof['value']['timeSeries'][x]
    usgst = pd.read_json(json.dumps(ts['values'][0]['value']))
    vcode = ts['variable']['variableCode'][0]['value']

    if vcode=='00060': # discharge
        colnm = 'USGSDischarge_m3s'
        if usgst.empty: #return empty df in dict
            out = {ts['sourceInfo']['siteCode'][0]['value']:
                pd.DataFrame({'DateTime_UTC':[],
                colnm:[]}).set_index(["DateTime_UTC"])}
            return out
        else:
            usgst.value = usgst.value / 35.3147
    else:
        colnm = 'USGSLevel_m'
        if usgst.empty:
            out = {ts['sourceInfo']['siteCode'][0]['value']:
                pd.DataFrame({'DateTime_UTC':[],
                colnm:[]}).set_index(["DateTime_UTC"])}
            return out
        else:
            usgst.value = usgst.value / 3.28084

    # usgst['site'] = ts['sourceInfo']['siteCode'][0]['value'] # site code
    out = {ts['sourceInfo']['siteCode'][0]['value']:usgst[['dateTime',
        'value']].rename(columns={'dateTime':'DateTime_UTC',
        'value':colnm}).set_index(["DateTime_UTC"])}
    return out

def get_usgs(regionsite, startDate, endDate, vvv=['00060', '00065']):
        # usgs='05406457'; startDate='2019-01-01'; endDate='2019-12-31'
        # regionsite=['WI_BEC']
        # regionsite = sites;startDate= min(xx.DateTime_UTC).strftime("%Y-%m-%d")
        #     endDate=max(xx.DateTime_UTC).strftime("%Y-%m-%d");vvv= ['00065']
    # regionsite is a list
    # vvv is a list of variable codes
    #00060 is cfs, discharge; 00065 is feet, height
    xs = pd.read_sql('select id, region, site, name, latitude, ' +\
        'longitude, datum, usgs, addDate, embargo, site.by, contact, contactEmail ' +\
        'from site', db.engine)
    xs['regionsite'] = xs["region"].map(str) + "_" + xs["site"]
    # for each region site...
    sitex = xs.loc[xs.regionsite.isin(regionsite)].usgs.tolist()
    sitedict = dict(list(zip(sitex, regionsite)))
    sitex = [x for x in sitex if x is not None]
    usgs = ",".join(sitex)
    #lat,lng = sitex.loc[:,['latitude','longitude']].values.tolist()[0]
    if(len(sitex) == 0 or usgs is None):
        return []
    vcds = ",".join(vvv)
    #request usgs water service data in universal time (T01:15 makes it line up with our datasets)
    url = "https://nwis.waterservices.usgs.gov/nwis/iv/?format=json&sites=" + \
        usgs + "&startDT=" + startDate + "T01:15Z&endDT=" + endDate + \
        "T23:59Z&parameterCd=" + vcds + "&siteStatus=all"
    r = requests.get(url)
    print(r.status_code)
    if r.status_code != 200:
        return ['USGS_error']
    xf = r.json()
    xx = [panda_usgs(x, xf) for x in range(len(xf['value']['timeSeries']))]

    if type(xx) == list and len(xx) == 0:
        xx = pd.DataFrame(columns = ['region', 'site', 'DateTime_UTC', 'variable',
            'value', 'flagtype', 'flagcomment'])
        return xx

    xoo = []
    try:
        for s in sitex:
            x2 = [list(k.values())[0] for k in xx if list(k.keys())[0]==s]
            x2 = reduce(lambda x,y: x.merge(y,how='outer',left_index=True,right_index=True), x2)
            x2.index = pd.to_datetime(x2.index, utc=True)
            x2 = x2.sort_index().apply(lambda x: pd.to_numeric(x, errors='coerce')).resample('15Min').mean()
            x2['site']=sitedict[s]
            xoo.append(x2.reset_index())

        xx = pd.concat(xoo)
        xx = xx.set_index(['DateTime_UTC','site'])
        xx.columns.name='variable'
        xx = xx.stack()
        xx.name="value"
        xx = xx.reset_index()
        xx[['region','site']] = xx['site'].str.split("_",expand=True)

        return xx[['DateTime_UTC','region','site','variable','value']]

    except:
        return ['USGS_error:' + usgs]

def authenticate_sites(sites, user=None, token=None):

    ss = []
    for site in sites:
        r, s = site.split("_")
        ss.append("(region='" + r + "' and site='" + s + "') ")

    #get user id (if necessary) and sites they have access to
    qs = "or ".join(ss)
    xx = pd.read_sql("select region, site, embargo, addDate, site.by from site where " + qs,
        db.engine)

    if token is not None:
        tt = pd.read_sql("select * from user where token='" + token + "'",
            db.engine)
        if(len(tt) == 1):
            user = str(tt.id[0])
            auth_sites = tt.qaqc[0].split(',')
    elif user is not None:
        tt = pd.read_sql("select qaqc from user where id='" +\
            str(user) + "';", db.engine)
        auth_sites = tt.qaqc[0].split(',')
    else:
        pass

    #public and user_authed are pandas series by which to logically index xx
    public = [(datetime.utcnow()-x).days+1 for x in xx['addDate']] > xx['embargo']*365

    if user is not None: # return public sites and authenticated sites
        user_authed = pd.Series(sites[0] in auth_sites)
        xx = xx[public | (xx['by']==int(user)) | user_authed]
    else: # return only public sites
        xx = xx[public]

    return [x[0] + "_" + x[1] for x in zip(xx.region, xx.site)]

def generate_confirmation_token(email):
    serializer = URLSafeTimedSerializer(app.config['SECRET_KEY'])
    return serializer.dumps(email, salt=app.config['SECURITY_PASSWORD_SALT'])

def confirm_token(token, expiration=3600*24): # expires in one day
    serializer = URLSafeTimedSerializer(app.config['SECRET_KEY'])
    try:
        email = serializer.loads(token,
            salt=app.config['SECURITY_PASSWORD_SALT'],
            max_age=expiration)
    except:
        return False
    return email

def zipfile_listdir_recursive(dir_name):

    fileList = []
    for file in os.listdir(dir_name):
        dirfile = os.path.join(dir_name, file)

        if os.path.isfile(dirfile):
            fileList.append(dirfile)
        elif os.path.isdir(dirfile):
            fileList.extend(zipfile_listdir_recursive(dirfile))

    return fileList

########## PAGES
@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'GET':
        return render_template('register.html')

    try:
        user = User(request.form['username'], request.form['password'], request.form['email'])
        db.session.add(user)
        db.session.commit()
        flash('User successfully registered', 'alert-success')

        return redirect(url_for('login'))

    except sqlalchemy.exc.IntegrityError as e:
        if 'email' in e[0]:
            flash('Error: Email already in use.', 'alert-warning')
        elif 'username' in e[0]:
            flash('Error: Username already in use.', 'alert-warning')
        else:
            flash('Unknown error. Please try again.', 'alert-warning')

        return redirect(url_for('register'))

@app.route('/resetpass_loggedin', methods=['GET', 'POST'])
@login_required
def resetpass_loggedin():

    if request.method == 'GET':
        return render_template('resetpass.html', email=current_user.email)

    try:
        user = User.query.filter(User.email == current_user.email).first_or_404()
    except: #this should never happen
        flash("We couldn't find an account with that email.", 'alert-danger')
        return render_template('reset.html', email=current_user.email)

    if request.form['password'] != request.form['password2']:
        flash('The passwords do not match.', 'alert-danger')
        return redirect(url_for('resetpass_loggedin'))

    user.password = generate_password_hash(request.form['password'])
    db.session.add(user)
    db.session.commit()

    flash('Password successfully reset.', 'alert-success')

    regdate = current_user.registered_on.strftime('%Y-%m-%d')

    return render_template('account.html', username=current_user.username,
        token=current_user.token, email=current_user.email,
        regdate=regdate, id=current_user.get_id(),
        authsites=current_user.qaqc_auth())

@app.route('/lost_pass', methods=['GET', 'POST'])
def lostpass():

    if request.method == 'GET':
        return render_template('reset.html')

    email = request.form.get('email')
    email2 = request.form.get('email2')

    #tests
    if email != email2:
        flash('The email addresses do not match.', 'alert-danger')
        return redirect(url_for('lostpass'))
    try:
        user = User.query.filter(User.email == email).first_or_404()
    except:
        flash("We couldn't find an account with that email.", 'alert-danger')
        return redirect(url_for('lostpass'))

    token = generate_confirmation_token(email)
    reset_url = url_for('lostpass_reset', token=token, _external=True)

    try:
        gmail_pw = cfg.GRDO_GMAIL_PW

        #compose email
        msg = MIMEMultipart()
        msg.attach(MIMEText("<p>Follow this link to reset your StreamPULSE " +\
            "password:<br><a href='" + reset_url + "'>" + reset_url + "</a></p>" +\
            "<p>The link is valid for 24 hours.</p>", 'html'))
        msg['Subject'] = 'StreamPULSE Password Reset'
        msg['From'] = 'grdouser@gmail.com'
        # msg['From'] = 'donotreply@streampulse.org'
        msg['To'] = email

        #log in to gmail, send email
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.ehlo()
        server.starttls()
        server.login("grdouser@gmail.com", gmail_pw)
        server.sendmail('grdouser@gmail.com', [email],
            msg.as_string())
        server.quit()

        flash("Email sent.", 'alert-success')
        return redirect(url_for('login'))

    except:
        msg = Markup("There has been an error. Please <a href=" +\
            "'mailto:vlahm13@gmail.com' class='alert-link'>notify us</a> " +\
            "so that we can resolve the issue.")
        flash(msg, 'alert-danger')
        return redirect(url_for('lostpass'))

@app.route('/resetpass/<string:token>', methods=['GET', 'POST'])
def lostpass_reset(token):

    try:
        email = confirm_token(token)
        user = User.query.filter(User.email == email).first_or_404()
    except:
        flash('The confirmation link is invalid or has expired.',
            'alert-danger')
        return redirect(url_for('lostpass'))

    if request.method == 'GET':
        return render_template('resetpass.html', email=email)

    # posting new password
    if request.form['password'] != request.form['password2']:
        flash('The passwords do not match.', 'alert-danger')
        return redirect(request.url)

    user.password = generate_password_hash(request.form['password'])
    db.session.add(user)
    db.session.commit()

    flash('Successfully reset password; please log in.', 'alert-success')

    return redirect(url_for('login'))

@app.route('/login', methods=['GET','POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')
    username = request.form['username']
    password = request.form['password']
    registered_user = User.query.filter_by(username=username).first()
    if registered_user is None:
        flash('Username is invalid' , 'alert-danger')
        return redirect(url_for('login'))
    if not registered_user.check_password(password):
        flash('Password is invalid', 'alert-danger')
        return redirect(url_for('login'))
    login_user(registered_user)
    flash('Logged in successfully', 'alert-success')
    return redirect(request.args.get('next') or url_for('index'))

@app.route('/logout')
def logout():
    logout_user()
    return redirect(url_for('index'))

# @app.route('/test')
# def tst():
#     return render_template('test.html')

@app.route('/account')
@login_required
def account():

    regdate = current_user.registered_on.strftime('%Y-%m-%d')
    user_id = current_user.get_id()
    sens_up = pd.read_sql("select distinct filename from upload where user_id='" +\
        str(user_id) + "';", db.engine).filename.tolist()
    grab_up = pd.read_sql("select distinct filename from grabupload where user_id='" +\
        str(user_id) + "';", db.engine).filename.tolist()

    return render_template('account.html', username=current_user.username,
        token=current_user.token, email=current_user.email,
        regdate=regdate, id=user_id, sensor_uploads=sens_up,
        grab_uploads=grab_up, authsites=current_user.qaqc_auth())

@app.route('/email_change')
@login_required
def email_change():

    return render_template('email_change.html', email=current_user.email)

@app.route('/email_change_submit', methods=['POST'])
@login_required
def email_change_submit():

    e1 = request.form.get('email1')
    e2 = request.form.get('email2')
    former_email = current_user.email
    emailList = pd.read_sql('select distinct contactEmail from site;',
        db.engine).contactEmail.tolist()

    if e1 != e2:
        flash('New email addresses do not match.', 'alert-danger')
    elif e1 in emailList:
        flash('That email address is already in use.', 'alert-danger')
    else:
        u = User.query.filter(User.email == former_email).one()
        u.email = e1 #this updates current_user.email

        s = Site.query.filter(Site.contactEmail == former_email).all()
        for rec in s:
            rec.contactEmail = e1
            db.session.add(rec)

        db.session.commit()

        flash('Successfully updated email address.', 'alert-success')

    return render_template('email_change.html', email=current_user.email)

@app.route('/')
@app.route('/index')
def index():

    spstats = pd.read_csv('scheduled_scripts/homepage_counts/homepage_counts.csv')

    # nusers = spstats.nusers[0]
    nusers = pd.read_sql("select count(id) as n from user", db.engine).n[0]
    # nsites = spstats.nsites[0]
    nsites = pd.read_sql("select count(id) as n from site", db.engine).n[0]
    nobs = spstats.nobs[0]

    return render_template('index.html', nobs="{:,}".format(nobs),
        nuse=nusers, nsit=nsites)

@app.route('/sitelist')
def sitelist():

    #pull in all site data
    sitedata = pd.read_sql('select region as Region, site as Site, name as ' +\
        'Name, latitude as Lat, longitude as Lon, datum as `Geodetic datum`, contact as Contact, ' +\
        'contactEmail as Email, usgs as `USGS gage`, `by`,' +\
        'embargo as `Embargo (days)`, addDate, ' +\
        'firstRecord as `First record`, lastRecord as `Last record`,' +\
        'variableList as Variables from site;',
        db.engine)

    #calculate remaining embargo days
    timedeltas = pd.Series([datetime.utcnow() - x for x in sitedata.addDate])
    days_past = timedeltas.map(lambda x: int(x.total_seconds() / 60 / 60 / 24))
    sitedata['Embargo (days)'] = sitedata['Embargo (days)'] * 365 - days_past
    sitedata.loc[sitedata['Embargo (days)'] <= 0, 'Embargo (days)'] = 0

    #format date range and varlist
    sitedata['First record'] = sitedata['First record'].dt.strftime('%Y-%m-%d')
    sitedata['Last record'] = sitedata['Last record'].dt.strftime('%Y-%m-%d')

    pd.set_option('display.max_colwidth', 500)
    core_variables = ['DO_mgL', 'satDO_mgL', 'DOsat_pct', 'WaterTemp_C',
        'Depth_m', 'Level_m', 'Discharge_m3s', 'Light_PAR', 'Light_lux']

    varcells = []
    for x in sitedata.Variables:
        if x is None:
            varcells.append(x)
        else:
            var_arr = np.asarray(x.split(','))
            isCore = np.in1d(var_arr, core_variables)
            core = var_arr[isCore]
            not_core = var_arr[~isCore]
            if any(core):
                cc = [core_variables.index(x) if x in core_variables \
                    else -1 for x in core] #equiv of pd.match
                core = core[np.argsort(cc)]
            not_core.sort()
            var_arr = ', '.join(np.concatenate((core, not_core)))
            varcells.append(var_arr)

    for i in range(len(varcells)):
        if varcells[i] is None:
            varcells[i] = '-'

    sitedata.Variables = varcells

    #obscure email addresses
    sitedata.Email = sitedata.Email.str.replace('@', '[at]')
    if not current_user.is_authenticated:
        emailless = sitedata.Email == '-'
        sitedata.loc[~emailless, 'Email'] = 'Log in to view'
        sitedata.loc[~emailless, 'Contact'] = 'Log in to view'

    #add column for data source
    sitedata['by'] = sitedata['by'].apply(str)
    sitedata['by'] = sitedata['by'].replace(r'^(?!\-900|\-902)\-?[0-9]+$',
        'sp', regex=True)
    title_mapping = {'-900': 'NEON', '-902': 'USGS (Powell Center)', 'sp': 'StreamPULSE'}
    sitedata['by'] = sitedata['by'].map(title_mapping)
    sitedata.rename(columns={'by':'Source'}, inplace=True)

    #additional arranging and modification of data frame
    sitedata = sitedata.drop(['addDate'], axis=1)
    sitedata = sitedata[['Region', 'Site', 'Name', 'Lat', 'Lon', 'Geodetic datum', 'Source',
        'Contact', 'Email', 'Embargo (days)', 'USGS gage', 'First record',
        'Last record', 'Variables']]
    sitedata = sitedata.fillna('-').sort_values(['Region', 'Site'],
        ascending=True)

    header = list(sitedata.columns)
    sitedata = sitedata.to_json(orient='values', date_format='iso')

    return render_template('sitelist.html', sitedata=sitedata, header=header)

@app.route('/upload_choice')
def upload_choice():
    return render_template('upload_choice.html')

@app.route('/download_choice')
def download_choice():
    return render_template('download_choice.html')

@app.route('/download_bulk')
def download_bulk():

    bulk_files = os.listdir(app.config['BULK_DNLD_FOLDER'])
    bulk_sizes = [os.path.getsize('../bulk_download_files/' + b) for b in bulk_files]
    # for i in xrange(len(bulk_sizes)):
    #     if bulk_sizes[i] < 1048576:
    #         bulk_sizes[i] = str(round(bulk_sizes[i] / 1024, 2)) + ' kB'
    #     elif bulk_sizes[i] < 1073741824 and bulk_sizes[i] >= 1048576:
    #         bulk_sizes[i] = str(round(bulk_sizes[i] / 1048576, 2)) + ' MB'
    #     else:
    #         bulk_sizes[i] = str(round(bulk_sizes[i] / 1073741824, 2)) + ' GB'

    bulk_dict = dict(list(zip(bulk_files, bulk_sizes)))


    #all files must be present or an error will arise during rendering
    return render_template('download_bulk.html', bulk_file_sizes=bulk_dict)

# @app.route('/pipeline1')
# def pipeline1():
#
#     return render_template('pipeline1.html')

@app.route('/viz_choice')
def viz_choice():
    return render_template('viz_choice.html')

@app.route('/viz_diag')
def viz_diag():
    return render_template('viz_diag.html')

@app.route('/series_upload', methods=['GET', 'POST'])
@login_required
def series_upload():

    if request.method == 'POST':

        # replace = False if request.form.get('replace') is None else True
        if request.form.get('replaceRecords') is not None:
            replace = 'records'
        elif request.form.get('replaceFile') is not None:
            replace = 'file'
        else:
            replace = 'no'

        #checks
        if 'file' not in request.files:
            flash('No file specified.','alert-danger')
            return redirect(request.url)
        ufiles = request.files.getlist("file")
        ufnms = [x.filename for x in ufiles]

        # ufnms = ['SR_GG_2017-12-22_XX.csv','SR_G-f_2017-12-22_XX.csv']
        # f=ufnms[0]
        # f = 'ss d_-d'
        if len(ufnms[0]) == 0:
            flash('No files selected.','alert-danger')
            return redirect(request.url)

        # fsizes = []
        # for x in ufiles:
        #     x.save('../spdumps/' + x.filename)
        #     fsize = os.stat('../spdumps/' + x.filename).st_size
        #     print(fsize)
        #     fsizes.append(fsize)
        #     os.remove('../spdumps/' + x.filename)
        # if sum(fsizes) > 5000000:
        #     flash('Total size of selected file(s) was ' +\
        #         str(round(sum(fsizes) / 1000000, 1)) +\
        #         ' MB, but must not exceed 5 MB.' +\
        #         ' Please separate and/or subdivide your file(s).',
        #         'alert-danger')
        #     return redirect(request.url)

        #get list of all files in spupload directory
        upfold = app.config['UPLOAD_FOLDER']
        ld = os.listdir(upfold)

        #check names of uploaded files
        core_regex = "^[A-Z]{2}_(.*)_[0-9]{4}-[0-9]{2}-[0-9]{2}_[A-Z]{2}" +\
            "(?:[0-9]+)?.[a-zA-Z]{3}$"
        lev_regex = "^[A-Z]{2}_(.*)_[0-9]{4}-[0-9]{2}-[0-9]{2}.csv$"

        for f in ufnms:
            core_match = re.match(core_regex, f)
            lev_match = re.match(lev_regex, f)

            if core_match is not None:
                site_match = core_match.group(1)
                illegal_match = re.search('([-_ ])', site_match)
                if illegal_match is not None:
                    illegal = illegal_match.group(0)
                    flash('Illegal character "' + illegal +\
                    '" found in site name.', 'alert-danger')
                    return redirect(request.url)
            elif lev_match is not None:
                site_match = lev_match.group(1)
                illegal_match = re.search('([-_ ])', site_match)
                if illegal_match is not None:
                    illegal = illegal_match.group(0)
                    flash('Illegal character "' + illegal +\
                    '" found in site name.', 'alert-danger')
                    return redirect(request.url)
            else:
                flash('Filename "' + f + '" does not match the required format.',
                    'alert-danger')
                return redirect(request.url)

        if replace != 'no': #if user has checked either replacement box
            if len(ufiles) > 1:
                flash('Please upload only one revision file at a time.',
                    'alert-danger')
                return redirect(request.url)

        else:

            #get lists of new and existing files, filter uploaded files by new
            new = [fn not in ld for fn in ufnms]
            existing = [ufnms[f] for f in range(len(ufnms)) if not new[f]]
            ufiles = [ufiles[f] for f in range(len(ufiles)) if new[f]]
            ufnms = [ufnms[f] for f in range(len(ufnms)) if new[f]]

            if not ufnms: #if no files left in list
                if len(existing) == 1:
                    msgc = ['This file has', 'it.']
                else:
                    msgc = ['These files have', 'one of them.']

                flash(msgc[0] + ' already been ' +\
                    'uploaded. Check a revision box if you want to revise ' +\
                    msgc[1], 'alert-danger')
                return redirect(request.url)

            if existing: #if some uploaded files aready exist

                if len(existing) > 1:
                    insrt1 = ('These files', 'exist'); insrt2 = 'these files (one at a time)'
                if len(existing) == 1:
                    insrt1 = ('This file', 'exists'); insrt2 = 'this file'

                flash('%s already %s: ' % insrt1 + ', '.join(existing) +\
                    '. You may continue to upload the other file(s), or click "Cancel" at the bottom of ' +\
                    'this page to go back and replace %s by checking the box.'
                    % insrt2, 'alert-warning')

        #get list of sites. can only be one per upload
        site = list(set([x.split("_")[0] + "_" + x.split("_")[1] for
            x in ufnms]))
        if len(site) > 1:
            flash('Please only select data from a single site.','alert-danger')
            return redirect(request.url)

        # UPLOAD locally and to sciencebase
        filenames = []
        fnlong = []
        filenamesNoV = [] #for filenames without version numbers, and upload IDs
        fsizes = []

        for file in ufiles:
            if file and allowed_file(file.filename):

                #clean filename, get version num if applicable
                filename = secure_filename(file.filename)
                filenamesNoV.append([filename, None])
                ver = len([x for x in ld if filename.split(".")[0] in x])

                #the versioning system for leveraged sites ignores
                #logger extensions when assigning v numbers.
                #the expression below can be used to fix this, but
                #then you'll have to update all leveraged site files on record.
                # mch = re.match(
                    # "([A-Z]{2}_.*_[0-9]{4}-[0-9]{2}-[0-9]{2}(?:_[A-Z]{2})?[0-9]?)(?:v\d+)?(.[a-zA-Z]{3})",
                    # filename).groups()

                # rename files if existing, add version number
                fup = os.path.join(upfold, filename)
                if replace and ver > 0: # need to add version number to file
                    fns = filename.split(".")
                    filename = fns[0] + "v" + str(ver+1) + "." + fns[1]
                    fup = os.path.join(upfold, filename)

                file.save(fup) # save locally
                fsizes.append(os.stat(fup).st_size)

                # sb.upload_file_to_item(sbupf, fup) #broken (need to get credentials)

                filenames.append(filename) #fname list passed on for display
                fnlong.append(fup) #list of files that get processed
            else: #name may be messed up or something else could have gone wrong
                log_message('E002')
                msg = Markup('Error 002. Possibly illegal filename. If problem' +\
                    ' persists, <a href="mailto:vlahm13@gmail.com" ' +\
                    'class="alert-link">email Mike Vlah</a> with the error ' +\
                    'number and a copy of the file you tried to upload.')
                flash(msg, 'alert-danger')

                return redirect(request.url)

        if sum(fsizes) > 5000000:
            flash('Total size of selected file(s) was ' +\
                str(round(sum(fsizes) / 1000000, 1)) +\
                ' MB, but must not exceed 5 MB.' +\
                ' Please separate and/or subdivide your file(s).',
                'alert-danger')
            [os.remove(x) for x in fnlong]
            return redirect(request.url)

        #persist filenames across requests
        session['filenamesNoV'] = filenamesNoV
        session['fnlong'] = fnlong

        #make sure LOGGERID formats are valid
        for i in range(len(filenamesNoV)):
            logger = re.search(".*\\d{4}-\\d{2}-\\d{2}(_[A-Z]{2})?" +\
                "(?:[0-9]+)?\\.\\w{3}", filenamesNoV[i][0]).group(1)

            if logger: #if there is a LOGGERID format
                logger = logger[1:len(logger)] #remove underscore

                if logger not in ['CS','HD','HW','HA','HP','HC','EM','XX']:
                    flash('"' + str(logger) + '" is an invalid LOGGERID. ' +\
                        'See formatting instructions.', 'alert-danger')
                    [os.remove(f) for f in fnlong]
                    return redirect(request.url)

        # PROCESS the data and save as tmp file
        try:
            if site[0] in core.index.tolist():
                gmtoff = core.loc[site].GMTOFF[0]
                # fnlong = ['/home/mike/git/streampulse/server_copy/spuploads/NC_ColeMill_2020-10-13_CS.dat']
                # gmtoff = -5
                x = sp_in(fnlong, gmtoff)
            elif site[0] in pseudo_core.index.tolist():
                gmtoff = pseudo_core.loc[site].GMTOFF[0]
                x = sp_in(fnlong, gmtoff)
            else:
                if len(fnlong) > 1:
                    flash('To upload multiple files at a time, or to upload raw logger ' +\
                        'data, you must first supply us with some information. ' +\
                        'See "Enabling raw logger file upload" in the general ' +\
                        'instructions below.', 'alert-danger')
                    [os.remove(f) for f in fnlong]
                    return redirect(request.url)
                x = sp_in_lev(fnlong[0])

            #save combined input files to a temporary csv
            tmp_file = site[0] + "_" +\
                binascii.hexlify(os.urandom(6)).decode('utf-8')
            out_file = os.path.join(upfold, tmp_file + ".csv")
            x.to_csv(out_file, index=False)

            #get data to pass on to confirm columns screen
            columns = x.columns.tolist() #col names
            columns.remove('upload_id')
            rr, ss = site[0].split("_") #region and site
            coldict = pd.read_sql("select * from cols where region='" + rr +\
                "' and site='" + ss + "'", db.engine)
            cdict = dict(list(zip(coldict['rawcol'], coldict['dbcol']))) #varname mappings
            ldict = dict(list(zip(coldict['rawcol'], coldict['level']))) #level mappings
            ndict = dict(list(zip(coldict['rawcol'], coldict['notes']))) #note mappings
            notificationEmail = pd.read_sql("select email from notificationemail" +\
                " where region='" + rr + "' and site='" + ss + "'", db.engine)
            notificationEmail = notificationEmail.email.tolist()
            if notificationEmail:
                notificationEmail = notificationEmail[0]
            else:
                notificationEmail = ''

        except Exception as e:

            tb = traceback.format_exc()

            try:
                # [os.remove(f) for f in fnlong]
                for f in fnlong:
                    fn = re.search('/([A-Za-z0-9\._\-]+)$', f).group(1)
                    ferr = os.path.join(app.config['ERRFILE_FOLDER'], fn)
                    os.rename(f, ferr)
            except:
                pass

            error_details = '\n\nfn_to_db: ' + ', '.join(filenames) +\
                '\nreplace: ' + replace + '\n\n'

            errno = 'E001'
            msg = Markup("Error 001. StreamPULSE development has been notified. " +\
                "If you're uploading raw logger data from a" +\
                " new site, you'll have to supply us with some information first." +\
                " See the general instructions below.")
            flash(msg, 'alert-danger')

            full_error_detail = tb + error_details
            log_exception(errno, full_error_detail)
            email_msg(errno + '\n' + full_error_detail, 'sp err', 'streampulse.info@gmail.com')
            # for file in ufiles:
            #     filename = secure_filename(file.filename)
            #     ferr = os.path.join(app.config['ERRFILE_FOLDER'], filename)
            #     file.save(ferr)

            return redirect(request.url)

        # check if existing site
        try:
            allsites = pd.read_sql("select concat(region, '_', site) as" +\
                " sitenm from site", db.engine).sitenm.tolist()
            existing = True if site[0] in allsites else False

            #go to next webpage
            flash("Please double check your variable name matching.",
                'alert-warning')

            matched_vars = [cdict[x] for x in columns if x in cdict.keys()]
            unmatched_vars = [x for x in variables if x not in matched_vars]
            unmatched_vars = sorted(unmatched_vars, key=lambda x: x.replace('_', '0').lower())

            return render_template('upload_columns.html', filenames=filenames,
                columns=columns, tmpfile=tmp_file, variables=variables,
                existing=existing, sitenm=site[0], replace=replace,
                cdict=cdict, ldict=ldict, ndict=ndict,
                unmatched_vars = unmatched_vars,
                notificationEmail=notificationEmail)

        except Exception as e:
            [os.remove(f) for f in fnlong]
            tb = traceback.format_exc()
            tb = tb + replace + notificationEmail + site[0] + filenames[0] + str(existing) +\
                str(cdict) + str(ldict) + str(ndict) + str(variables)
            log_exception('E004', tb)
            msg = Markup('Error 004. Check for unusual characters in your ' +\
                'column names (degree symbol, etc.). If problem persists, ' +\
                '<a href="mailto:michael.vlah@duke.edu"' +\
                ' class="alert-link">email StreamPULSE development</a> ' +\
                'with the error number and a copy of the file you tried to upload.')
            flash(msg, 'alert-danger')
            return redirect(request.url)

    if request.method == 'GET': #when first visiting the series upload page
        # xx = pd.read_sql("select distinct region, site from data", db.engine)
        # vv = pd.read_sql("select distinct variable from data",
        #     db.engine)['variable'].tolist()
        xx = pd.read_sql("select distinct region, site from site", db.engine)
        sites = [x[0] + "_" + x[1] for x in zip(xx.region, xx.site)]
        sitedict = sorted([getsitenames(x) for x in sites],
            key=lambda tup: tup[1])
        return render_template('series_upload.html', sites=sitedict,
            variables=variables[1:])

@app.route('/grab_upload', methods=['GET', 'POST'])
@login_required
def grab_upload():
    if request.method == 'GET': #occurs when you first visit the page

        #remove the last uploaded file if the upload did not complete
        try:
            fnlong = session.get('fnlong')
            upload_complete = session.get('upload_complete')

            if not upload_complete:
                os.remove(fnlong)

        except:
            pass

        return render_template('grab_upload.html')

    if request.method == 'POST': #invoked when you interact with the page

        try:

            replace = False if request.form.get('replaceG') is None else True

            #checks
            if 'fileG' not in request.files:
                flash('File missing or unreadable','alert-danger')
                return redirect(request.url)

            ufile = request.files.getlist("fileG") #list helps with following tests
            ufnm = [x.filename for x in ufile]

            if len(ufnm) > 1:
                flash('Please upload one file at a time.','alert-danger')
                return redirect(request.url)
            if len(ufnm[0]) == 0:
                flash('No files selected.','alert-danger')
                return redirect(request.url)

            #list format no longer uUserul; extract items
            ufile = ufile[0]
            ufnm = ufnm[0]

            #check name of uploaded file
            try:
                re.match("^[A-Z]{2}_[0-9]{4}-[0-9]{2}-[0-9]{2}.csv$", ufnm).group(0)
            except:
                flash('Please follow the file naming instructions.', 'alert-danger')
                return redirect(request.url)

            #get list of all files in spgrab directory
            upfold = app.config['GRAB_FOLDER']
            ld = os.listdir(upfold)

            if not replace and ufnm in ld:
                flash("This filename has already been uploaded. Check the " +\
                    "box if you want to replace this file's contents in the" +\
                    "database.",
                    'alert-danger')
                return redirect(request.url)

            #clean filename, generate version number
            filename = secure_filename(ufnm)
            filenameNoV = filename
            ver = len([x for x in ld if filename.split(".")[0] in x])

            #add version number to file if this filename already exists
            fnlong = os.path.join(upfold, filename)
            if replace and ver > 0:
                fns = filename.split(".")
                filename = fns[0] + "v" + str(ver+1) + "." + fns[1]
                fnlong = os.path.join(upfold, filename)

        except Exception as e:
            tb = traceback.format_exc()
            log_exception('E003', tb)
            msg = Markup('Error 003. Please <a href="mailto:michael.vlah@duke.edu"' +\
                ' class="alert-link">email StreamPULSE development</a> ' +\
                'with the error number and a copy of the file you tried to upload.')
            flash(msg, 'alert-danger')

            return redirect(request.url)

        #more checks
        try:
            x = pd.read_csv(ufile, parse_dates=[0])
            xcols = x.columns

        except:
            flash("Could not parse CSV file. Make sure it's in standard " +\
                "format and that there are no uncommon symbols, like degrees.",
                'alert-danger')
            return redirect(request.url)

        #write check for proper UTC format

        if xcols[0] != 'DateTime_UTC':
            flash("First column must contain datetimes in UTC, formatted as " +\
                '"YYYY-MM-DD HH:MM:SS". Its name ' +\
                'must be "DateTime_UTC".', 'alert-danger')
            return redirect(request.url)

        if xcols[1] != 'Sitecode':
            flash('Second column must contain sitecodes and be named ' +\
                '"Sitecode".', 'alert-danger')
            return redirect(request.url)

        try:

            #get list of all filenames on record
            all_fnames = list(pd.read_sql('select distinct filename from grabupload',
                db.engine).filename)

            #get data to pass on to confirm columns screen
            columns = x.columns.tolist() #col names
            columns = [c for c in columns if c not in
                ['DateTime_UTC','Sitecode']]
            ureg = filename.split('_')[0]
            usites = list(x.Sitecode)

            if any([re.search('([-_ ])', s) is not None for s in set(usites)]):
                flash('Illegal character (dash, space, or underscore) found ' +\
                    'in at least one site name.', 'alert-danger')
                return redirect(request.url)

            urs = [ureg + '_' + s for s in usites]
            coldict = pd.read_sql("select * from grabcols where site in ('" +\
                "', '".join(usites) + "') and region='" + ureg + "';",
                db.engine)
            cdict = dict(list(zip(coldict['rawcol'], coldict['dbcol']))) #varname mappings
            mdict = dict(list(zip(coldict['rawcol'], coldict['method']))) #method mappings
            wdict = dict(list(zip(coldict['rawcol'], coldict['write_in']))) #more method mappings
            adict = dict(list(zip(coldict['rawcol'], coldict['addtl']))) #additional mappings

        except Exception as e:
            tb = traceback.format_exc()
            log_exception('E006', tb)
            msg = Markup('Error 006. Please <a href="mailto:michael.vlah@duke.edu"' +\
                ' class="alert-link">email StreamPULSE development</a> ' +\
                'with the error number and a copy of the file you tried to upload.')
            flash(msg, 'alert-danger')

            return redirect(request.url)

        try:

            # get list of new sites
            allsites = pd.read_sql("select concat(region, '_', site) as" +\
                " sitenm from site", db.engine).sitenm.tolist()
            new = list(set([rs for rs in urs if rs not in allsites]))

            flash("Please double check your variable name matching.",
                'alert-warning')

            #write csv to disk; establish session variables to pass on
            x.to_csv(fnlong, index=False)
            session['fnlong'] = fnlong
            session['upload_complete'] = False
            session['filenameNoV'] = filenameNoV

            #go to next screen
            return render_template('grab_upload_columns.html', filename=filename,
                columns=columns, gvars=grab_variables,
                # variables=grab_variables, varsWithUnits=grab_vars_with_units, methods=grab_methods,
                cdict=cdict, mdict=mdict, wdict=wdict, adict=adict,
                newsites=new, sitenames=allsites, replacing=replace)

        except Exception as e:
            tb = traceback.format_exc()
            log_exception('007', tb)
            msg = Markup('Error 007. Please <a href="mailto:michael.vlah@duke.edu"' +\
                ' class="alert-link">email StreamPULSE development</a> ' +\
                'with the error number and a copy of the file you tried to upload.')
            try:
                os.remove(fnlong)
            except:
                pass
            finally:
                return redirect(request.url)

@app.route('/reach_characterization_filedrop', methods=['GET', 'POST'])
@login_required
def reach_characterization_filedrop():

    if request.method == 'POST':

        try:
            reachchar_dir = os.path.realpath('../spreachdata')
            reachchar_dir_old = os.path.realpath('../spreachdata_oldversions')

            #check inputs, extract region code and dataset names
            contactemail = request.form['contactemail']
            contactname = request.form['contactname']
            email_legal = sanitize_input_email(contactemail)
            name_legal = sanitize_input_allow_unicode(contactname)

            if not email_legal:
                msg = Markup('Only alphanumeric characters and @.- _~' +\
                    ' allowed in email address field')
                flash(msg, 'alert-danger')
                return redirect(url_for('reach_characterization_filedrop'))
            if not name_legal:
                msg = Markup('Only alphanumeric characters, spaces, and dashes ' +\
                    'allowed in ' + illegal_input + ' field.')
                flash(msg, 'alert-danger')
                return redirect(url_for('reach_characterization_filedrop'))

            if 'reach_characterization_upload' not in request.files:
                flash('No files detected', 'alert-danger')
                return redirect(request.url)

            files = request.files.getlist("reach_characterization_upload")
            fnms = [x.filename for x in files]

            if len(set(fnms)) < len(fnms):
                flash('At least two files you tried to upload have the same name.',
                    'alert-danger')
                return redirect(request.url)

            if len(fnms[0]) == 0: #is this needed, or is first catch sufficient?
                flash('No files selected.', 'alert-danger')
                return redirect(request.url)

            # fnms = ['AZ_canopy.csv', 'AZ_cross_section.csv']
            # f = fnms[1]
            regionlist = pd.read_sql('select distinct region from site;',
                db.engine).region.tolist()

            regions = []
            datasets = []
            for f in fnms:
                rgx = re.match('^([A-Za-z]{2})_(synoptic_)?(canopy|cross_section|' +\
                    'geomorphology|substrate|depth_rating_curve).csv$', f)
                if rgx:
                    rgx_grps = rgx.groups()
                    region = rgx_grps[0]
                    regions.append(region)
                    if any([l.islower() for l in region]):
                        flash('Name error in ' + f +\
                            '. Region code must be capitalized.', 'alert-danger')
                        return redirect(request.url)
                    if region not in regionlist:
                        flash('Name error in ' + f + '. Unrecognized region code.' +\
                        ' Please upload sensor data first.', 'alert-danger')
                        return redirect(request.url)
                    synop = '' if not rgx_grps[1] else rgx_grps[1]
                    datasets.append(synop + rgx_grps[2])
                else:
                    flash('Name error in ' + f +\
                        '. Example of a valid filename: RG_substrate.csv.',
                        'alert-danger')
                    return redirect(request.url)

            if any([r != regions[0] for r in regions]):
                flash('Please upload datasets from only one region at a time.',
                    'alert-danger')
                return redirect(request.url)

            #prevent filename mischief; document any name changes that occur
            fnms_secure = []
            files_secure = []
            fnms_changed = {}
            for f in files:
                if f:
                    fnm = f.filename
                    secured = secure_filename(fnm)
                    if secured != fnm:
                        fnms_changed[fnm] = secured
                    fnms_secure.append(secured)
                    files_secure.append(f)

            #determine whether any filenames have been uploaded before; move old vsns
            files_on_server = os.listdir(reachchar_dir)
            uploaded_bool = [f in files_on_server for f in fnms_secure]

            already_have = []
            moved = []
            if any(uploaded_bool):
                already_have = [fnms_secure[i] for i in range(len(fnms_secure)) \
                if uploaded_bool[i]]

                # if request.form.get('replacebox') == 'on':
                timestamp = datetime.now().strftime('%Y%m%d-%H%M%S%f')
                for f in already_have:
                    archive_filename = f[0:len(f) - 4] + '_' + timestamp + '.csv'
                    fmrpath = reachchar_dir + '/' + f
                    curpath = reachchar_dir_old + '/' + archive_filename
                    os.rename(fmrpath, curpath)
                    moved.append((fmrpath, curpath))
                # else:
                #     flash('Error. Dataset(s) already on file: ' +\
                #         ', '.join(already_have) +\
                #         '. Check the box in Step 3 to overwrite.', 'alert-danger')
                #     return redirect(request.url)

            #write files
            for i in range(len(files_secure)):
                # fn_base = re.match('^(.*?)\.csv$', fn_secure).groups()
                savepath = os.path.join(reachchar_dir, fnms_secure[i])
                files_secure[i].save(savepath)

            #populate database
            # dfile_str = ', '.join(fnms_secure) if dfiles[0] else 'NA'
            dtnow = datetime.utcnow()
            for n in fnms_secure:
                db_entry = Reachfiles(filename=n, uploader=contactname,
                    email=contactemail, addDate=dtnow)
                db.session.add(db_entry)

        except:

            if moved:
                for p in moved:
                    os.rename(p[1], p[0])

            tb = traceback.format_exc()
            log_exception('E010', tb)
            msg = Markup('Error 010. Please <a href="mailto:michael.vlah@duke.edu"' +\
                ' class="alert-link">notify StreamPULSE development</a> so this can be fixed.')
            flash(msg, 'alert-danger')

            return redirect(request.url)

        try:

            #give feedback to user
            len_already_have = len(already_have)
            n_new = len(fnms_secure) - len_already_have
            w1 = 'file' if n_new == 1 else 'files'
            w2 = 'file' if len_already_have == 1 else 'files'
            w3 = ' (' + ', '.join(already_have) + ').' if len_already_have else '.'
            flash('Uploaded ' + str(n_new) + ' new ' + w1 + ' and updated ' +\
                str(len_already_have) + ' existing ' + w2 + w3, 'alert-success')

            lfnms = len(fnms_changed)
            if lfnms:
                name_changes = [a[0] + ' -> ' + a[1] for a in list(fnms_changed.items())]
                ww = 'These filenames have' if lfnms != 1 else 'This filename has'
                flash(ww + ' been changed as a precaution: ' +\
                    ', '.join(name_changes) + '.', 'alert-warning')

        except:

            tb = traceback.format_exc()
            log_exception('E011', tb)
            msg = Markup('Error 011. Please <a href="mailto:michael.vlah@duke.edu"' +\
                ' class="alert-link">notify StreamPULSE development</a> so this can be fixed.')
            flash(msg, 'alert-danger')

            return redirect(request.url)

        db.session.commit()

        #get list of all regions for which reach characterization data have been supplied
        sc_files = os.listdir(app.config['REACH_CHAR_FOLDER'])
        exdata_regions = set([x.split('_')[0] for x in sc_files])

        return render_template('reach_characterization_filedrop.html',
            exdata_regions=exdata_regions)

    if request.method == 'GET': #when first visiting the reach char upload page

        #get list of all regions for which reach characterization data have been supplied
        sc_files = os.listdir(app.config['REACH_CHAR_FOLDER'])
        exdata_regions = set([x.split('_')[0] for x in sc_files])

        return render_template('reach_characterization_filedrop.html',
            exdata_regions=exdata_regions)

@app.route('/grdo_filedrop', methods=['GET', 'POST'])
def grdo_filedrop():

    if request.method == 'POST':

        #checks
        if 'metadataf' not in request.files and 'dataf' not in request.files:
            flash('No files detected','alert-danger')
            return redirect(request.url)
        mfiles = request.files.getlist("metadataf")
        mfnms = [x.filename for x in mfiles]
        dfiles = request.files.getlist("dataf")
        dfnms = [x.filename for x in dfiles]
        if len(mfnms[0]) == 0 and len(dfnms[0]) == 0:
            flash('No files selected.','alert-danger')
            return redirect(request.url)

        #upload
        try:
            timestamp = datetime.now().strftime('%m-%d-%Y_%H%M%S%f')
            mfnms_secure = []
            for file in mfiles:
                if file:
                    fn = file.filename
                    if fn == 'NA':
                        fn = 'na'
                    fn_secure = secure_filename(fn)
                    base, extn = re.match('^(.*?)(\..+)?$', fn_secure).groups()
                    if extn:
                        fn_secure = base + '_' + timestamp + extn
                    else:
                        fn_secure = base + '_' + timestamp
                    # fpath = os.path.join('/home/mike/Desktop/meta/', fn_secure)
                    fpath = os.path.join('/home/joanna/1_new/meta/', fn_secure)
                    file.save(fpath)
                    mfnms_secure.append(fn_secure)

            dfnms_secure = []
            for file in dfiles:
                if file:
                    fn = file.filename
                    if fn == 'NA':
                        fn = 'na'
                    fn_secure = secure_filename(fn) + '_' + timestamp
                    base, extn = re.match('^(.*?)(\..+)?$', fn_secure).groups()
                    if extn:
                        fn_secure = base + '_' + timestamp + extn
                    else:
                        fn_secure = base + '_' + timestamp
                    # fpath = os.path.join('/home/mike/Desktop/data/', fn_secure)
                    fpath = os.path.join('/home/joanna/1_new/data/', fn_secure)
                    file.save(fpath)
                    dfnms_secure.append(fn_secure)

        except:
            msg = Markup('There has been an error. Please notify site maintainer <a href=' +\
                '"mailto:vlahm13@gmail.com" class="alert-link">' +\
                'Mike Vlah</a>.')
            flash(msg, 'alert-danger')
            return redirect(request.url)

        #populate database
        contactname = request.form.get('contactname')
        contactemail = request.form.get('contactemail')
        embargo = request.form.get('embargo')
        addtl = request.form.get('additional')
        mfile_str = ', '.join(mfnms_secure) if mfiles[0] else 'NA'
        dfile_str = ', '.join(dfnms_secure) if dfiles[0] else 'NA'

        db_entry = Grdo(name=contactname, email=contactemail,
            addDate=datetime.utcnow(), embargo=embargo, notes=addtl,
            dataFiles=dfile_str, metaFiles=mfile_str)
        db.session.add(db_entry)
        db.session.commit()

        mlen = len(mfiles) if mfiles[0] else 0
        dlen = len(dfiles) if dfiles[0] else 0

        if mlen + dlen > 0:
            flash('Uploaded ' + str(mlen) + ' metadata file(s) and ' +\
            str(dlen) + ' data file(s).', 'alert-success')

        meta = pd.read_sql("select metaFiles from grdo", db.engine).metaFiles.tolist()
        listoflists = [x.split(', ') for x in meta]
        metafiles = [x for sublist in listoflists for x in sublist if x != 'NA']

        data = pd.read_sql("select dataFiles from grdo", db.engine).dataFiles.tolist()
        listoflists = [x.split(', ') for x in data]
        datafiles = [x for sublist in listoflists for x in sublist if x != 'NA']

        return render_template('grdo_filedrop.html', nmeta=len(metafiles),
            ndata=len(datafiles))

    if request.method == 'GET': #when first visiting the grdo upload page

        meta = pd.read_sql("select metaFiles from grdo", db.engine).metaFiles.tolist()
        listoflists = [x.split(', ') for x in meta]
        metafiles = [x for sublist in listoflists for x in sublist if x != 'NA']

        data = pd.read_sql("select dataFiles from grdo", db.engine).dataFiles.tolist()
        listoflists = [x.split(', ') for x in data]
        datafiles = [x for sublist in listoflists for x in sublist if x != 'NA']

        return render_template('grdo_filedrop.html', nmeta=len(metafiles),
            ndata=len(datafiles))

@app.route("/upload_cancel", methods=["POST"])
def cancelcolumns(): #only used when cancelling series_upload
    ofiles = request.form['ofiles'].split(",")
    tmpfile = request.form['tmpfile']+".csv"
    ofiles.append(tmpfile)
    [os.remove(os.path.join(app.config['UPLOAD_FOLDER'],x)) for x in ofiles] # remove tmp files
    flash('Upload cancelled.','alert-primary')
    return redirect(url_for('series_upload'))

@app.route("/policy")
def datapolicy():
    return render_template("datapolicy.html")

def updatecdict(region, site, cdict, ldict, ndict):
    # region='AZ'; site='WB'; c='Depth_m'

    rawcols = pd.read_sql("select * from cols where region='" + region +\
        "' and site ='" + site + "'", db.engine)
    rawcols = rawcols['rawcol'].tolist()
    for c in list(cdict.keys()):
        if c in rawcols: # update
            cx = Cols.query.filter_by(region=region, site=site, rawcol=c).first()
            cx.dbcol = cdict[c]
            cx.level = ldict[c]
            cx.notes = ndict[c]
        else: # add
            cx = Cols(region, site, c, cdict[c], ldict[c], ndict[c])
            db.session.add(cx)

def updateNotificationEmail(region, site, email):


    q = Notificationemail.query.filter_by(region=region, site=site).first()
    if q is not None: #update
        q.email = email
    else: # add
        q = Notificationemail(region, site, email)
        db.session.add(q)

def chunker_ingester(df, orm=Data, chunksize=100000):

    #determine chunks based on number of records
    n_full_chunks = df.shape[0] // chunksize
    partial_chunk_len = df.shape[0] % chunksize

    #convert directly to dict if small enough, otherwise do it chunkwise
    if n_full_chunks == 0:
        xdict = df.to_dict('records')
        db.session.bulk_insert_mappings(orm, xdict) #ingest all records
    else:
        for i in range(n_full_chunks):
            chunk = df.head(chunksize)
            df = df.drop(df.head(chunksize).index)
            chunk = chunk.to_dict('records')
            db.session.bulk_insert_mappings(orm, chunk)

        if partial_chunk_len:
            lastchunk = df.to_dict('records')
            db.session.bulk_insert_mappings(orm, lastchunk)

def updatedb(xx, fnamelist, replace='no'):

    # reg='AZ'; site='LV'; vars=['DO_mgL', 'WaterTemp_C']
    # mindt='2017-11-05 00:00:00'; maxdt='2017-11-25 00:00:00'

    if replace == 'records':

        reg = xx.region[0]
        site = xx.site[0]
        vars = set(xx.variable)
        mindt = str(xx.DateTime_UTC.min())
        maxdt = str(xx.DateTime_UTC.max())

        table_sub = pd.read_sql("select * from data where region='" + reg +\
            "' and site='" + site + "' and variable in ('" + "','".join(vars) +\
            "') and DateTime_UTC >= '" + mindt + "' and DateTime_UTC <= '" +\
            maxdt + "';", db.engine)

        # xx = table_sub.iloc[1:20,]
        # xx.loc[1:10,'value'] = 100
        # xx = xx.drop(['id','flag'], axis=1)
        # table_sub['ind'] = np.arange(0, table_sub.shape[0], 1)

        df_intersect = pd.merge(table_sub, xx, on=['region', 'site', 'variable',
            'DateTime_UTC'], how='inner')
        intersect_bool = table_sub.id.isin(df_intersect.id)

        table_sub = table_sub.drop('id', axis=1)
        # table_sub.loc[4:5, 'flag'] = 3

        flagrows = table_sub[intersect_bool & table_sub.flag.notnull()]
        flagrows = flagrows.drop(['value', 'upload_id'], axis=1)

        table_sub = table_sub[~intersect_bool]
        # new_records = newt[~intersect_bool]

        xx = pd.concat([table_sub, xx], axis=0, ignore_index=True)

        xx = pd.merge(xx, flagrows, on=['region', 'site', 'variable',
            'DateTime_UTC'], how='left')

        flag_update_inds = xx.index[xx.flag_y.notnull()]
        xx.loc[flag_update_inds, 'flag_x'] = xx.flag_y[flag_update_inds]
        xx = xx.drop('flag_y', axis=1)
        xx.rename(columns={'flag_x':'flag'}, inplace=True)
        # xx.loc[xx.flag.isnull(), 'flag'] = None
        xx.flag = xx.flag.where(xx.flag.notnull(), None)

        #delete records that are being replaced
        db.session.query(Data).filter(Data.region == reg, Data.site == site,
            Data.variable.in_(vars), Data.DateTime_UTC >= mindt,
            Data.DateTime_UTC <= maxdt).delete(synchronize_session=False)

        #insert new and/or replacement data (chunk it if > 100k records)
        chunker_ingester(xx)
        # db.session.rollback()
        # db.session.commit()

    elif replace == 'file':

        #get list of existing upload ids and table of flagged obs to be replaced
        upIDs = pd.read_sql("select id from upload where filename in ('" +\
            "', '".join(fnamelist) + "')", db.engine)
        upIDs = [str(i) for i in upIDs.id]
        flagged_obs = pd.read_sql("select * from data where upload_id in ('" +\
            "', '".join(upIDs) + "') and flag is not null", db.engine)

        #delete records that are being replaced (this could be sped up using
        #the code from replace == 'byrow' above)
        #if list(upIDs):
        #    d = Data.query.filter(Data.upload_id.in_(list(upIDs))).all()
        #    for rec in d:
        #        db.session.delete(rec)
        #delete records that are being replaced
        if list(upIDs):
            db.session.query(Data).filter(Data.upload_id.in_(list(upIDs)))\
                .delete(synchronize_session=False)

        #reconstitute flags (this too)
        for ind, r in flagged_obs.iterrows():
            try:
                d = Data.query.filter(Data.region==r['region'], Data.site==r['site'],
                    Data.upload_id==r['upload_id'], Data.variable==r['variable'],
                    Data.DateTime_UTC==r['DateTime_UTC']).first()
                d.flag = r['flag']
                db.session.add(d)
            except:
                continue

        #insert new or replacement data (chunk it if > 100k records)
        chunker_ingester(xx)

    else: #if not replacing, just insert new data
        chunker_ingester(xx)

    #create and call stored procedure to update site table with var list and time range
    with open('site_update_stored_procedure.sql', 'r') as f:
        t = f.read()

    t = t.replace('RR', xx.region[0])
    t = t.replace('SS', xx.site[0])

    db.session.execute(t)
    db.session.execute('CALL update_site_table();')

def grab_updatecdict(region, sitelist, cdict, mdict, wdict, adict):

    #get input variable name list
    rawcols = pd.read_sql("select * from grabcols where region='" + region +\
        "' and site in ('" + "', '".join(sitelist) + "')", db.engine)
    rawcols = set(rawcols['rawcol'].tolist())

    #update or establish varname, method, addtl mappings
    for c in list(cdict.keys()):
        for s in sitelist:
            if c in rawcols: # update/add

                cx = Grabcols.query.filter_by(rawcol=c, site=s).first()
                if cx: #if we already have column preferences for this site, update
                    cx.dbcol = cdict[c] # assign new dbcol value for this rawcol
                    cx.method = mdict[c] # assign new method
                    cx.write_in = wdict[c] # assign new write-in method
                    cx.addtl = adict[c] # assign new additional attributes
                else: #else, add
                    cx = Grabcols(region, s, c, cdict[c], mdict[c], wdict[c], adict[c])
                    db.session.add(cx)

            else: # add
                cx = Grabcols(region, s, c, cdict[c], mdict[c], wdict[c], adict[c])
                db.session.add(cx)

def grab_updatedb(xx, fnamelist, replace=False):

    unique_regionsites = xx.drop_duplicates(subset=['region','site'])

    if replace:

        #get list of existing upload ids and table of flagged obs to be replaced
        upIDs = pd.read_sql("select id from grabupload where filename in ('" +\
            "', '".join(fnamelist) + "')", db.engine)
        upIDs = [str(i) for i in upIDs.id]
        flagged_obs = pd.read_sql("select * from grabdata where upload_id in ('" +\
            "', '".join(upIDs) + "') and flag is not null", db.engine)

        #delete records that are being replaced (this could be sped up)
        if list(upIDs):
            d = Grabdata.query.filter(Grabdata.upload_id.in_(list(upIDs))).all()
            for rec in d:
                db.session.delete(rec)

        #insert new (replacement) data (chunk it if > 100k records)
        n_full_chunks = xx.shape[0] // 100000
        partial_chunk_len = xx.shape[0] % 100000

        if n_full_chunks == 0:
            xx = xx.to_dict('records')
            db.session.bulk_insert_mappings(Grabdata, xx) #ingest all records
        else:
            for i in range(n_full_chunks): #ingest full (100k-record) chunks
                chunk = xx.head(100000)
                xx = xx.drop(xx.head(100000).index)
                chunk = chunk.to_dict('records')
                db.session.bulk_insert_mappings(Grabata, chunk)

            if partial_chunk_len:
                xx = xx.to_dict('records')
                db.session.bulk_insert_mappings(Data, xx) #ingest remainder

        #reconstitute flags
        for ind, r in flagged_obs.iterrows():
            try:
                d = Grabdata.query.filter(Grabdata.region==r['region'], Grabdata.site==r['site'],
                    Grabdata.upload_id==r['upload_id'], Grabdata.variable==r['variable'],
                    Grabdata.method==r['method'], Grabdata.write_in==r['write_in'],
                    Grabdata.addtl==r['addtl'], Grabdata.DateTime_UTC==r['DateTime_UTC']).first()
                d.flag = r['flag']
                db.session.add(d)
            except:
                continue

    else: #if not replacing, just insert new data (this should be chunked too)
        xx = xx.to_dict('records')
        db.session.bulk_insert_mappings(Grabdata, xx)

    #create and call stored procedure to update site table with var list and time range
    unique_regionsites = unique_regionsites.reset_index()

    for i in range(unique_regionsites.shape[0]):

        with open('site_update_stored_procedure_grab.sql', 'r') as f:
            t = f.read()
            f.close()

        RR, SS = unique_regionsites.loc[i, ['region', 'site']]
        t = t.replace('RR', RR)
        t = t.replace('SS', SS)

        db.session.execute(t)
        db.session.execute('CALL update_site_table_grab();')

def sanitize_input_allow_unicode(input):
    mch = regex.search(r'[^A-Za-z0-9\p{L} \-\.]', input)
    out = False if mch else True
    return out

# def sanitize_input_forbid_unicode(input):
#     mch = re.search(ur'[^A-Za-z0-9 \-\.]', input)
#     out = False if mch else True
#     return out

def sanitize_input_email(input):
    mch = re.search(r'[^A-Za-z0-9 \-\@\.\_\'\~]', input)
    out = False if mch else True
    return out

@app.route("/upload_confirm", methods=["POST"])
def confirmcolumns():

    #get combined inputs (tmpfile), varname mappings (cdict), and filenames
    tmpfile = request.form['tmpfile']
    tmpcode = tmpfile.split('_')[2]
    cdict = json.loads(request.form['cdict'])
    cdict = dict([(r['name'], r['value']) for r in cdict])
    ldict = json.loads(request.form['ldict'])
    ldict = dict(list(zip(list(cdict.keys()), ldict)))
    ndict = json.loads(request.form['ndict'])
    ndict = dict(list(zip(list(cdict.keys()), ndict)))
    notificationEmail = request.form['notificationEmail']

    fnlong = session.get('fnlong')
    filenamesNoV = session.get('filenamesNoV')
    filenames_for_reporting = [x[0] for x in filenamesNoV]

    #sanitize inputs
    if request.form['existing'] == "no":

        illegal_input = None

        input_is_legal = sanitize_input_email(request.form['contactEmail'])
        if not input_is_legal:
            illegal_input = 'contact email'

        input_dict = {'contactName':'contact name', 'lat':'latitude',
            'lng':'longitude', 'datum':'datum', 'sitename':'site name', 'usgs':'USGS gage ID'}
        if not illegal_input:

            for i in list(input_dict.keys()):
                input_is_legal = sanitize_input_allow_unicode(request.form[i])
                if not input_is_legal:
                    illegal_input = input_dict[i]
                    break

        if illegal_input:

            try:
                os.remove(os.path.join(app.config['UPLOAD_FOLDER'], tmpfile + ".csv"))
                [os.remove(f) for f in fnlong]
            except:
                pass
            if illegal_input == 'contact email':
                msg = Markup('Only alphanumeric characters and @.- _~' +\
                    ' allowed in email address field')
            else:
                msg = Markup('Only alphanumeric characters, spaces, and dashes ' +\
                    'allowed in ' + illegal_input + ' field.')

            flash(msg, 'alert-danger')
            return redirect(url_for('series_upload'))

    try:

        #load and format dataframe
        xx = pd.read_csv(os.path.join(app.config['UPLOAD_FOLDER'],
            tmpfile + ".csv"), parse_dates=[0])
        upid_col = xx['upload_id']
        xx = xx[list(cdict.keys())].rename(columns=cdict) #assign canonical names

        datetimecollist = [1 for i in xx.columns if i == 'DateTime_UTC']
        if len(datetimecollist) > 1:
            flash('Only one DateTime_UTC column allowed.', 'alert-danger')
            os.remove(os.path.join(app.config['UPLOAD_FOLDER'], tmpfile + ".csv"))
            [os.remove(f) for f in fnlong]
            return redirect(url_for('series_upload'))

        xx = pd.concat([xx, upid_col], axis=1) #reattach upload IDs
        region, site = tmpfile.split("_")[:-1]

        if request.form['existing'] == "no":

            # add new site to database
            usgss = None if request.form['usgs'] == "" else request.form['usgs']
            sx = Site(region=region, site=site, name=request.form['sitename'],
                latitude=request.form['lat'], longitude=request.form['lng'],
                datum=request.form['datum'],
                usgs=usgss, addDate=datetime.utcnow(),
                embargo=request.form['embargo'],
                by=current_user.get_id(), contact=request.form['contactName'],
                contactEmail=request.form['contactEmail'])
            db.session.add(sx)

            #give uploading user access to this site
            add_site_permission(current_user, region, site)

        # #format df for database entry
        # xx = xx.set_index(["DateTime_UTC", "upload_id"])
        # xx.columns.name = 'variable'
        # xx = xx.stack() #one col each for vars and vals
        # xx.name="value"
        # xx = xx.reset_index()
        # xx = xx.groupby(['DateTime_UTC','variable']).mean().reset_index() #dupes
        # xx['region'] = region
        # xx['site'] = site
        # xx['flag'] = None
        # xx = xx[['region','site','DateTime_UTC','variable','value','flag',
        #     'upload_id']]

        # replace = True if request.form['replacing'] == 'yes' else False
        replace = request.form['replace']

        #add new information to upload table in db
        fn_to_db = [i[0] for i in filenamesNoV]
        # unsortable = [x for x in filenamesNoV if x[1] is None]
        # filenamesNoV = [x for x in filenamesNoV if x[1] is not None]
        # if filenamesNoV:
        #     filenamesNoV = sorted(filenamesNoV, key=itemgetter(1))
        # filenamesNoV.extend(unsortable)
        filenamesNoV = [i for i in filenamesNoV if i[1] is not None]
        if filenamesNoV:
            filenamesNoV = sorted(filenamesNoV, key=itemgetter(1))
            for f in filenamesNoV:
                uq = Upload(filename=f[0], uploadtime_utc=datetime.utcnow(),
                    user_id=current_user.get_id())
                db.session.add(uq)

        #update variable name mappings
        updatecdict(region, site, cdict, ldict, ndict)
        updateNotificationEmail(region, site, notificationEmail)
        db.session.commit()

    except Exception as e:

        tb = traceback.format_exc()

        try:
            os.remove(os.path.join(app.config['UPLOAD_FOLDER'], tmpfile + ".csv"))
            [os.remove(f) for f in fnlong]
        except:
            pass

        df_head = xx.head(2).to_string()
        log_rawcols = '\n\nrawcols: ' + ', '.join(list(cdict.keys()))
        log_dbcols = '\ndbcols: ' + ', '.join(list(cdict.values()))

        if request.form['existing'] == "no":
            error_details = '\n\nusgs: ' + request.form['usgs'] + '\nsitename: ' +\
                request.form['sitename'] + '\nlat: ' + request.form['lat'] +\
                '\nlon: ' + request.form['lng'] + '\nembargo: ' +\
                request.form['embargo'] + '\ncontactname: ' +\
                request.form['contactName'] + '\ncontactemail: ' +\
                request.form['contactEmail'] + '\n\nmeta: ' + metastring +\
                '\n\nfn_to_db: ' + ', '.join(fn_to_db) + '\nreplace: ' +\
                replace + '\n\n'
        else:
            error_details = '\n\nfn_to_db: ' + ', '.join(fn_to_db) +\
                '\nreplace: ' + replace + '\n\n'

        errno = 'E008'
        msg = Markup("Error 008. StreamPULSE development has been notified.")
        flash(msg, 'alert-danger')

        full_error_detail = tb + error_details + df_head + log_rawcols + log_dbcols
        log_exception(errno, full_error_detail)
        email_msg(errno + '\n' + full_error_detail, 'sp err', 'streampulse.info@gmail.com')

        return redirect(url_for('series_upload'))

    timerange = xx.DateTime_UTC.max() - xx.DateTime_UTC.min()
    if replace == 'records' and timerange.days > 366:
        try:
            os.remove(os.path.join(app.config['UPLOAD_FOLDER'], tmpfile + ".csv"))
        except:
            pass
        [os.remove(f) for f in fnlong]
        flash('Please upload no more than a year of data (366 days) if using ' +\
            'by-record data revision.', 'alert-danger')
        return redirect(url_for('series_upload'))

    #save dataframe and ancillary data so that it can be accessed when user returns
    xx.to_csv('../spdumps/' + tmpcode + '_xx.csv',  index=False)
    # feather.write_dataframe(xx, '../spdumps/' + tmpcode + '_xx.feather')

    dumpfile = '../spdumps/' + tmpcode + '_confirmcolumns.json'
    with open(dumpfile, 'w') as d:
        dmp = json.dump({'region': region, 'site': site, 'cdict': cdict,
            'ldict': ldict, 'ndict': ndict, 'fn_to_db': fn_to_db,
            'replace': replace, 'metadata': request.form.get('metadata'),
            'existing': request.form.get('existing'), 'usgs': request.form.get('usgs'),
            'embargo': request.form.get('sitename'), 'contactName': request.form.get('contactName'),
            'contactEmail': request.form.get('contactEmail'), 'lat': request.form.get('lat'),
            'lng': request.form.get('lng'), 'fnlong': fnlong, 'replace': replace}, d)

    #initiate data processing pipeline as background process
    report_filenames = ', '.join(filenames_for_reporting)
    #R_process = subprocess.Popen(['Rscript', '--vanilla',
    subprocess.Popen(['Rscript', '--vanilla',
        'pipeline/pipeline.R', request.form['notificationEmail'], tmpcode,
        region, site, report_filenames,
        os.path.join(app.config['UPLOAD_FOLDER'], tmpfile + ".csv"),
        ', '.join(fnlong)])
    #if R_process.returncode != 0:
    #    with open('static/email_templates/error_notification.txt', 'r') as f:
    #        error_notification_email = f.read()
    #    error_notification_email = error_notification_email.format(filename=', '.join(report_filenames))
    #
    #    email_msg(error_notification_email, 'StreamPULSE Error',
    #        request.form['notificationEmail'], header=False, render_html=True)

    #    try:
    #        os.remove(os.path.join(app.config['UPLOAD_FOLDER'], tmpfile + ".csv"))
    #        [os.remove(f) for f in fnlong]
    #    except:
    #        pass

    notification = 'StreamPULSE is processing your upload for ' + region + '_' +\
        site + '. We will send you an email notification when outlier ' +\
        'detection and gap filling are complete. If you do not receive an email in 24 hours, there has been an error.'

    flash(notification, 'alert-success')

    return redirect(url_for('series_upload'))

@app.route("/get_pipeline_data", methods=["POST"])
def get_pipeline_data():

    try:

        tmpcode = request.json

        # tmpcode = '0e93993c5fd9'
        dumpfile = '../spdumps/' + tmpcode + '_confirmcolumns.json'
        with open(dumpfile) as d:
            up_data = json.load(d)
        region = up_data['region']
        site = up_data['site']
        replace = up_data['replace']

        origdf = pd.read_csv('../spdumps/' + tmpcode + '_orig.csv',
            parse_dates=['DateTime_UTC'])
        origdf.DateTime_UTC = origdf.DateTime_UTC.dt.tz_localize('UTC')
        pldf = pd.read_csv('../spdumps/' + tmpcode + '_cleaned.csv',
            parse_dates=['DateTime_UTC'])
        pldf.DateTime_UTC = pldf.DateTime_UTC.dt.tz_localize('UTC')
        flagdf = pd.read_csv('../spdumps/' + tmpcode + '_flags.csv',
            parse_dates=['DateTime_UTC'])
        flagdf.DateTime_UTC = flagdf.DateTime_UTC.dt.tz_localize('UTC')
        # origdf = feather.read_dataframe('../spdumps/' + tmpcode + '_orig.feather')
        # pldf = feather.read_dataframe('../spdumps/' + tmpcode + '_cleaned.feather')
        # flagdf = feather.read_dataframe('../spdumps/' + tmpcode + '_flags.feather')

        #json format original data, pipeline data, and flag data
        origjson = origdf.to_json(orient='records', date_format='iso')
        pljson = pldf.to_json(orient='records', date_format='iso')

        flagdf = flagdf.set_index('DateTime_UTC').stack().reset_index().\
            rename(columns={'level_1': 'variable', 0: 'code'}, inplace=False)
        flagdf = flagdf[flagdf['code'] != 0]
        flagjson = flagdf.to_json(orient='records', date_format='iso')

        variables = origdf.columns[1:-1].tolist()

        #retrieve qaqc information if it exists (only if this is a reupload)
        if replace != 'no':

            sdt0 = origdf.DateTime_UTC.min()
            edt0 = origdf.DateTime_UTC.max()
            # region='NC'; site='UEno'; sdt0='2018-05-11'; edt0='2018-06-13'
            # variables=['DO_mgL', 'WaterTemp_C']
            # variables=['chili']

            qaqcdf = pd.read_sql('select DateTime_UTC, variable from data where ' +\
                'region="' + region + '" and site="' + site + '" and DateTime_UTC >="' +\
                str(sdt0) + '" and DateTime_UTC <="' + str(edt0) + '" and variable in ("' +\
                '","'.join(variables) + '") and flag is not null;', db.engine)

            qaqcjson = {}
            if not qaqcdf.empty:
                for v in variables:
                    qj = qaqcdf.loc[qaqcdf.variable == v, 'DateTime_UTC']
                    qaqcjson[v] = qj.dt.strftime('%Y-%m-%dT%H:%M:%S').tolist()
            else:
                qaqcjson = dict([[v, []] for v in variables])
        else:
            qaqcjson = dict([[v, []] for v in variables])

        qaqcjson = json.dumps(qaqcjson)
        with open('../spdumps/' + tmpcode + '_oldqaqc.json', 'w') as oj:
            oj.write(qaqcjson)

        # Get sunrise sunset data
        sxx = pd.read_sql("select latitude, longitude from site where region='" +\
            region + "' and site='" + site + "'", db.engine)
        sdt = min(origdf.DateTime_UTC).replace(hour=0, minute=0, second=0,
            microsecond=0)
        edt = max(origdf.DateTime_UTC).replace(hour=0, minute=0, second=0,
            microsecond=0) + timedelta(days=1)

        ddt = edt - sdt
        lat = sxx.latitude[0]
        lng = sxx.longitude[0]
        rss = []
        for i in range(ddt.days + 1):
            rise, sets = list(suns(sdt + timedelta(days=int(i) - 1), latitude=lat,
                longitude=lng).calculate())
            if rise > sets:
                sets = sets + timedelta(days=1) # account for UTC
            rss.append([rise, sets])

        rss = pd.DataFrame(rss, columns=("rise", "set"))
        rss.set = rss.set.shift(1)
        sunriseset = rss.loc[1:].to_json(orient='records', date_format='iso')

        drr = get_twoweek_windows(sdt, edt)

    except Exception as e:

        tb = traceback.format_exc()

        if 'origdf' in locals():
            full_error_detail = tb + str(origdf.head()) + str(pldf.head()) + str(flagdf.head()) +\
                dumpfile + region + site + tmpcode
        else:
            full_error_detail = tb + ' ORIGDF DID NOT EXIST!'

        log_exception('E012', full_error_detail)
        email_msg(full_error_detail, 'sp err', 'streampulse.info@gmail.com')

        msg = Markup('Error 012. StreamPULSE development has been notified.')
        flash(msg, 'alert-danger')

        return redirect(url_for('series_upload'))

    return jsonify(variables=variables, origjson=origjson, pljson=pljson,
        flagjson=flagjson, sunriseset=sunriseset, plotdates=drr, oldqaqc=qaqcjson)

@app.route("/pipeline-complete-<string:tmpcode>", methods=["GET"])
@login_required
def pipeline_complete(tmpcode):

    #load static html for popup menu
    with open('static/html/qaqcPopupMenu_pl.html', 'r') as html_file:
        qaqc_options_sensor = html_file.read()
    qaqc_options_sensor = qaqc_options_sensor.replace('\n', '')

    return render_template('pipeline_qaqc.html', tmpcode=tmpcode,
        qaqc_options=qaqc_options_sensor)

def rm_bad_data(uf, ufpts, df, modify_dicts=False):

    bad_ids = [x['instance_id'] for x in uf if x['flagid'] == 'Bad Data']
    for x in list(ufpts.keys()):
        flagdts = ufpts[x]['dt']
        flagids = ufpts[x]['id']
        rm_dts = []

        for i in range(len(flagdts) - 1, -1, -1):
            if flagids[i] in bad_ids:
                rm_dts.append(flagdts[i])

                if modify_dicts:
                    flagdts.pop(i)
                    flagids.pop(i)

        if len(rm_dts):
            rm_dts = [datetime.strptime(x[0:19], '%Y-%m-%dT%H:%M:%S') for x in rm_dts]
            df.loc[rm_dts, x] = None

    if modify_dicts:
        for i in range(len(uf) - 1, -1, -1):
            if uf[i]['flagid'] == 'Bad Data':
                uf.pop(i)

    return uf, ufpts, df

@app.route("/round2-gapfill-<string:tmpcode>", methods=["POST"])
@login_required
def round2_gapfill(tmpcode):

    userflagpts = json.loads(request.form['userflagpts'])
    userflags = json.loads(request.form['userflags'])
    rejections = json.loads(request.form['rej_holder'])
    interpdeluxe = request.form['interpdeluxe']

    # tmpcode='ab10a36ee492'

    origdf = pd.read_csv('../spdumps/' + tmpcode + '_orig.csv',
        parse_dates=['DateTime_UTC']).set_index(['DateTime_UTC'])
    # origdf.DateTime_UTC = origdf.DateTime_UTC.dt.tz_localize('UTC')
    # origdf.head(1)
    pldf = pd.read_csv('../spdumps/' + tmpcode + '_cleaned.csv',
        parse_dates=['DateTime_UTC']).set_index(['DateTime_UTC'])
    # pldf.DateTime_UTC = pldf.DateTime_UTC.dt.tz_localize('UTC')
    # origdf = feather.read_dataframe('../spdumps/' + tmpcode + '_orig.feather')
    # origdf = origdf.set_index(['DateTime_UTC']).tz_localize(None)
    # pldf = feather.read_dataframe('../spdumps/' + tmpcode + '_cleaned.feather')
    # pldf = pldf.set_index(['DateTime_UTC']).tz_localize(None)

    #replace pldf values with origdf values where pldf has been rejected
    for r in rejections.items():
        rejdts = r[1]
        if rejdts:
            rejvar = r[0]
            rejdts = [datetime.strptime(x[0:-5], '%Y-%m-%dT%H:%M:%S') for x in rejdts]
            pldf.loc[rejdts, rejvar] = origdf.loc[rejdts, rejvar]

    #remove anything flagged as "Bad Data" (from pldf and flag dicts)
    userflags, userflagpts, pldf = rm_bad_data(userflags, userflagpts, pldf, True)

    pldf = pldf.reset_index()
    pldf.to_csv('../spdumps/' + tmpcode + '_cleaned_checked.csv',  index=False)
    # feather.write_dataframe(pldf, '../spdumps/' + tmpcode + '_cleaned_checked.feather')

    #fill remaining gaps (background process)
    sp = subprocess.Popen(['Rscript', '--vanilla',
        'pipeline/fill_remaining_gaps.R', tmpcode, interpdeluxe])
    sp.communicate() #wait for it to return

    dumpfile2 = '../spdumps/' + tmpcode + '_useredits.json'
    with open(dumpfile2, 'w') as dmp:
        json.dump({'userflags': userflags, 'userflagpts': userflagpts}, dmp)

    return redirect(url_for('check_round2', tmpcode=tmpcode))

@app.route("/check-round2-<string:tmpcode>", methods=["GET"])
@login_required
def check_round2(tmpcode):

    # tmpcode = 'f1415093a23e'

    #load static html for popup menu
    with open('static/html/qaqcPopupMenu_pl2.html', 'r') as html_file:
        qaqc_options_sensor = html_file.read()
    qaqc_options_sensor = qaqc_options_sensor.replace('\n', '')

    usrmsg = '../spdumps/' + tmpcode + '_usrmsg.txt'
    if not os.path.exists(usrmsg):
        flash('An error occurred during imputation. Some or all data gaps ' +\
            'may remain.', 'alert-danger')
    else:
        with open(usrmsg, 'r') as u:
            usr_msg_code = u.read()

        if usr_msg_code == '1':
            flash('No missing datapoints found, so imputation was not performed.',
                'alert-warning')
        elif usr_msg_code == '2':
            flash('Fewer than 30 days without NAs, so NDI was not performed.',
                'alert-warning')
        elif usr_msg_code == '3':
            flash('An error occurred during NDI. Only univariate linear ' +\
                'interpolation of gaps <= 3 hrs was performed.', 'alert-warning')

    return render_template('pipeline_qaqc2.html', tmpcode=tmpcode,
        qaqc_options=qaqc_options_sensor)

@app.route("/get_pipeline_data2", methods=["POST"])
def get_pipeline_data2():

    try:

        tmpcode = request.json

        # tmpcode='01e51a7c5ddc'
        dumpfile = '../spdumps/' + tmpcode + '_confirmcolumns.json'
        with open(dumpfile) as d:
            up_data = json.load(d)
        region = up_data['region']
        site = up_data['site']
        replace = up_data['replace']

        dumpfile2 = '../spdumps/' + tmpcode + '_useredits.json'
        with open(dumpfile2, 'r') as d:
            useredits = json.load(d)

        with open('../spdumps/' + tmpcode + '_oldqaqc.json', 'r') as oj:
            # qaqcjson = json.load(oj)
            qaqcjson = oj.read()

        # pldf = feather.read_dataframe('../spdumps/' + tmpcode +\
        #     '_cleaned_checked_imp.feather')
        pldf = pd.read_csv('../spdumps/' + tmpcode + '_cleaned_checked_imp.csv',
            parse_dates=['DateTime_UTC'])
        # pldf.DateTime_UTC = pldf.DateTime_UTC.dt.tz_localize('UTC')
        pldf.apply(lambda x: sum(x.isnull()), axis=0)
        # flagdf = feather.read_dataframe('../spdumps/' + tmpcode +\
        #     '_flags2.feather')
        flagdf = pd.read_csv('../spdumps/' + tmpcode + '_flags2.csv',
            parse_dates=['DateTime_UTC'])
        # flagdf.DateTime_UTC = flagdf.DateTime_UTC.dt.tz_localize('UTC')


        #json format pipeline data and flag data
        pljson = pldf.to_json(orient='records', date_format='iso')

        flagdf = flagdf.set_index('DateTime_UTC').stack().reset_index().\
            rename(columns={'level_1': 'variable', 0: 'code'}, inplace=False)
        flagdf = flagdf[flagdf['code'] != 0]
        flagjson = flagdf.to_json(orient='records', date_format='iso')

        variables = pldf.columns[1:-1].tolist()

        # Get sunrise sunset data
        sxx = pd.read_sql("select latitude, longitude from site where region='" +\
            region + "' and site='" + site + "'", db.engine)
        sdt = min(pldf.DateTime_UTC).replace(hour=0, minute=0, second=0,
            microsecond=0)
        edt = max(pldf.DateTime_UTC).replace(hour=0, minute=0, second=0,
            microsecond=0) + timedelta(days=1)

        ddt = edt - sdt
        lat = sxx.latitude[0]
        lng = sxx.longitude[0]
        rss = []
        for i in range(ddt.days + 1):
            rise, sets = list(suns(sdt + timedelta(days=int(i) - 1), latitude=lat,
                longitude=lng).calculate())
            if rise > sets:
                sets = sets + timedelta(days=1) # account for UTC
            rss.append([rise, sets])

        rss = pd.DataFrame(rss, columns=("rise", "set"))
        rss.set = rss.set.shift(1)
        sunriseset = rss.loc[1:].to_json(orient='records', date_format='iso')

        drr = get_twoweek_windows(sdt, edt)

    except Exception as e:

        tb = traceback.format_exc()

        if 'pldf' in locals():
            pldf_head = pldf.head(2).to_string()
            flagdf_head = flagdf.head(2).to_string()

            full_error_detail = tb + pldf_head + flagdf_head +\
                dumpfile + region + site + tmpcode
        else:
            full_error_detail = tb + ' PLDF DID NOT EXIST!'

        log_exception('E013', full_error_detail)
        email_msg(full_error_detail, 'sp err', 'streampulse.info@gmail.com')

        msg = Markup('Error 013. StreamPULSE development has been notified.')
        flash(msg, 'alert-danger')

        return redirect(url_for('series_upload'))

    return jsonify(variables=variables, pljson=pljson, flagjson=flagjson,
        sunriseset=sunriseset, plotdates=drr, useredits=useredits, oldqaqc=qaqcjson)

@app.route("/submit-dataset-<string:tmpcode>", methods=["POST"])
@login_required
def submit_dataset(tmpcode):

    try:

        userflagpts = json.loads(request.form['userflagpts'])
        userflags = json.loads(request.form['userflags'])
        rejections = json.loads(request.form['rej_holder'])
        # print(userflags)
        # print(userflagpts)
        # print(rejections)

        # tmpcode = '02dee6f14e8c'
        # userflagpts = {'DOsat_pct': {'dt': ['2017-08-05T18:00:00.000Z', '2017-08-05T18:15:00.000Z', '2017-08-05T18:30:00.000Z', '2017-08-05T18:45:00.000Z', '2017-08-05T19:00:00.000Z', '2017-08-05T19:15:00.000Z', '2017-08-05T19:30:00.000Z'], 'id': [3, 3, 3, 3, 3, 3, 3]}, 'Depth_m': {'dt': ['2017-08-05T05:30:00.000Z', '2017-08-05T05:45:00.000Z', '2017-08-05T06:00:00.000Z', '2017-08-05T06:15:00.000Z', '2017-08-05T06:30:00.000Z'], 'id': [1, 1, 1, 1, 1]}, 'pH_mV': {'dt': ['2017-08-05T07:15:00.000Z', '2017-08-05T07:30:00.000Z', '2017-08-05T07:45:00.000Z', '2017-08-05T08:00:00.000Z', '2017-08-05T08:15:00.000Z', '2017-08-05T08:30:00.000Z', '2017-08-05T08:45:00.000Z', '2017-08-05T09:00:00.000Z'], 'id': [1, 1, 1, 1, 1, 1, 1, 1]}}
        # userflags = [{'comment': '', 'endDate': '2017-08-05T06:34:39.981Z', 'flagid': 'Questionable', 'instance_id': 1, 'startDate': '2017-08-05T05:24:48.176Z', 'var': ['Depth_m']}, {'comment': 'fart', 'endDate': '2017-08-05T20:02:36.176Z', 'flagid': 'Questionable', 'instance_id': 3, 'startDate': '2017-08-05T17:56:23.884Z', 'var': ['DOsat_pct']}, {'flagid': 'Interesting', 'instance_id': 1, 'startDate': '2017-08-05T07:06:13.054Z', 'endDate': '2017-08-05T09:05:39.688Z', 'comment': 'whoa!', 'var': ['pH_mV']}]
        # rejections = {'Depth_m': ['2017-08-05T17:15:00.000Z', '2017-08-05T17:30:00.000Z', '2017-08-05T17:45:00.000Z'], 'DOsat_pct': [], 'pH_mV': []}

        dumpfile = '../spdumps/' + tmpcode + '_confirmcolumns.json'
        with open(dumpfile) as d:
            up_data = json.load(d)
        region = up_data['region']
        site = up_data['site']
        replace = up_data['replace']

        pldf = pd.read_csv('../spdumps/' + tmpcode + '_cleaned_checked_imp.csv',
            parse_dates=['DateTime_UTC']).set_index(['DateTime_UTC'])
        # pldf.DateTime_UTC = pldf.DateTime_UTC.dt.tz_localize('UTC')
        flagdf = pd.read_csv('../spdumps/' + tmpcode + '_flags.csv',
            parse_dates=['DateTime_UTC']).set_index(['DateTime_UTC'])
        # flagdf.DateTime_UTC = flagdf.DateTime_UTC.dt.tz_localize('UTC')
        flagdf2 = pd.read_csv('../spdumps/' + tmpcode + '_flags2.csv',
            parse_dates=['DateTime_UTC']).set_index(['DateTime_UTC'])
        # flagdf2.DateTime_UTC = flagdf2.DateTime_UTC.dt.tz_localize('UTC')
        # pldf = feather.read_dataframe('../spdumps/' + tmpcode + '_cleaned_checked_imp.feather')
        # pldf = pldf.set_index(['DateTime_UTC']).tz_localize(None)
        # flagdf = feather.read_dataframe('../spdumps/' + tmpcode + '_flags.feather')
        # flagdf = flagdf.set_index(['DateTime_UTC']).tz_localize(None)
        # flagdf2 = feather.read_dataframe('../spdumps/' + tmpcode + '_flags2.feather')
        # flagdf2 = flagdf2.set_index(['DateTime_UTC']).tz_localize(None)

        #compile imputation codes from rnd1 and rnd2; 1 for linterp, 2 for ndi
        flagmerge = flagdf2.iloc[:, 0:flagdf2.shape[1]]
        flagmerge.loc[:, :] = 0
        rnd1_linterp_bool = flagdf.loc[:, flagdf.columns != 'DateTime_UTC'] == 4
        rnd2_linterp_bool = flagdf2.loc[:, flagdf2.columns != 'DateTime_UTC'] == 1
        rnd1_indfilt = rnd1_linterp_bool.index.isin(rnd2_linterp_bool.index)
        rnd1_linterp_bool = rnd1_linterp_bool[rnd1_indfilt]
        rnd1_linterp_bool = rnd1_linterp_bool.loc[~rnd1_linterp_bool.index.duplicated()]
        linterp_bool = rnd1_linterp_bool | rnd2_linterp_bool
        linterp_df = linterp_bool * 1
        ndi_df = (flagdf2.loc[:, flagdf2.columns != 'DateTime_UTC'] == 2) * 2
        flagmerge = linterp_df + ndi_df
        flagmerge[flagmerge == 3] = 2
        flagmerge_indfilt = flagmerge.index.isin(pldf.index)
        flagmerge = flagmerge[flagmerge_indfilt]
        flagmerge = flagmerge.loc[~flagmerge.index.duplicated()]
        flagmerge = flagmerge.astype(str)
        flagmerge[flagmerge == '1'] = 'linterp'
        flagmerge[flagmerge == '2'] = 'ndi'
        # zz = pd.DataFrame({'a':['t','y','u'], 'b':['v','b','n']})
        # flagmerge.apply(lambda x: sum(x != 0), axis=0)
        # flagmerge.apply(lambda x: sum(x == 'ndi'), axis=0)

        # remove pldf values where they've been rejected
        for r in rejections.items():
            rejdts = r[1]
            if rejdts:
                rejvar = r[0]
                rejdts = [datetime.strptime(x[0:-5], '%Y-%m-%dT%H:%M:%S') for x in rejdts]
                pldf.loc[rejdts, rejvar] = None

        #no need to track imputations that were subsequently rejected
        colbool = ~pldf.columns.isin(['upload_id', 'DateTime_UTC'])
        flagmerge[pldf.loc[:, colbool].isna()] = '0'

        #add imputation "flags" to a new table called autoqaqc
        flagmerge = flagmerge.stack().reset_index()
        flagmerge.columns = ['DateTime_UTC', 'variable', 'qaqc']
        flagmerge = flagmerge.loc[flagmerge.qaqc != '0', :].reset_index(drop=True)
        fm_nrow = flagmerge.shape[0]
        rsdf = pd.DataFrame({'region': np.repeat(region, fm_nrow),
            'site': np.repeat(site, fm_nrow)})
        flagmerge = pd.concat([rsdf, flagmerge], axis=1)
        chunker_ingester(flagmerge, Autoqaqc)

        #insert post-pipeline, post-user-edit dataset into data table
        pldf = pldf.reset_index().set_index(['DateTime_UTC', 'upload_id'])
        pldf.columns.name = 'variable'
        pldf = pldf.stack() #one col each for vars and vals
        pldf.name = "value"
        pldf = pldf.reset_index()
        pldf = pldf.groupby(['DateTime_UTC','variable']).mean().reset_index() #dupes
        pldf['region'] = region
        pldf['site'] = site
        pldf['flag'] = None
        pldf = pldf[['region','site','DateTime_UTC','variable','value','flag',
            'upload_id']]

        updatedb(pldf, up_data['fn_to_db'], replace)

        # flagids = userflagpts['WaterTemp_C']['id']
        # dts = userflagpts['WaterTemp_C']['dt']
        # i = 0

        #parse user-added flags and flag removals...
        newflagid = -1 #series split by removals must be regarded as multiple flag instances
        # f = list(userflagpts.items())[0]
        for f in userflagpts.items():

            mod_switch = False #don't add new flag id when this is off
            flagdeetmap = {} #hold mappings between new (neg) flag ids and original comments
            flagids = f[1]['id']
            dts = f[1]['dt']

            if flagids:
                if any([x == 'rm' for x in flagids]):
                    try:
                        runid = next(x for x in flagids if x != 'rm')
                    except:
                        continue
                    for i in range(1, len(flagids)):
                        if flagids[i] == 'rm' and i >= (len(flagids) - 1):
                            break #end of series
                        elif flagids[i] == 'rm': #get ready to add new flag id
                            if flagids[i + 1] == runid:
                                newflagid -= 1
                                mod_switch = True
                            elif flagids[i + 1] == 'rm':
                                continue
                        elif flagids[i] != runid: #non-rm-induced flag id break
                            newflagid -= 1
                            runid = flagids[i]
                            mod_switch = False
                        elif flagids[i] == runid and mod_switch: #insert new flag id
                            if newflagid not in flagdeetmap.keys():
                                flagdeetmap[newflagid] = flagids[i]
                            flagids[i] = newflagid

                    #get rid of flag removal indicators (i.e. flag sequence separators)
                    rminds = [i for i, item in enumerate(flagids) if item == 'rm']
                    rminds.reverse()
                    for x in rminds:
                        flagids.pop(x)
                        dts.pop(x)

                #insert new flag data into db (flag table and data table)
                uniqids = [x for x in set(flagids) if not isinstance(x, str)]
                dts = [datetime.strptime(x[0:-5], '%Y-%m-%dT%H:%M:%S') for x in dts]

                # i = 0
                for i in range(len(uniqids)):
                    u = uniqids[i]
                    sdt = dts[flagids.index(u)]
                    edt = dts[::-1][flagids[::-1].index(u)]
                    fvr = f[0]
                    u = flagdeetmap[u] if u < 0 else u
                    flg, cmt = next( (x['flagid'], x['comment']) for x\
                        in userflags if x['instance_id'] == u)

                    z = Flag(region, site, sdt, edt, fvr, flg, cmt, int(current_user.get_id()))
                    db.session.add(z)
                    flgdat = Data.query.filter(Data.region == region,
                        Data.site == site, Data.DateTime_UTC >= sdt,
                        Data.DateTime_UTC <= edt, Data.variable == fvr).all()

                    for fd in flgdat:
                        fd.flag = z.id

        # os.path.join(app.config['UPLOAD_ORIG_FOLDER'], )
        # feather.write_dataframe('../spdumps/' + tmpcode + '_orig.feather')

        # make a new text file with the metadata
        lvltxt = '\n\n--- Data status codes ---\n\n' +\
            'Data level codes:\n' +\
            '\tR: Raw (directly from sensor/logger)\n' +\
            '\tO: Outliers/anomalies removed\n' +\
            '\tG: Gaps imputed\n' +\
            '\tC: Corrected for drift (due to biofouling, calibration, etc.)\n' +\
            '\tD: Derived from other variables\n' +\
            '\t-: No information\n\n--- Data status by variable ---\n\n'

        metafilepath = os.path.join(app.config['META_FOLDER'],
            region + "_" + site + "_metadata.txt")
        leveldata = pd.read_sql("select dbcol, level, notes from cols where region = '" +\
            region + "' and site = '" + site + "';", db.engine)
        leveldata = leveldata.loc[~leveldata.dbcol.isin(['DateTime_UTC',
            'Battery_V']), :]
        leveldata.columns = ['Variable', 'StatusCodes', 'VariableDerivation']
        leveldata = leveldata.mask(leveldata == '', '-')
        lvltxt2 = leveldata.to_string() + '\n'
        lvltxt = lvltxt + lvltxt2

        # if request.form['existing'] == "no":
        if up_data['existing'] == "no":
            metastring = up_data['metadata']
            metastring = metastring + lvltxt
            with open(metafilepath, 'a') as metafile:
                metafile.write(lvltxt)
        else:
            #update level data in metadata files
            if os.path.isfile(metafilepath):
                with open(metafilepath, 'r') as m:
                    metatext = m.read()
                meta1 = metatext.split('--- Data status codes ---')[0]
                lvltxt = meta1 + lvltxt

            with open(metafilepath, 'w') as m:
                m.write(lvltxt)

    except Exception as e:

        tb = traceback.format_exc()

        if 'pldf' in locals():
            df_head = pldf.head(2).to_string()
        else:
            df_head = 'PLDF NOT IN LOCALS!'

        log_rawcols = '\n\nrawcols: ' + ', '.join(list(up_data['cdict'].keys()))
        log_dbcols = '\ndbcols: ' + ', '.join(list(up_data['cdict'].values()))

        if up_data['existing'] == "no":
            error_details = '\n\nusgs: ' + up_data['usgs'] + '\nsitename: ' +\
                up_data['site'] + '\nlat: ' + up_data['lat'] +\
                '\nlon: ' + up_data['lng'] + '\nembargo: ' +\
                up_data['embargo'] + '\ncontactname: ' +\
                up_data['contactName'] + '\ncontactemail: ' +\
                up_data['contactEmail'] +\
                '\n\nfn_to_db: ' + ', '.join(up_data['fn_to_db']) + '\nreplace: ' +\
                replace + '\n\n'
        else:
            error_details = '\n\nfn_to_db: ' + ', '.join(up_data['fn_to_db']) +\
                '\nreplace: ' + replace + '\n\n'

        if replace == 'records':
            errno = 'E009b'
            msg = Markup('Error 009b. StreamPULSE development has been notified.')
            # msg = Markup("Error 009b. Try reducing the size of your revised " +\
            #     "file by removing rows or columns that don't require revision.")
        else:
            errno = 'E009a'
            msg = Markup('Error 009a. StreamPULSE development has been notified.')

        full_error_detail = tb + error_details + df_head + log_rawcols + log_dbcols
        log_exception(errno, full_error_detail)
        email_msg(full_error_detail, 'sp err', 'streampulse.info@gmail.com')

        try:
            os.remove(os.path.join(app.config['UPLOAD_FOLDER'], tmpcode + ".csv"))
            [os.remove(f) for f in up_data['fnlong']]
            db.session.rollback()
        except:
            pass
        flash(msg, 'alert-danger')

        return redirect(url_for('series_upload'))

    try:
        os.remove(os.path.join(app.config['UPLOAD_FOLDER'], tmpcode + ".csv"))
    except:
        pass
    db.session.commit() #persist all db changes made during upload
    flash('Uploaded ' + str(len(pldf.index)) + ' values, thank you!',
        'alert-success')

    return redirect(url_for('series_upload'))

@app.route("/grab_upload_confirm", methods=["POST"])
def grab_confirmcolumns():

    try:

        #retrieve variables from request, session, and filesystem
        cdict = json.loads(request.form['cdict'])
        mdict = json.loads(request.form['mdict'])
        #remove Nones introduced when setting a prepopulated variable to blank
        mdict = [m for m in mdict if m is not None]
        wdict = json.loads(request.form['wdict'])
        adict = json.loads(request.form['adict'])
        fnlong = session.get('fnlong')
        xx = pd.read_csv(fnlong, parse_dates=[0])
        filenameNoV = session.get('filenameNoV')
        region = filenameNoV.split('_')[0]

        #sanitize inputs
        input_dict = {'contactName':'contact name', 'lat':'latitude',
            'lng':'longitude', 'datum':'datum', 'sitename':'site name', 'usgs':'USGS gage ID'}
        illegal_input = None

        for i in range(int(request.form['newlen'])):

            input_is_legal = sanitize_input_email(request.form['contactEmail' + str(i)])
            if not input_is_legal:
                illegal_input = 'contact email'

            if not illegal_input:

                for j in list(input_dict.keys()):
                    input_is_legal = sanitize_input_allow_unicode(request.form[j + str(i)])
                    if not input_is_legal:
                        illegal_input = input_dict[j]
                        break

            if illegal_input:
                if illegal_input == 'contact email':
                    msg = Markup('Only alphanumeric characters and @.- _~' +\
                        ' allowed in email address field')
                else:
                    msg = Markup('Only alphanumeric characters, spaces, and dashes ' +\
                        'allowed in ' + illegal_input + ' field.')

                flash(msg, 'alert-danger')
                return redirect(url_for('grab_upload'))

        #get list of all filenames on record
        all_fnames = list(pd.read_sql('select distinct filename from grabupload',
            db.engine).filename)

        #if this filename has not been seen before...
        if filenameNoV not in all_fnames:

            update_upload_table = True

            #find out what next upload_id will be
            last_upID = pd.read_sql("select max(id) as m from grabupload",
                db.engine)
            last_upID = list(last_upID.m)[0]

            if last_upID:
                upID = last_upID + 1
            else:
                upID = 1

                #reset auto increment for grabupload table
                db.engine.execute('alter table grabupload auto_increment=1')

        else:
            update_upload_table = False

            #retrieve upload_id
            upID = pd.read_sql("select id from grabupload where filename='" +\
                filenameNoV + "'", db.engine)
            upID = list(upID.id)[0]

        #parse input dict objects into usable dictionaries
        cdict = dict([(r['name'], r['value']) for r in cdict])
        mdict = dict([(r['name'], r['value']) for r in mdict])
        wdict = dict([(r['name'], r['value']) for r in wdict])
        adict = dict([(r['name'], r['value']) for r in adict])

        #if there are new sites, process them
        if request.form['new_sites'] == "true":

            #for each new site included in the uploaded csv...
            newsitelist = []
            for i in range(int(request.form['newlen'])):

                #get the name, split into site and region components
                newsite = request.form['newsite' + str(i)]
                region, site = newsite.split('_')[0:2]
                newsitelist.append(site)

                #get usgs number if applicable
                usgss = request.form['usgs' + str(i)]
                if usgss == '':
                    usgss = None

                # add new site to Site table
                sx = Site(region=region, site=site, by=current_user.get_id(),
                    name=request.form['sitename' + str(i)],
                    latitude=request.form['lat' + str(i)],
                    longitude=request.form['lng' + str(i)],
                    datum=request.form['datum' + str(i)],
                    usgs=usgss, addDate=datetime.utcnow(),
                    embargo=request.form['embargo' + str(i)],
                    contact=request.form['contactName' + str(i)],
                    contactEmail=request.form['contactEmail' + str(i)])
                db.session.add(sx)

                # make a new text file with the metadata
                metastring = request.form['metadata' + str(i)]
                metafilepath = os.path.join(app.config['META_FOLDER'],
                    region + "_" + site + "_metadata.txt")

                with open(metafilepath, 'a') as metafile:
                    metafile.write(metastring)

            #give uploading user access to these new sites
            add_site_permission(current_user, region, newsitelist)
            db.session.commit()

        #replace user varnames with database varnames; attach upload_id column
        # xx_pre = xx.iloc[:,0:2]
        # xx_post = xx.iloc[:,2:]
        # xx_post = xx_post[cdict.keys()].rename(columns=cdict) #assign names
        # xx = pd.concat([xx_pre, xx_post], axis=1)
        cols_to_drop = [i for i in xx.columns[2:] if i not in list(cdict.keys())]
        xx = xx.drop(cols_to_drop, axis=1)
        xx['upload_id'] = upID

        #format df for database entry
        xx = xx.set_index(["DateTime_UTC", "upload_id", "Sitecode"])
        xx.columns.name = 'variable'
        xx = xx.stack() #one col each for vars and vals
        xx.name = "value"
        xx = xx.reset_index()

        for i in list(cdict.keys()):
            xx.loc[xx.variable == i, 'method'] = mdict[i]
            xx.loc[xx.variable == i, 'write_in'] = wdict[i]
            xx.loc[xx.variable == i, 'addtl'] = adict[i]
            xx.loc[xx.variable == i, 'variable'] = cdict[i]

        xx = xx.groupby(['DateTime_UTC', 'variable', 'Sitecode', 'method',
            'write_in', 'addtl']).mean().reset_index() #average dupes
        xx['region'] = region
        xx['flag'] = None
        xx.rename(columns={'Sitecode':'site'}, inplace=True)
        xx = xx[['region','site','DateTime_UTC','variable','value','method',
            'flag','write_in','addtl','upload_id']]

        replace = True if request.form['replacing']=='true' else False

        if update_upload_table:
            uq = Grabupload(filename=filenameNoV,
                uploadtime_utc=datetime.utcnow(), user_id=current_user.get_id())
            db.session.add(uq)

        #add data and varname mappings to db tables
        grab_updatedb(xx, [filenameNoV], replace)
        sitelist = list(set(xx.site))
        grab_updatecdict(region, sitelist, cdict, mdict, wdict, adict)

    except Exception as e:
        tb = traceback.format_exc()
        log_exception('E005', tb)
        msg = Markup('Error 005. Please <a href="mailto:michael.vlah@duke.edu"' +\
            ' class="alert-link">email StreamPULSE development</a> ' +\
            'with the error number and a copy of the file you tried to upload.')
        flash(msg, 'alert-danger')

        return redirect(request.url)

    db.session.commit() #persist all db changes made during upload
    session['upload_complete'] = True
    flash('Uploaded ' + str(len(xx.index)) + ' values, thank you!',
        'alert-success')

    return redirect(url_for('grab_upload'))

def add_site_permission(user, region, site_list):

    #get string of comma separated region_site combo(s) from user input
    if type(site_list) is not list:
        site_list = [site_list]
    regsites = ','.join([region + '_' + x for x in site_list])

    #update the existing user permissions string with new region_site combo(s)
    site_permiss = list(pd.read_sql('select qaqc from user where username="' +\
        user.username + '";', db.engine).qaqc)

    if site_permiss[0]:
        site_permiss = site_permiss[0] + ',' + regsites
    else:
        site_permiss = regsites

    cx = User.query.filter_by(username=user.username).first()
    cx.qaqc = site_permiss

def getsitenames(regionsite):
    region, site = regionsite.split("_")
    names = pd.read_sql("select name from site where region='" + region +\
        "' and site ='" + site + "'", db.engine)
    return (regionsite, region + " - " + names.name[0])

@app.route('/download')
def download():

    #acquire SP site data and filter rows by authenticated sites
    sitedata = pd.read_sql("select region, site, name, variableList " +\
        "as variable, firstRecord as startdate, lastRecord as enddate " +\
        "from site where `by` != '-902' and variableList is not NULL;", db.engine)
    sitedata['regionsite'] = [x[0] + "_" + x[1] for x in zip(sitedata.region,
        sitedata.site)]

    if current_user.is_authenticated:
        sites = authenticate_sites(sitedata.regionsite,
            user=current_user.get_id())
    else:
        sites = authenticate_sites(sitedata.regionsite)

    sitedata = sitedata[sitedata.regionsite.isin(sites) &
        sitedata.variable.notnull()] #redundant, but negligible cost

    #reformat and filter columns; return data as list of tuples
    sitedata.variable = sitedata.variable.apply(lambda x: x.split(','))
    sitedata.startdate = sitedata.startdate.apply(lambda x:
        x.strftime('%Y-%m-%d'))
    sitedata.enddate = sitedata.enddate.apply(lambda x:
        x.strftime('%Y-%m-%d'))
    sitedata.name = sitedata.region + " - " + sitedata.name
    dvv = sitedata[['regionsite','name','startdate','enddate','variable']]
    dvv.iloc[:,0:2] = dvv.iloc[:,0:2].apply(lambda x:
        x.str.decode('unicode_escape'))
    dvv = dvv.values
    sitedict = sorted([list(x) for x in dvv], key=lambda tup: tup[1])

    #separating powell/sp data could be final step to save some time, but
    #i'm allowing reduncancy here because the execution time cost is lower than
    #the cost of reorganization
    sitedataP = pd.read_sql("select region, site, name, variableList " +\
        "as variable, firstRecord as startdate, lastRecord as enddate " +\
        "from site where `by` = '-902' and variableList is not NULL;", db.engine)
    sitedataP['regionsite'] = [x[0] + "_" + x[1] for x in zip(sitedataP.region,
        sitedataP.site)]

    #powell data: reformat and filter columns; return data as nested lists
    sitedataP.variable = sitedataP.variable.apply(lambda x: x.split(','))
    sitedataP.startdate = sitedataP.startdate.apply(lambda x:
        x.strftime('%Y-%m-%d'))
    sitedataP.enddate = sitedataP.enddate.apply(lambda x:
        x.strftime('%Y-%m-%d'))
    sitedataP.name = sitedataP.region + " - " + sitedataP.name
    dvvP = sitedataP[['regionsite','name','startdate','enddate','variable']]
    dvvP.iloc[:,0:2] = dvvP.iloc[:,0:2].apply(lambda x:
        x.str.decode('unicode_escape'))
    dvvP = dvvP.values
    sitedictP = sorted([list(x) for x in dvvP], key=lambda tup: tup[1])

    #list available reach characterization datasets, replace synoptic fns with 'synoptic'
    sd_files = os.listdir(app.config['REACH_CHAR_FOLDER'])
    reg_dset_list = [re.match('^([A-Za-z]{2})_(.*)?.csv$',
        s).groups() for s in sd_files]
    reg_dset_list = [(x[0],
        'synoptic') if 'synoptic' in x[1] else x for x in reg_dset_list]
    reg_dset_list = list(set(reg_dset_list))
    reg_set = set([x[0] for x in reg_dset_list])

    reg_dset_dict = {}
    for e in reg_set:
        reg_dset_dict[e] = [ee[1] for ee in reg_dset_list if ee[0] == e]

    return render_template('download.html', sites=sitedict,
        powell_sites=sitedictP, reach_char_map=reg_dset_dict)

@app.route('/_getstats', methods=['POST'])
def getstats():
    sitenm = request.json['site']
    xx = pd.read_sql("select * from data where concat(region,'_',site) in ('"+"', '".join(sitenm)+"') and flag is NULL", db.engine)
    startDate = xx.DateTime_UTC.min().strftime("%Y-%m-%d")
    endDate = (xx.DateTime_UTC.max()+timedelta(days=1)).strftime("%Y-%m-%d")
    initDate = (xx.DateTime_UTC.max()-timedelta(days=13)).strftime("%Y-%m-%d")
    #xx = pd.read_sql("select distinct variable from data", db.engine)
    variables = list(set(xx.variable))#xx['variable'].tolist()
    return jsonify(result="Success", startDate=startDate, endDate=endDate, initDate=initDate, variables=variables, site=sitenm)

@app.route('/_getcsv', methods=["POST"])
def getcsv():

    #retrieve form specifications
    sitenm = request.form['sites'].split(",")
    regionlist = [x.split('_')[0] for x in sitenm]
    startDate = request.form['startDate']#.split("T")[0]
    endDate = request.form['endDate']
    variables = request.form['variables'].split(",")
    email = request.form.get('email')
    canopy = request.form.get('canopy')
    csect = request.form.get('cross_section')
    geo = request.form.get('geomorphology')
    substrate = request.form.get('substrate')
    # csect = request.form.get('csect')
    # geo = request.form.get('geo')
    # substrate = request.form.get('substrate')
    synoptic = request.form.get('synoptic')
    aggregate = request.form['aggregate']
    dataform = request.form['dataform'] # wide or long format

    if re.match('[a-zA-Z]{2}_nwis-[0-9]+', sitenm[0]):
        src_table = 'powell'
    else:
        src_table = 'data'

    #deal with user info and login creds
    if current_user.get_id() is None: # not logged in
        uid = None
        if email is not None: # record email address
            elist = open("static/email_list.csv","a")
            elist.write(email + "\n")
            elist.close()
    else: # get logged in email
        uid = int(current_user.get_id())
        myuser = User.query.filter(User.id == uid).first()
        email = myuser.email

    # add download stats to db table
    dnld_stat = Downloads(timestamp=datetime.utcnow(), userID=uid, email=email,
        dnld_sites=request.form['sites'], dnld_date0=startDate,
        dnld_date1=endDate, dnld_vars=request.form['variables'])
    db.session.add(dnld_stat)
    db.session.commit() #should be at end of function

    #make temp directory and store data policy there
    tmp = tempfile.mkdtemp()
    shutil.copy2("static/streampulse_data_policy.txt", tmp)

    #get data, metadata, etc for each site and put in temp directory
    nograbsites = []
    for s in sitenm:

        # get sensor data and flags for site s
        sqlq = "select " + src_table + ".*, flag.flag as flagtype, flag.comment as " +\
            "flagcomment from " + src_table +\
            " left join flag on " + src_table + ".flag=flag.id where concat(" + src_table + ".region, " +\
            "'_', " + src_table + ".site)='" + s + "' and " + src_table + ".DateTime_UTC > '" +\
            startDate + "' and " + src_table + ".DateTime_UTC < '" + endDate + "' " +\
            "and " + src_table + ".variable in ('" + "', '".join(variables) + "');"
        xx = pd.read_sql(sqlq, db.engine)

        if len(xx) < 1:
            continue

        # set NA values, then drop them (currently not doing anything)
        xx.loc[xx.flag == 0, "value"] = None
        xx.dropna(subset=['value'], inplace=True)

        #remove flag data if not desired by user
        if request.form.get('flag') is not None:
            xx.drop(['id','flag','upload_id'], axis=1, inplace=True)
        else:
            xx.drop(['id','flag','flagtype','flagcomment','upload_id'], axis=1,
                inplace=True)

        #acquire discharge and depth from USGS if desired
        if request.form.get('usgs') is not None:
            #xu = get_usgs([s],startDate,endDate)
            # print xx['DateTime_UTC'].min()
            xu = get_usgs([s], xx['DateTime_UTC'].min().strftime("%Y-%m-%d"),
            xx['DateTime_UTC'].max().strftime("%Y-%m-%d"), ['00060', '00065'])
            df_index = xx.columns
            if len(xu) is not 0:
                xx = pd.concat([xx,xu])
                xx = xx.reindex_axis(df_index, axis=1)

        #get grab (manually sampled) data if desired
        if request.form.get('grab') is not None:
            sqlq2 = "select region, site, DateTime_UTC, variable, value, " +\
                "method, write_in, addtl " +\
                "from grabdata where concat(region, " +\
                "'_', site)='" + s + "' and DateTime_UTC > '" +\
                startDate + "' and DateTime_UTC < '" + endDate + "';"
            grabdata = pd.read_sql(sqlq2, db.engine)

            #if data available, write dataframe to CSV in temp directory
            if grabdata.shape[0] > 0:
                grabdata.to_csv(tmp + '/' + s + '_grabData.csv', index=False)
            else:
                nograbsites.append(s)

        # check for doubles with same datetime, region, site, variable...
        xx = xx.set_index(["DateTime_UTC","region","site","variable"])
        xx = xx[~xx.index.duplicated(keep='last')].sort_index().reset_index()

        #apply aggregation and format preferences for sensor data
        if aggregate != "none":
            xx = xx.set_index(['DateTime_UTC']).groupby(['region',
                'site','variable']).resample(aggregate).mean().reset_index()
        if dataform == "wide":
            xx = xx.pivot_table("value", ['region','site','DateTime_UTC'],
                'variable').reset_index()

        #write sensor dataframes to CSV file in temp directory
        xx.to_csv(tmp + '/' + s + '_sensorData.csv', index=False)

        #put additional metadata in folder if metdata file exists
        mdfile = os.path.join(app.config['META_FOLDER'], s + "_metadata.txt")
        if os.path.isfile(mdfile):
            shutil.copy2(mdfile, tmp)

    #write site data to CSV in temp dir
    sitequery = "select region, site, name, latitude, longitude, datum, usgs" +\
        " as usgsGage" +\
        ", contact, contactEmail from site where concat(region, '_'," +\
        " site) in ('" + "','".join(sitenm) + "');"
    sitedata = pd.read_sql(sitequery, db.engine)
    sitedata.to_csv(tmp + '/siteData.csv', index=False, encoding='utf-8')

    #determine which site characteristic datasets the user wants
    sitechar_reqs = {}
    sitechar_reqs['_canopy.csv'] = True if canopy else False
    sitechar_reqs['_cross_section.csv'] = True if csect else False
    sitechar_reqs['_substrate.csv'] = True if substrate else False
    sitechar_reqs['_geomorphology.csv'] = True if geo else False
    sitechar_sel = [x[0] for x in list(sitechar_reqs.items()) if x[1]]
    if synoptic:
        sitechar_sel.extend(['_synoptic' + x for x in sitechar_sel])

    #add desired site characteristic datasets to subdirectory of temp file
    sd_files = os.listdir(app.config['REACH_CHAR_FOLDER'])
    # regionset = set([x.split('_')[0] for x in sd_files])
    sitechar_filelist = []
    for s in sd_files:
        sd_reg, sd_set = re.match('^([A-Za-z]{2})(_.*)$', s).groups()
        if sd_reg in regionlist and sd_set in sitechar_sel:
            sitechar_filelist.append(app.config['REACH_CHAR_FOLDER'] + '/' + s)

    if sitechar_filelist:
        os.mkdir(tmp + '/reach_characterization_datasets')
        for s in sitechar_filelist:
            shutil.copy2(s, tmp + '/reach_characterization_datasets')

    #add readme with notes if needed
    if nograbsites:
        with open(tmp + '/' + 'readme.txt', 'w') as readme:
            readme.write('Note: No manually collected data available at ' +\
                'specified time for site(s): ' + ', '.join(nograbsites) + '.')
            readme.close()

    #zip all files in temp dir as new zip dir, pass on to user (old, nonrecursive way)
    # writefiles = os.listdir(tmp) # list files in the temp directory
    # zipname = 'SPdata_' + datetime.now().strftime("%Y-%m-%d") + '.zip'
    # with zipfile.ZipFile(tmp + '/' + zipname, 'w') as zf:
    #     [zf.write(tmp + '/' + f, f) for f in writefiles]
    # flash('File sent: ' + zipname, 'alert-success')

    #recursively zip all files in temp dir as new zip dir, pass on to user
    writefiles = zipfile_listdir_recursive(tmp)
    rel_wfs = [re.match(tmp + '/(.*)', f).group(1) for f in writefiles]
    zipname = 'SPdata_' + datetime.now().strftime("%Y-%m-%d") + '.zip'
    zf = zipfile.ZipFile(tmp + '/' + zipname, 'w')
    for i in range(len(writefiles)):
        zf.write(writefiles[i], rel_wfs[i])
    zf.close()

    return send_file(tmp + '/' + zipname, 'application/zip',
        as_attachment=True, attachment_filename=zipname)

@app.route('/visualize')
def visualize():

    #acquire site data and filter rows by authenticated sites
    sitedata = pd.read_sql("select region, site, name, variableList " +\
        "as variable, firstRecord as startdate, lastRecord as enddate " +\
        "from site where `by` != -902;", db.engine)
    sitedata['regionsite'] = [x[0] + "_" + x[1] for x in zip(sitedata.region,
        sitedata.site)]

    if current_user.is_authenticated:
        sites = authenticate_sites(sitedata.regionsite,
            user=current_user.get_id())
    else:
        sites = authenticate_sites(sitedata.regionsite)

    sitedata = sitedata[sitedata.regionsite.isin(sites) &
        sitedata.variable.notnull()]

    #reformat and filter columns; return data as dict
    sitedata.variable = sitedata.variable.apply(lambda x: x.split(','))
    sitedata.startdate = sitedata.startdate.apply(lambda x:
        x.strftime('%Y-%m-%d'))
    sitedata.enddate = sitedata.enddate.apply(lambda x:
        x.strftime('%Y-%m-%d'))
    sitedata.name = sitedata.region + " - " + sitedata.name
    dvv = sitedata[['regionsite','name','startdate','enddate','variable']]
    dvv.iloc[:,1:2] = dvv.iloc[:,1:2].apply(lambda x:
        x.str.decode('unicode_escape'))
    dvv = dvv.values
    sitedict = sorted([list(x) for x in dvv], key=lambda tup: tup[1])

    #separating powell/sp data could be final step to save some time, but
    #i'm allowing reduncancy here because the execution time cost is lower than
    #the cost of reorganization
    sitedataP = pd.read_sql("select region, site, name, variableList " +\
        "as variable, firstRecord as startdate, lastRecord as enddate " +\
        "from site where `by` = '-902' and variableList is not NULL;", db.engine)
    sitedataP['regionsite'] = [x[0] + "_" + x[1] for x in zip(sitedataP.region,
        sitedataP.site)]

    #powell data: reformat and filter columns; return data as nested lists
    sitedataP.variable = sitedataP.variable.apply(lambda x: x.split(','))
    sitedataP.startdate = sitedataP.startdate.apply(lambda x:
        x.strftime('%Y-%m-%d'))
    sitedataP.enddate = sitedataP.enddate.apply(lambda x:
        x.strftime('%Y-%m-%d'))
    sitedataP.name = sitedataP.region + " - " + sitedataP.name
    dvvP = sitedataP[['regionsite','name','startdate','enddate','variable']]
    dvvP.iloc[:,1:2] = dvvP.iloc[:,1:2].apply(lambda x:
        x.str.decode('unicode_escape'))
    dvvP = dvvP.values
    sitedictP = sorted([list(x) for x in dvvP], key=lambda tup: tup[1])

    #get set of sites for which models have been fit (for overlays)
    outputs = os.listdir(cfg.RESULTS_FOLDER)
    avail_mods = list(set([o[7:len(o) - 9] for o in outputs if o[0:3] == 'mod']))

    return render_template('visualize.html', sites=sitedict,
        powell_sites=sitedictP, avail_mods=avail_mods)

@app.route('/_getgrabvars', methods=["POST"])
def getgrabvars():

    #get data from ajax call
    data = request.json
    region, site = data[0].split('_')
    startdate = data[1]
    enddate = data[2]

    #get list of grab vars from grabdata table
    sqlq = "select distinct variable as d from grabdata where region='" +\
        region + "' and site='" + site + "' " + "and DateTime_UTC>'" +\
        startdate + "' " + "and DateTime_UTC<'" + enddate + "';"
    grabvars = list(pd.read_sql(sqlq, db.engine)['d'])

    grabvarunits = []
    for g in grabvars:
        for v in grab_variables:
            if v['var'] == g:
                grabvarunits.append(v['unit'])
                continue

    return jsonify(variables=grabvars, varsandunits=grabvarunits)

@app.route('/_getgrabviz', methods=["POST"])
def getgrabviz():

    # region, site = request.json['regionsite'].split(",")[0].split("_")
    region, site = request.json['regionsite'].split("_")
    startDate = request.json['startDate']
    endDate = request.json['endDate']
    variables = request.json['grabvars']
    unit = request.json.get('unit')

    # variables = variables] if len(variables)
    # region='NC'; site='NHC'; startDate='2017-05-01'; endDate='2017-09-01'; variables=['Ca']

    if variables[0] != 'None':

        #query partly set up for when this function will need to handle multiple vars
        sqlq = "select grabdata.DateTime_UTC as date, grabdata.value as " + variables[0] +\
            ", grabdata.flag as flagid, grabflag.flag, grabflag.comment " +\
            " from grabdata left join grabflag on grabdata.flag=grabflag.id " +\
            "where grabdata.region='" +\
            region + "' and grabdata.site='" +\
            site + "' " + "and grabdata.DateTime_UTC > '" + startDate + "' " +\
            "and grabdata.DateTime_UTC < '" + endDate + "' " +\
            "and grabdata.variable in ('" + "', '".join(variables) + "');"

        xx = pd.read_sql(sqlq, db.engine)

        xx = xx[xx.flag != 'Bad Data'] #remove bad data rows
        # flagdat = xx[['date', 'flagid', 'flag',
        #     'comment']].dropna().drop(['flagid'], axis=1)
        # flagdat.to_json(orient='records', date_format='iso')

        #some datetime-value pairs may be duplicated, and only one is flagged. sending all flag
        #data results in good points receiving "bad data" labels, so remove those flags
        xx = xx.drop_duplicates(subset=['date', variables[0]], keep='last')

        #average values across duplicated dates; format for export
        # xx = xx.drop(['flagid', 'flag', 'comment'], axis=1)
        # xx = xx.groupby(xx.date).mean().reset_index()
        xx = xx.to_json(orient='records', date_format='iso')

    else:
        xx = 'None'

    # return jsonify(grabdat=xx, var=variables[0], flagdat=flagdat)
    return jsonify(grabdat=xx, var=variables[0], unit=unit)

@app.route('/_interquartile', methods=["POST"])
def interquartile():

    var = request.json['variable']
    dsource = request.json['source']
    src = 'powell' if dsource == 'pow' else 'data'
    region, site = request.json['site'].split('_')
    # region='VT'; site='Pass'; var='DO_mgL'

    if(var not in ['ER', 'GPP']):
        pre_agg = pd.read_sql("select concat(mid(DateTime_UTC, 6, 5)," +\
            "'T') as " +\
            "time, value as val from " + src +\
            " where region='" + region + "' and site='" + site +\
            "' and variable='" + var + "';", db.engine)
    else:
        outputs = os.listdir(cfg.RESULTS_FOLDER)
        outputs_keep = []
        for o in outputs:
            m = re.match('predictions_([a-zA-Z0-9]{2})_(.+)_[0-9]{4}.rds$', o)
            if m:
                reg, sit = m.groups()
                if sit == site and reg == region:
                    outputs_keep.append(o)

        r_func_def = 'function(file){' +\
                         'x = readRDS(file);' +\
                         'x$date = as.character(x$date);' +\
                         'return(x);' +\
                     '}'
        r_func = robjects.r(r_func_def)

        pre_agg = pd.DataFrame()
        for o in outputs_keep:
            df = r_func(cfg.RESULTS_FOLDER + '/' + o)
            df = pandas2ri.ri2py(df)

            if var == 'ER':
                o_pre_agg = pd.concat([df.date.str[5:10] + 'T', df.ER], axis=1)
            else:
                o_pre_agg = pd.concat([df.date.str[5:10] + 'T', df.GPP], axis=1)

            pre_agg = pre_agg.append(o_pre_agg, ignore_index=True)

        pre_agg.columns = ['time', 'val']
        pre_agg = pre_agg.dropna(how='any').reset_index(drop=True)

    def quant25(x):
        return x.quantile(.25)
    def quant75(x):
        return x.quantile(.75)

    quantiles = pre_agg.pivot_table(index='time', values='val',
        aggfunc=[quant25, quant75]).reset_index()

    return jsonify(dat=quantiles.to_json(orient='values'))

@app.route('/_getviz', methods=["POST"])
def getviz():

    region, site = request.json['site'].split(",")[0].split("_")
    startDate = request.json['startDate']
    endDate = request.json['endDate']#.split("T")[0]
    variables = request.json['variables']
    dsource = request.json['source']
    src = 'powell' if dsource == 'pow' else 'data'
    # region='NC'; site='NHC'; startDate='2017-11-01'; endDate='2018-01-01'
    # region='AK'; site='CARI-down'; startDate='2018-04-01'; endDate='2018-04-20'
    # variables=['DO_mgL','WaterTemp_C','Light_lux']; src='data'

    #this block shouldnt be necessary once data leveling is in place.
    #you'll then be able to restore the block below, unless we still
    #want to incorporate detailed flag info then, which I suppose we might
    # sqlq_sp = "select data.region, data.site, data.DateTime_UTC, " +\
    #     "data.variable, data.value, data.flag as flagid, flag.flag, " +\
    #     "flag.comment from data left join flag on data.flag=flag.id where " +\
    #     "data.region='" + region + "' and data.site='" + site +\
    #     "' and data.DateTime_UTC>'" + startDate + "' " +\
    #     "and data.DateTime_UTC<'" + endDate + "' " +\
    #     "and data.variable in ('" + "', '".join(variables) + "')"

    sqlq = "select " + src + ".region, " + src + ".site, " + src + ".DateTime_UTC, " +\
        src + ".variable, " + src + ".value, " + src + ".flag as flagid, flag.flag, " +\
        "flag.comment from " + src + " left join flag on " + src + ".flag=flag.id where " +\
        src + ".region='" + region + "' and " + src + ".site='" + site +\
        "' and " + src + ".DateTime_UTC>'" + startDate + "' " +\
        "and " + src + ".DateTime_UTC<'" + endDate + "' " +\
        "and " + src + ".variable in ('" + "', '".join(variables) + "')"

    # sqlq = sqlq_powell if dsource == 'pow' else sqlq_sp

    xx = pd.read_sql(sqlq, db.engine)
    # xx.loc[xx.flag == 'Bad Data', 'value'] = None # set NaNs so bad datapoints dont plot
    xx = xx[xx.flag != 'Bad Data'] #instead, just remove bad data rows
    # xx.loc[(xx.variable == 'DO_mgL') & (xx.index < 8),'value'] = -888

    #thin data to 1/15 if data source is NEON
    is_neon = pd.read_sql("select `by` from site where region='" + region +\
        "' and site='" + site + "';", db.engine).by[0] == -900
    if is_neon:
        xx = xx.iloc[np.arange(0, xx.shape[0], 15), :]

    #append value to flag comment for very negative flagged values, so value
    #can be included in mouseover text
    xx.comment[xx.value < -10] = xx.value.round(5).apply(str) + ';;;' + xx.comment

    flagdat = xx[['DateTime_UTC', 'variable', 'flagid', 'flag',
        'comment']].dropna().drop(['flagid'], axis=1)

    #separate very negative values without flags
    ufv = xx[((xx.value < -10) & (xx.comment.isnull()) & (xx.variable != 'AirTemp_C')) |\
        ((xx.value < 0) & (xx.comment.isnull()) & (xx.variable == 'DO_mgL'))]
    # ufv = xx[(xx.value < -10) & (xx.comment.isnull()) & (~xx.variable.isin(['AirTemp_C',
    #     'WaterTemp_C']))]
    ufv['display_val'] = -9.99095 #left for compatibility with old numpy
    ufv.loc[ufv.variable == 'DO_mgL', 'display_val'] = 0.00095
    # ufv.loc[:, 'display_val'] = -9.99095

    #very negative (and thus erroneous points) will show up as arrows at y~-10.
    #(or y~0 for DO)
    xx.value[(xx.value < -10) & (xx.variable != 'AirTemp_C')] = -9.99095
    xx.value[(xx.value < -0) & (xx.variable == 'DO_mgL')] = 0.00095

    #some datetime-value pairs are duplicated, and only one is flagged. sending all flag
    #data results in good points receiving "bad data" labels, so remove those flags
    # flagdat = flagdat[flagdat.flag != 'Bad Data'] #redundant, right?
    xx = xx.drop(['flag', 'comment'], axis=1).drop_duplicates()\
        .set_index(["DateTime_UTC", "variable"])\
        .drop(['region', 'site', 'flagid'], axis=1)

    ufv = ufv.drop(['flag', 'comment'], axis=1).drop_duplicates()\
        .set_index(["DateTime_UTC", "variable", 'display_val'])\
        .drop(['region', 'site', 'flagid'], axis=1)

    # get rid of duplicated date/variable combos and convert to wide format
    xx = xx[~xx.index.duplicated(keep='last')].unstack('variable')
    xx.columns = xx.columns.droplevel()
    xx = xx.reset_index()

    ufv = ufv[~ufv.index.duplicated(keep='last')].unstack('variable')
    ufv.columns = ufv.columns.droplevel()
    ufv = ufv.reset_index()

    # sqlq = "select * from data where region='" + region + "' and site='" +\
    #     site + "' " + "and DateTime_UTC>'" + startDate + "' " +\
    #     "and DateTime_UTC<'" + endDate + "' " +\
    #     "and variable in ('" + "', '".join(variables) + "')"
    # ufv = pd.read_sql(sqlq, db.engine)
    #
    # xx.loc[xx.flag == 0, "value"] = None # set NaNs
    # flagdat = xx[['DateTime_UTC','variable','flag']].dropna().drop(['flag'],
    #     axis=1).to_json(orient='records',date_format='iso') # flag data
    # xx = xx.drop(['id', 'upload_id'], axis=1).drop_duplicates()\
    #   .set_index(["DateTime_UTC", "variable"])\
    #   .drop(['region', 'site', 'flag'], axis=1)
    # xx = xx[~xx.index.duplicated(keep='last')].unstack('variable') # get rid of duplicated date/variable combos
    # xx.columns = xx.columns.droplevel()
    # xx = xx.reset_index()

    # Get sunrise sunset data
    sxx = pd.read_sql("select id, region, site, name, latitude, " +\
        "longitude, usgs, addDate, embargo, site.by, contact, contactEmail " +\
        "from site where region='" + region +\
        "' and site='" + site + "'", db.engine)
    sdt = datetime.strptime(startDate, "%Y-%m-%d")
    edt = datetime.strptime(endDate, "%Y-%m-%d")
    ddt = edt - sdt
    lat = sxx.latitude[0]
    lng = sxx.longitude[0]
    rss = []

    for i in range(ddt.days + 1):
        rise, sets = list(suns(sdt + timedelta(days=int(i) - 1), latitude=lat,
            longitude=lng).calculate())
        if rise > sets:
            sets = sets + timedelta(days=1) # account for UTC
        rss.append([rise, sets])

    rss = pd.DataFrame(rss, columns=("rise", "set"))
    rss.set = rss.set.shift(1)
    sunriseset = rss.loc[1:].to_json(orient='records', date_format='iso')

    return jsonify(variables=variables, sunriseset=sunriseset,
        vnegs_unflag=ufv.to_json(orient='records', date_format='iso'),
        dat=xx.to_json(orient='records', date_format='iso'),
        flagdat=flagdat.to_json(orient='records', date_format='iso'))

@app.route('/logbook')
def print_log():
    with open('templates/logbook.md', 'r') as f:
        logbook_md = f.read()
    logbook_md = Markup(markdown.markdown(logbook_md))
    return render_template('logbook.html', **locals())

@app.route('/clean_choice')
def clean_choice():
    return render_template('qaqc_choice.html')

@app.route('/qaqc_grabdata')
@login_required
def qaqc_grabdata():

    #acquire site data. filter those without grab data, and those without auth
    site_df = pd.read_sql("select concat(region, '_', site) as regionsite, " +\
        "concat(region, ' - ', name) as name, grabVarList as variableList from site;",
        db.engine)
    # all_sites = site_df.regionsite.tolist()
    site_df = site_df[site_df.variableList.notnull()]
    grab_sites = site_df.regionsite.tolist()

    # grab_sites = pd.read_sql("select distinct concat(region, '_', site) as " +\
    #     "regionsite from grabdata;", db.engine).regionsite.tolist()
    # site_df = site_df[site_df.regionsite.isin(grab_sites)]

    # pd.read_sql("select site, group_concat(distinct variable) as variableList from" +\
    #     " grabdata where site in ('NHC', 'Stony');", db.engine)

    qaqcuser = current_user.qaqc_auth()
    auth_sites = [z for z in grab_sites if z in qaqcuser]
    site_df = site_df[site_df.regionsite.isin(auth_sites)]

    #sort, convert to list of tuples, specify flag types
    site_df_sort = site_df.iloc[np.argsort(site_df.name),:]
    tuplist = list(site_df_sort.itertuples(index=False, name=None))
    flags = ['Interesting', 'Questionable', 'Below Detection Limit',
        'Unknown Collection Time', 'Bad Data'] #i think this is obsolete

    #load static html for popup menu
    with open('static/html/qaqcPopupMenu_grab.html', 'r') as html_file:
        qaqc_options_grab = html_file.read()
    qaqc_options_grab = qaqc_options_grab.replace('\n', '')

    return render_template('qaqc_grabdata.html', flags=flags, sitedata=tuplist,
        qaqc_options=qaqc_options_grab)

@app.route('/qaqc_sensordata') #/clean
@login_required
def qaqc():

    #acquire site data and filter by authenticated sites
    resp = pd.read_sql("select concat(region, '_', site) as regionsite, " +\
        "concat(region, ' - ', name) as name, variableList from site;", db.engine)
    all_sites = resp.regionsite.tolist()
    qaqcuser = current_user.qaqc_auth()
    auth_sites = [z for z in all_sites if z in qaqcuser]
    filt = resp[resp.regionsite.isin(auth_sites)]

    #sort, convert to list of tuples, specify flag types
    srt = filt.iloc[np.argsort(filt.name),:]
    tuplist = list(srt.itertuples(index=False, name=None))
    flags = ['Interesting', 'Questionable', 'Bad Data']
    # sitedict = sorted([getsitenames(x) for x in auth_sites],
    #     key=lambda tup: tup[1])

    #load static html for popup menu
    with open('static/html/qaqcPopupMenu_sensor.html', 'r') as html_file:
        qaqc_options_sensor = html_file.read()
    qaqc_options_sensor = qaqc_options_sensor.replace('\n', '')

    return render_template('qaqc.html', flags=flags, tags=[''], sitedata=tuplist,
        qaqc_options=qaqc_options_sensor)

@app.route('/_getqaqc', methods=["POST"])
def getqaqc():

    region, site = request.json['site'].split(",")[0].split("_")
    vars = request.json['vars']
    year = request.json['year']
    # region='FL'; site='SF700'; vars=['DO_mgL']; year='2019'
    # region='FL'; site='SF700'; vars=['DO_mgL', 'Level_m']; year='2019'

    sqlq = "select data.region, data.site, data.DateTime_UTC, " +\
        "data.variable, data.value, data.flag as flagid, flag.flag, " +\
        "flag.comment from data left join flag on data.flag=flag.id where " +\
        "data.region='" + region + "' and data.site='" + site +\
        "' and data.variable in ('" + "','".join(vars) + "') and " +\
        "year(DateTime_UTC) = " + year + ";"
    xx = pd.read_sql(sqlq, db.engine) #this is what makes it take so long. read in 4w chunks
    xx.loc[xx.flag == 0, "value"] = None # set NaNs
    flagdat = xx[['DateTime_UTC', 'variable', 'flagid', 'flag',
        'comment']].dropna().drop(['flagid'],
        axis=1).to_json(orient='records', date_format='iso') # flag data

    variables = xx.loc[:,'variable'].unique().tolist()

    xx = xx.drop(['flag', 'comment'], axis=1).drop_duplicates()\
        .set_index(["DateTime_UTC", "variable"])\
        .drop(['region', 'site', 'flagid'], axis=1)
    xx = xx[~xx.index.duplicated(keep='last')].unstack('variable') # get rid of duplicated date/variable combos
    xx.columns = xx.columns.droplevel()
    xx = xx.reset_index()

    # Get sunrise sunset data
    sxx = pd.read_sql("select latitude, longitude from site where region='" +\
        region + "' and site='" + site + "'", db.engine)
    # sxx = pd.read_sql("select id, region, site, name, latitude, " +\
    #     "longitude, usgs, addDate, embargo, site.by, contact, contactEmail " +\
    #     "from site where region='" + region +\
    #     "' and site='" + site + "'", db.engine)
    sdt = min(xx.DateTime_UTC).replace(hour=0, minute=0, second=0, microsecond=0)
    edt = max(xx.DateTime_UTC).replace(hour=0, minute=0, second=0,
        microsecond=0) + timedelta(days=1)

    ddt = edt - sdt
    lat = sxx.latitude[0]
    lng = sxx.longitude[0]
    rss = []
    for i in range(ddt.days + 1):
        rise, sets = list(suns(sdt + timedelta(days=int(i) - 1), latitude=lat,
            longitude=lng).calculate())
        if rise > sets:
            sets = sets + timedelta(days=1) # account for UTC
        rss.append([rise, sets])

    rss = pd.DataFrame(rss, columns=("rise", "set"))
    rss.set = rss.set.shift(1)
    sunriseset = rss.loc[1:].to_json(orient='records', date_format='iso')

    # Get 2 week plot intervals
    def daterange(start, end):
        r = (end + timedelta(days=1) - start).days
        if r % 14 >= 0:
            r = r + 14
        return [(end - timedelta(days=i)).strftime('%Y-%m-%d') for i in range(0, r, 14)]

    drr = daterange(sdt, edt)

    return jsonify(variables=variables, dat=xx.to_json(orient='records', date_format='iso'),
        sunriseset=sunriseset, flagdat=flagdat, plotdates=drr)#, flagtypes=flagtypes)

@app.route('/_getqaqc_grab', methods=["POST"])
def getqaqc_grab():

    region, site = request.json['site'].split(",")[0].split("_")
    vars = request.json['vars']
    year = request.json['year']

    sqlq = "select grabdata.region, grabdata.site, grabdata.DateTime_UTC, " +\
        "grabdata.variable, grabdata.value, grabdata.flag as flagid, grabflag.flag, " +\
        "grabflag.comment from grabdata left join grabflag on grabdata.flag=grabflag.id where " +\
        "grabdata.region='" + region + "' and grabdata.site='" + site +\
        "' and grabdata.variable in ('" + "','".join(vars) + "') and " +\
        "year(DateTime_UTC) = " + year + ";"
    xx = pd.read_sql(sqlq, db.engine) #this is what makes it take so long. read in 4w chunks
    xx.loc[xx.flag == 0, "value"] = None # set NaNs
    flagdat = xx[['DateTime_UTC', 'variable', 'flagid', 'flag',
        'comment']].dropna().drop(['flagid'],
        axis=1).to_json(orient='records', date_format='iso') # flag data

    variables = xx.loc[:,'variable'].unique().tolist()

    xx = xx.drop(['flag', 'comment'], axis=1).drop_duplicates()\
        .set_index(["DateTime_UTC", "variable"])\
        .drop(['region', 'site', 'flagid'], axis=1)
    xx = xx[~xx.index.duplicated(keep='last')].unstack('variable') # get rid of duplicated date/variable combos
    xx.columns = xx.columns.droplevel()
    xx = xx.reset_index()

    # Get sunrise sunset data
    sxx = pd.read_sql("select latitude, longitude from site where region='" +\
        region + "' and site='" + site + "'", db.engine)
    # sxx = pd.read_sql("select id, region, site, name, latitude, " +\
    #     "longitude, usgs, addDate, embargo, site.by, contact, contactEmail " +\
    #     "from site where region='" + region +\
    #     "' and site='" + site + "'", db.engine)
    sdt = min(xx.DateTime_UTC).replace(hour=0, minute=0, second=0, microsecond=0)
    edt = max(xx.DateTime_UTC).replace(hour=0, minute=0, second=0,
        microsecond=0) + timedelta(days=1)

    ddt = edt - sdt
    lat = sxx.latitude[0]
    lng = sxx.longitude[0]
    rss = []
    for i in range(ddt.days + 1):
        rise, sets = list(suns(sdt + timedelta(days=int(i) - 1), latitude=lat,
            longitude=lng).calculate())
        if rise > sets:
            sets = sets + timedelta(days=1) # account for UTC
        rss.append([rise, sets])

    rss = pd.DataFrame(rss, columns=("rise", "set"))
    rss.set = rss.set.shift(1)
    sunriseset = rss.loc[1:].to_json(orient='records', date_format='iso')

    # Get 2 week plot intervals
    def daterange(start, end):
        r = (end + timedelta(days=1) - start).days
        if r % 140 > 0:
            r = r + 140
        return [(end - timedelta(days=i)).strftime('%Y-%m-%d') for i in range(0, r, 140)]

    drr = daterange(sdt, edt)

    return jsonify(variables=variables, dat=xx.to_json(orient='records', date_format='iso'),
        sunriseset=sunriseset, flagdat=flagdat, plotdates=drr)#, flagtypes=flagtypes)

@app.route('/_getqaqcyears', methods=["POST"])
def getqaqcyears():
    region, site = request.json['site'].split('_')
    yrs = pd.read_sql("select distinct mid(DateTime_UTC, 1, 4) as d from " +\
        "data where region='" + region + "' and site='" + site + "';",
        db.engine).d.tolist()

    return jsonify(years=yrs)

@app.route('/_getqaqcyears_grab', methods=["POST"])
def getqaqcyears_grab():
    region, site = request.json['site'].split('_')
    yrs = pd.read_sql("select distinct mid(DateTime_UTC, 1, 4) as d from " +\
        "grabdata where region='" + region + "' and site='" + site + "';",
        db.engine).d.tolist()

    return jsonify(years=yrs)

@app.route('/qaqc_help')
def qaqc_help_page():
    return render_template('qaqc_help.html')

@app.route('/_outlierdetect', methods=["POST"])
def outlier_detect():

    # start_time = timeit.default_timer()

    dat_chunk = pd.DataFrame(request.json)
    # dat_chunk.to_csv('~/Dropbox/streampulse/data/test_outl2.csv', index=False)

    outl_ind_r = find_outliers(dat_chunk) #call R code for outlier detect

    outl_ind = {}
    for j in range(1, len(outl_ind_r) + 1): #loop through R-ified list

        if outl_ind_r.rx2(j)[0] == 'NONE':
            outl_ind[outl_ind_r.names[j-1]] = None
            continue

        tmp_lst = []
        for i in outl_ind_r.rx2(j):
            tmp_lst.append(int(i))
        outl_ind[outl_ind_r.names[j-1]] = tmp_lst

    # elapsed = timeit.default_timer() - start_time
    # print elapsed

    return jsonify(outliers=outl_ind)

@app.route('/_addflag', methods=["POST"])
def addflag():
    rgn, ste = request.json['site'].split("_")
    # sdt = dtparse.parse(request.json['startDate'])
    # edt = dtparse.parse(request.json['endDate'])
    sdt = datetime.strptime(request.json['startDate'],"%Y-%m-%dT%H:%M:%S.%fZ")
    edt = datetime.strptime(request.json['endDate'],"%Y-%m-%dT%H:%M:%S.%fZ")
    var = request.json['var']
    flg = request.json['flagid']
    cmt = request.json['comment']

    for vv in var:
        fff = Flag(rgn, ste, sdt, edt, vv, flg, cmt, int(current_user.get_id()))
        db.session.add(fff)
        # db.session.commit()
        flgdat = Data.query.filter(Data.region==rgn, Data.site==ste, Data.DateTime_UTC>=sdt, Data.DateTime_UTC<=edt, Data.variable==vv).all()
        for f in flgdat:
            f.flag = fff.id
        db.session.commit()
    return jsonify(result="success")

@app.route('/_addflag_grab', methods=["POST"])
def addflag_grab():

    rgn, ste = request.json['site'].split("_")
    sdt = datetime.strptime(request.json['startDate'], "%Y-%m-%dT%H:%M:%S.%fZ")
    edt = datetime.strptime(request.json['endDate'], "%Y-%m-%dT%H:%M:%S.%fZ")
    var = request.json['var']
    flg = request.json['flagid']
    cmt = request.json['comment']

    for vv in var:
        fff = Grabflag(rgn, ste, sdt, edt, vv, flg, cmt, int(current_user.get_id()))
        db.session.add(fff)
        flgdat = Grabdata.query.filter(Grabdata.region==rgn, Grabdata.site==ste,
            Grabdata.DateTime_UTC>=sdt, Grabdata.DateTime_UTC<=edt,
            Grabdata.variable==vv).all()
        for f in flgdat:
            f.flag = fff.id
        db.session.commit()
    return jsonify(result="success")

@app.route('/_rmflag', methods=["POST"])
def rmflag():

    rgn, ste = request.json['site'].split("_")
    sdt = datetime.strptime(request.json['startDate'],"%Y-%m-%dT%H:%M:%S.%fZ")
    edt = datetime.strptime(request.json['endDate'],"%Y-%m-%dT%H:%M:%S.%fZ")
    var = request.json['var']

    for vv in var:

        # flagq = Flag.query.filter(Flag.region==rgn, Flag.site==ste,
        #     Flag.startDate>=sdt, Flag.endDate<=edt,
        #     Flag.variable==vv).all()
        # for f in flagq:
        #     db.session.delete(f)

        datq = Data.query.filter(Data.region == rgn, Data.site == ste,
            Data.DateTime_UTC >= sdt, Data.DateTime_UTC <= edt,
            Data.variable == vv).all()
        for d in datq:
            d.flag = None

        db.session.commit()

    return jsonify(result="success")

@app.route('/_rmflag_grab', methods=["POST"])
def rmflag_grab():

    rgn, ste = request.json['site'].split("_")
    sdt = datetime.strptime(request.json['startDate'],"%Y-%m-%dT%H:%M:%S.%fZ")
    edt = datetime.strptime(request.json['endDate'],"%Y-%m-%dT%H:%M:%S.%fZ")
    var = request.json['var']

    for vv in var:

        datq = Grabdata.query.filter(Grabdata.region == rgn, Grabdata.site == ste,
            Grabdata.DateTime_UTC >= sdt, Grabdata.DateTime_UTC <= edt,
            Grabdata.variable == vv).all()
        for d in datq:
            d.flag = None

        db.session.commit()

    return jsonify(result="success")

@app.route('/api')
def api():

    #this function used to handle mutiple sites in a list,
    #but now that behavior is a relic

    # sites=['WI_BEC'];startDate='2016-01-01';endDate='2016-12-31';variables='DO_mgL,DOsat_pct,satDO_mgL,WaterPres_kPa,Depth_m,WaterTemp_C,Light_PAR,AirPres_kPa,Discharge_m3s,Level_m'

    #pull in requests
    startDate = request.args.get('startdate')
    endDate = request.args.get('enddate')
    variables = request.args.get('variables')
    sites = request.args['sitecode'].split(',')

    #test for site existence
    reg, sit = sites[0].split('_')
    q1 = "select id, region, site, name, latitude, " +\
        "longitude, usgs, addDate, embargo, site.by, contact, contactEmail " +\
        "from site where region='" + reg + "' and site='" + sit + "';"
    resp = pd.read_sql(q1, db.engine)
    if resp.shape[0] == 0:
        return jsonify(error='Unknown site requested.')

    #user auth
    if request.headers.get('Token') is not None:
        sites = authenticate_sites(sites, token=request.headers['Token'])
    elif current_user.is_authenticated:
        sites = authenticate_sites(sites, user=current_user.get_id())
    else:
        sites = authenticate_sites(sites)

    if not sites:
        return jsonify(error='This site is private and requires a valid user token.')

    #assemble sql queries for data and metadata
    is_powell_site = re.match('nwis-[0-9]+', sit)
    src = 'powell' if is_powell_site else 'data'

    ss = []; ss2 = []
    for site in sites:
        r,s = site.split("_")
        ss.append("(region='" + r + "' and site='" + s + "') ")
        ss2.append("(" + src + ".region='" + r + "' and " + src + ".site='" + s + "') ")

    qs = "or ".join(ss)
    qs2 = "or ".join(ss2)
    # r='AQ';s='OUTL12'

    meta = pd.read_sql("select region, site, name, latitude as lat, " +\
        "longitude as lon, datum, usgs as usgsid from site where " + qs, db.engine)

    sqlq = "select " + src + ".region, " + src + ".site, " + src + ".DateTime_UTC, " +\
        src + ".variable, " + src + ".value, flag.flag as flagtype, flag.comment as " +\
        "flagcomment from " + src + " left join flag on " + src + ".flag = flag.id where " +\
        qs2

    if startDate is not None:
        sqlq = sqlq + "and " + src + ".DateTime_UTC > '" + startDate + "' "
    if endDate is not None:
        sqlq = sqlq + "and " + src + ".DateTime_UTC < '" + endDate + "' "
    if variables is not None:
        vvv = variables.split(",")
        sqlq = sqlq + "and " + src + ".variable in ('" + "', '".join(vvv) + "')"

    #read in data as df; format it
    xx = pd.read_sql(sqlq, db.engine)
    vv = xx.variable.unique().tolist()
    # xx.loc[xx.flag==0,"value"] = None # set NA values (deprecated)
    xx.dropna(subset=['value'], inplace=True) # remove rows with NA value

    #get USGS data if depth requested but not available
    xu = []
    if variables is not None:
        if "Discharge_m3s" in variables and "Discharge_m3s" not in vv:
            xu = get_usgs(sites, min(xx.DateTime_UTC).strftime("%Y-%m-%d"),
                max(xx.DateTime_UTC).strftime("%Y-%m-%d"), ['00060'])
            if len(xu) == 1 and xu[0][0:10] == 'USGS_error':
                return jsonify(data=xu[0])
        if "Depth_m" in variables and "Depth_m" not in vv and len(xu) is 0:
            xu = get_usgs(sites, min(xx.DateTime_UTC).strftime("%Y-%m-%d"),
                max(xx.DateTime_UTC).strftime("%Y-%m-%d"), ['00065'])
            if len(xu) == 1 and xu[0][0:10] == 'USGS_error':
                return jsonify(data=xu[0])

    if len(xu) is not 0:
        # subset usgs data based on each site's dates
        xx = pd.concat([xx,xu], sort=True)

    #rearrange columns
    # flagcols = ['flagtype','flagcomment']
    # reordered = [i for i in xx.columns.tolist() if i not in flagcols] + flagcols
    # xx = xx[reordered]

    # check for doubles with same datetime, region, site, variable...
    xx = xx.set_index(["DateTime_UTC","region","site","variable"])
    xx = xx[~xx.index.duplicated(keep='last')].sort_index().reset_index()
    xx['DateTime_UTC'] = xx['DateTime_UTC'].apply(lambda x: \
        x.strftime('%Y-%m-%d %H:%M:%S'))

    #get flag data (already done above, so this may be obsolete)
    if request.args.get('flags') == 'true':
        fsql = "select * from flag where " + qs
        if startDate is not None:
            fsql = fsql + "and startDate > '" + startDate + "' "
        if endDate is not None:
            fsql = fsql + "and endDate < '" + endDate + "' "
        if variables is not None:
            vvv = variables.split(",")
            fsql = fsql + "and variable in ('" + "', '".join(vvv) + "')"
        flags = pd.read_sql(fsql, db.engine)
        flags.drop(['by'], axis=1, inplace=True)
        # xx.drop(['id'], axis=1, inplace=True)
        xx[['flagtype','flagcomment']] = \
            xx[['flagtype','flagcomment']].fillna('') #repace NaNs in flag cols

        #assemble response
        resp = jsonify(data=xx.to_dict(orient='records'),
            sites=meta.to_dict(orient='records'),
            flags=flags.to_dict(orient='records'))
    else:
        xx.drop(['flagtype','flagcomment'], axis=1, inplace=True)
        # xx.drop(['id','flag'], axis=1, inplace=True)

        #assemble response
        resp = jsonify(data=xx.to_dict(orient='records'),
            sites=meta.to_dict(orient='records'))

    return resp

def clean_query_response(r):

    #replace NaT with None
    r.firstRecord = r.firstRecord.astype(object)
    r.loc[r.firstRecord.isnull(),'firstRecord'] = None
    r.lastRecord = r.lastRecord.astype(object)
    r.loc[r.lastRecord.isnull(),'lastRecord'] = None
    # r.lastRecord.loc[r.lastRecord.isnull()] = None

    #replace NaN with None
    r.latitude = r.latitude.where((pd.notnull(r.latitude)), None)
    r.longitude = r.longitude.where((pd.notnull(r.longitude)), None)

    #convert embargo years and addDate to days of embargo remaining
    emb = []
    for i in range(len(r.embargoDaysLeft)):
        timediff = (r.addDate[i] + pd.Timedelta(days=365 * r.embargoDaysLeft[i])) -\
            datetime.today()
        emb.append(timediff.days)
    r.loc[:,'embargoDaysLeft'] = [x if x > 0 else 0 for x in emb]

    return r

@app.route('/query_available_data')
def query_available_data():

    #pull in requests
    startDate = request.args.get('startdate')
    endDate = request.args.get('enddate')
    variable = request.args.get('variable')
    region = request.args.get('region')
    site = request.args.get('site')
    # powell = request.args.get('powell')
    # powell = True if powell == 'TRUE' else False

    #error checks (more in R code)
    if variable not in variables and variable is not None and variable != 'all':
        return jsonify(error='Unknown variable requested. Available ' +\
            'variables are: ' + ', '.join(variables))

    regsites = pd.read_sql("select distinct region, site from site;",
        db.engine)
    regions = list(set(regsites.region))
    regions.append(u'all')
    if region is not None and region not in regions:
        return jsonify(error='Unknown region requested.')
    if site is not None:
        sites_at_region = regsites[regsites.region == region].site.tolist()
        if site not in sites_at_region:
            return jsonify(error='No site "' + site + '" found for region "' +\
                region + '".')

    #only region supplied = requesting sites
    if region is not None and region != 'all' and site is None:
        r = pd.read_sql("select distinct region, site, name, latitude, " +\
            "longitude, datum, usgs as usgsGage, addDate, firstRecord, lastRecord, contact, contactEmail, " +\
            "embargo as embargoDaysLeft from site where region='" + region + "';",
            db.engine)
        if list(r.region):
            r = clean_query_response(r)
            return jsonify(sites=r.to_dict(orient='records'))
        else:
            r = 'No data available for requested region.'
            return jsonify(error=r)

    #only region supplied and region is 'all' = requesting sites
    if region is not None and region == 'all':
        r = pd.read_sql("select distinct region, site, name, latitude, " +\
            "longitude, datum, usgs as usgsGage, addDate, firstRecord, lastRecord, contact, contactEmail, " +\
            "embargo as embargoDaysLeft from site;", db.engine)
        r = clean_query_response(r)
        return jsonify(sites=r.to_dict(orient='records'))

    #only variable supplied and variable is 'all' = requesting variables
    if variable is not None and variable == 'all':
        return jsonify(variables=','.join(variables))

    #only variable supplied = requesting sites
    if variable is not None and startDate is None and region is None:
        r = pd.read_sql("select distinct region, site, name, latitude, " +\
            "longitude, datum, usgs as usgsGage, addDate, firstRecord, lastRecord, contact, contactEmail, " +\
            "embargo as embargoDaysLeft from site where " +\
            "variableList like '%%" + variable + "%%';", db.engine)
        if list(r.region):
            r = clean_query_response(r)
            return jsonify(sites=r.to_dict(orient='records'))
        else:
            r = 'No data available for requested variable.'
            return jsonify(error=r)

    #only site code supplied = requesting variables and date bounds
    if region is not None and startDate is None and variable is None:
        r = pd.read_sql("select variableList from site where " +\
            "region='" + region + "' and site='" + site + "';",
            db.engine).variableList.tolist()
        r2 = pd.read_sql("select firstRecord, lastRecord from site where " +\
            "region='" + region + "' and site='" + site + "';",
            db.engine)
        if r and list(r2.firstRecord):
            return jsonify(variables=r, datebounds=r2.to_json(orient='values',
                date_format='iso'))
        else:
            if not r:
                r = 'No variables available for requested site.'
                return jsonify(error=r)
            if not list(r2.firstRecord):
                r2 = 'No data available for requested site.'
                return jsonify(error=r2)

    #only dates supplied = requesting sites
    if startDate is not None and region is None and variable is None:
        r = pd.read_sql("select distinct region, site, name, latitude, " +\
            "longitude, datum, usgs as usgsGage, addDate, firstRecord, lastRecord, contact, contactEmail, " +\
            "embargo as embargoDaysLeft from site where " +\
            "firstRecord <='" + startDate + "' and lastRecord >='" +\
            endDate + "';", db.engine)
        if list(r.region):
            r = clean_query_response(r)
            return jsonify(sites=r.to_dict(orient='records'))
        else:
            r = 'No data available for entire requested timespan.'
            return jsonify(error=r)

    #site code and dates supplied = requesting variables
    if startDate is not None and region is not None and variable is None:
        r = pd.read_sql("select variableList from site where " +\
            "region='" + region + "' and site='" + site +\
            "' and firstRecord <='" + startDate + "' and lastRecord >='" +\
             endDate + "';", db.engine).variableList.tolist()
        if r:
            return jsonify(variables=r)
        else:
            r = 'No data available for entire requested timespan and site.'
            return jsonify(error=r)

    #site code and variable supplied = requesting date range for that variable
    if startDate is None and region is not None and variable is not None:

        is_powell_site = re.match('nwis-[0-9]+', site)
        src = 'powell' if is_powell_site else 'data'

        r = pd.read_sql("select min(DateTime_UTC) as firstRecord, " +\
            "max(DateTime_UTC) as lastRecord from " + src + " where " +\
            "region='" + region + "' and site='" + site +\
            "' and variable='" + variable + "';", db.engine)
        if list(r.firstRecord):
            return jsonify(datebounds=r.to_json(orient='values',
                date_format='iso'))
        else:
            r = 'No data available for requested site and variable.'
            return jsonify(error=r)

    #variable and dates supplied = requesting sites
    if startDate is not None and region is None and variable is not None:

        # src = 'powell' if powell else 'data'

        r = pd.read_sql("select distinct site.region, site.site, site.latitude, " +\
            "site.longitude, site.usgs as usgsGage, site.addDate, site.firstRecord, " +\
            "site.lastRecord, site.contact, site.contactEmail, " +\
            "site.embargo as embargoDaysLeft from data left join site on (" +\
            "data.region=site.region and " +\
            "data.site=site.site) where " +\
            "data.DateTime_UTC >='" + startDate + "' and data.DateTime_UTC >='" +\
             endDate + "' and data.variable='" + variable + "';", db.engine)
        if list(r.region):
            r = clean_query_response(r)
            return jsonify(sites=r.to_dict(orient='records'))
        else:
            r = 'No data available for variable during requested timespan.'
            return jsonify(error=r)

@app.route('/query_available_results')
def query_available_results():

    #pull in requests and list of model name components
    region = request.args.get('region')
    site = request.args.get('site')
    year = request.args.get('year')

    #extract region, site, year components of each model object (sp and powell)
    resdir = app.config['RESULTS_FOLDER']
    d = os.listdir(resdir)
    d = [x for x in d if x[0:6] == 'modOut']
    regsiteyr = [re.match('\w+_(.+?)_(.+?)_([0-9]{4}).rds', x).groups() for x in d]

    resdir_powell = resdir[0: len(resdir) - 4] + 'powell_data/shiny_lists'
    dP = os.listdir(resdir_powell)
    regsiteyrP = []
    # x = dP[0]
    for x in dP:
        rx = re.match('(\w+)_(\w+)_([0-9]+).rds', x)
        regsiteyrP.append((rx.group(1), 'nwis-' + rx.group(2), rx.group(3)))
    regsiteyr.extend(regsiteyrP)
    # regsiteyrP = [re.match('(\w+)_(\w+)_([0-9]+).rds', x).groups() for x in dP]

    #error checks (more in R code)
    regsites = pd.read_sql("select distinct region, site from site;",
        db.engine)
    regions = list(set(regsites.region))
    regions.append(u'all')
    if region is not None and region not in regions:
        return jsonify(error='Unknown region requested.')
    if site is not None:
        sites_at_region = regsites[regsites.region == region].site.tolist()
        if site not in sites_at_region:
            return jsonify(error='No site "' + site + '" found for region "' +\
                region + '".')

    #only region supplied
    if region is not None and region != 'all' and site is None and year is None:
        rsy = [x for x in regsiteyr if x[0] == region]
        if rsy:
            return jsonify(available_model_results=rsy)
        else:
            r = 'No data available for requested region.'
            return jsonify(error=r)

    #only region supplied and region is 'all'
    if region is not None and region == 'all':
        return jsonify(available_model_results=regsiteyr)

    #only year supplied
    if region is None and year is not None:
        rsy = [x for x in regsiteyr if x[2] == year]
        if rsy:
            return jsonify(available_model_results=rsy)
        else:
            r = 'No data available for requested year.'
            return jsonify(error=r)

    #region and year supplied
    if region is not None and site is None and year is not None:
        rsy = [x for x in regsiteyr if x[2] == year and x[0] == region]
        if rsy:
            return jsonify(available_model_results=rsy)
        else:
            r = 'No data available for requested region and year.'
            return jsonify(error=r)

    #region and site supplied
    if region is not None and site is not None and year is None:
        rsy = [x for x in regsiteyr if x[1] == site and x[0] == region]
        if rsy:
            return jsonify(available_model_results=rsy)
        else:
            r = 'No data available for requested region and site.'
            return jsonify(error=r)

@app.route('/request_results')
def request_results():

    #pull in requests
    # regionsite=['NC_Eno']; year='2017'
    # regionsite = ['NE_nwis-06461500']; year='2014'
    regionsite = [request.args.get('sitecode')]
    year = request.args.get('year')

    #select appropriate model result folder, depending on powell/sp
    rx = re.match('([a-zA-z]{2})_nwis-([0-9]+)', regionsite[0])
    resdir = app.config['RESULTS_FOLDER']
    if rx:
        resdir = resdir[0: len(resdir) - 4] + 'powell_data/shiny_lists'
        region = rx.group(1)
        site = rx.group(2)
        requested_model = region + '_' + site + '_' + year + '.rds'
        site_prefix = 'nwis-'
    else:
        requested_model = 'modOut_' + regionsite[0] + '_' + year + '.rds'
        region, site = regionsite[0].split('_')
        site_prefix = ''

    #user auth
    if request.headers.get('Token') is not None:
        regionsite = authenticate_sites(regionsite, token=request.headers['Token'])
    else:
        regionsite = authenticate_sites(regionsite)

    if not regionsite:
        return jsonify(error='This site is private and requires a valid user token.')

    #split region and site; pull in list of model result filenames
    mods_avail = os.listdir(resdir)

    #error checks (more in R code)
    regsites = pd.read_sql("select distinct region, site from site;",
        db.engine)
    regions = list(set(regsites.region))
    regions.append(u'all')
    if region is not None and region not in regions:
        return jsonify(error='Unknown region requested.')
    if site is not None:
        sites_at_region = regsites[regsites.region == region].site.tolist()
        site = site_prefix + site
        if site not in sites_at_region:
            return jsonify(error='No site "' + site + '" found for region "' +\
                region + '".')

    #region and site supplied
    if requested_model in mods_avail:
        return send_from_directory(resdir, requested_model, as_attachment=True)
    else:
        r = 'No model results available for requested region, site, year.'
        return jsonify(error=r)

@app.route('/_grdo_metatemplate_download', methods=['POST'])
def grdo_metatemplate_download():

    return send_from_directory('static/grdo', 'GRDO_MetaData_Template.xlsx',
        as_attachment=True)

@app.route('/_grdo_datatemplate_download', methods=['POST'])
def grdo_datatemplate_download():

    return send_from_directory('static/grdo', 'GRDO_TimeseriesData_Template.xlsx',
        as_attachment=True)

@app.route('/_reach_characterization_templates_download', methods=['POST'])
def reach_characterization_templates_download():

    return send_from_directory('static', 'streampulse_reach_characterization_templates.zip',
        as_attachment=True)

@app.route('/_reachchar_exfiles_download', methods=['POST'])
def reachchar_exfiles_download():

    region = request.form['selregion']
    sdf = app.config['REACH_CHAR_FOLDER']

    #find files from the requested region
    rc_files = os.listdir(sdf)
    rc_bool = [True if re.match(region + '_.*', x) else False for x in rc_files]
    req_files = [rc_files[i] for i in range(len(rc_bool)) if rc_bool[i]]

    #add files to temp directory and zip, with readme
    tmp = tempfile.mkdtemp()

    for f in req_files:
        shutil.copy2(sdf + '/' + f, tmp)

    shutil.copy2('static/streampulse_reach_characterization_templates/README.txt',
        tmp)
    # with open(tmp + '/README.txt', 'w') as r:
    #     r.write('Please pay close attention to units!\n')
    #     r.close()

    # writefiles = os.listdir(tmp)
    zipname = region + '_reach_characterization_files.zip'
    with zipfile.ZipFile(tmp + '/' + zipname, 'w') as zf:
        [zf.write(tmp + '/' + f, f) for f in req_files]

    return send_from_directory(tmp, zipname, as_attachment=True)

@app.route('/_allsp_download', methods=['POST'])
def allsp_download():

    return send_from_directory('../bulk_download_files', 'all_sp_data.zip',
        as_attachment=True)

@app.route('/_allneon_download', methods=['POST'])
def allneon_download():

    return send_from_directory('../bulk_download_files', 'all_neon_data.zip',
        as_attachment=True)

@app.route('/_allpowell_download', methods=['POST'])
def allpowell_download():

    return send_from_directory('../bulk_download_files', 'all_powell_data.zip',
        as_attachment=True)

@app.route('/_allgrab_download', methods=['POST'])
def allgrab_download():

    return send_from_directory('../bulk_download_files', 'all_grab_data.csv.zip',
        as_attachment=True)

@app.route('/_allbasicsite_download', methods=['POST'])
def allbasicsite_download():

    return send_from_directory('../bulk_download_files',
        'all_basic_site_data.csv.zip', as_attachment=True)

@app.route('/_allsuppmeta_download', methods=['POST'])
def allsuppmeta_download():

    return send_from_directory('../bulk_download_files',
        'all_supplementary_site_metadata.zip', as_attachment=True)

@app.route('/_allreachchar_download', methods=['POST'])
def allreachchar_download():

    return send_from_directory('../bulk_download_files',
        'all_reach_characterization_datasets.zip', as_attachment=True)

@app.route('/_allmodelsumm_download', methods=['POST'])
def allmodelsumm_download():

    return send_from_directory('../bulk_download_files',
        'all_model_summary_data.csv.zip', as_attachment=True)

@app.route('/_alldailyres_download', methods=['POST'])
def alldailyres_download():

    return send_from_directory('../bulk_download_files',
        'all_daily_model_results.csv.zip', as_attachment=True)

@app.route('/_allspmodelobj_download', methods=['POST'])
def allspmodelobj_download():

    return send_from_directory('../bulk_download_files',
        'all_sp_model_objects.zip', as_attachment=True)

# @app.route('/_sp_logo_download', methods=['POST'])
# def sp_logo_download():
#
#     return send_from_directory('static/img', 'sp_logo.eps',
#         as_attachment=True)

@app.route('/request_predictions')
def request_predictions():

    #pull in requests
    regionsite = [request.args.get('sitecode')]
    year = request.args.get('year')

    #select appropriate model result folder, depending on powell/sp
    rx = re.match('([a-zA-z]{2})_nwis-([0-9]+)', regionsite[0])
    resdir = app.config['RESULTS_FOLDER']
    if rx:
        resdir = resdir[0: len(resdir) - 4] + 'powell_data/shiny_lists'
        region = rx.group(1)
        site = rx.group(2)
        requested_model = region + '_' + site + '_' + year + '.rds'
        site_prefix = 'nwis-'
    else:
        requested_model = 'predictions_' + regionsite[0] + '_' + year + '.rds'
        region, site = regionsite[0].split('_')
        site_prefix = ''
    # requested_model = 'predictions_' + regionsite[0] + '_' + year + '.rds'

    #user auth
    if request.headers.get('Token') is not None:
        regionsite = authenticate_sites(regionsite, token=request.headers['Token'])
    else:
        regionsite = authenticate_sites(regionsite)

    if not regionsite:
        return jsonify(error='This site is private and requires a valid user token.')

    #split region and site; pull in list of model result filenames
    mods_avail = os.listdir(resdir)

    #error checks (more in R code)
    regsites = pd.read_sql("select distinct region, site from site;",
        db.engine)
    regions = list(set(regsites.region))
    regions.append(u'all')
    if region is not None and region not in regions:
        return jsonify(error='Unknown region requested.')
    if site is not None:
        sites_at_region = regsites[regsites.region == region].site.tolist()
        site = site_prefix + site
        if site not in sites_at_region:
            return jsonify(error='No site "' + site + '" found for region "' +\
                region + '".')

    #region and site supplied
    if requested_model in mods_avail:
        return send_from_directory(resdir, requested_model, as_attachment=True)
    else:
        r = 'No model predictions available for requested region, site, year.'
        return jsonify(error=r)

@app.route('/api/model_details_download')
def model_details_download():

    #pull in requests
    region = request.args.get('region')
    site = request.args.get('site')
    year = request.args.get('year')
    regsite = [region + '_' + site]

    #test
    q1 = "select id, region, site, name, latitude, " +\
        "longitude, usgs, addDate, embargo, site.by, contact, contactEmail " +\
        "from site where region='" + region +\
        "' and site='" + site + "';"
    resp = pd.read_sql(q1, db.engine)
    if resp.shape[0] == 0:
        return jsonify(error='Unknown site requested.')

    #user auth
    if request.headers.get('Token') is not None:
        regsite = authenticate_sites(regsite, token=request.headers['Token'])
    elif current_user.is_authenticated:
        regsite = authenticate_sites(regsite, user=current_user.get_id())
    else:
        regsite = authenticate_sites(regsite)

    if not regsite:
        return jsonify(error='This site is private and requires a valid user token.')

    #get specs for best model run so far
    q2 = "select * from model where region='" + region +\
        "' and site='" + site + "' and year='" + str(year) +\
        "' and current_best=1;"
    best_mod = pd.read_sql(q2, db.engine)

    return jsonify(specs=best_mod.to_dict(orient='records'))

@app.route('/api/model_details_upload', methods=['POST'])
def model_details_upload():

    #pull in data, format for database entry
    deets = dict(request.form) #not readable by bulk_insert_mappings
    deets = pd.DataFrame.from_dict(deets, orient='index')
    deets = deets.transpose()
    deets = deets.to_dict('records')[0] #readable by bulk_insert_mappings

    #convert R string booleans to 0 and 1
    for k in deets:
        if deets[k] == 'FALSE':
            deets[k] = 0
        if deets[k] == 'TRUE':
            deets[k] = 1

    # #user auth (not needed; user will never run unauthorized model in first place)
    # regsite = deets['region'] + '_' + deets['site']
    #
    # if request.headers.get('Token') is not None:
    #     regsite = authenticate_sites(regsite, token=request.headers['Token'])
    # elif current_user.is_authenticated: #will this ever be possible?
    #     regsite = authenticate_sites(regsite, user=current_user.get_id())
    # else:
    #     regsite = authenticate_sites(regsite)
    #
    # if not regsite:
    #     return jsonify(error='This site is private and requires a valid user token.')

    #demote previous best model if it exists
    d = Model.query.filter(Model.region == deets['region'],
        Model.site == deets['site'], Model.year == deets['year'],
        Model.current_best == 1).all()

    if d:
        for rec in d:
            rec.current_best = False

    #add new record to model database
    db.session.bulk_insert_mappings(Model, [deets])
    db.session.commit()

    return jsonify(callback='success')

@app.route('/api/model_upload', methods=['POST'])
def model_upload():

    #pull in serialized R data (RDS files) and variable filename component
    modOut = request.files['modOut']
    predictions = request.files['predictions']
    file_id = request.headers.get('fileid')

    #if already a model for this region-site-time: move, touch, rename
    fnames = os.listdir('shiny/model_viz/data')
    cur_time = time.mktime(datetime.now().timetuple())
    cur_time = str(cur_time)[0:-2]
    if 'modOut_' + file_id + '.rds' in fnames:
        new_suffix = file_id + cur_time + '.rds'
        os.rename('shiny/model_viz/data/modOut_' + file_id + '.rds',
            'shiny/model_viz/former_best_models/modOut_' + new_suffix)
        with open('shiny/model_viz/former_best_models/modOut_' + new_suffix, 'a'):
            os.utime('shiny/model_viz/former_best_models/modOut_' + new_suffix, None)
        os.rename('shiny/model_viz/data/predictions_' + file_id + '.rds',
            'shiny/model_viz/former_best_models/predictions_' + new_suffix)
        with open('shiny/model_viz/former_best_models/predictions_' + new_suffix, 'a'):
            os.utime('shiny/model_viz/former_best_models/predictions_' + new_suffix, None)

    #save new RDS files to shiny data folder
    modOut.save('shiny/model_viz/data/modOut_' + file_id + '.rds')
    predictions.save('shiny/model_viz/data/predictions_' + file_id + '.rds')

    return jsonify(callback='success')

@app.route('/model')
def modelgen():
    xx = pd.read_sql("select distinct region, site from data", db.engine)
    sites = [x[0] + "_" + x[1] for x in zip(xx.region,xx.site)]
    if current_user.is_authenticated:
        sites = authenticate_sites(sites, user=current_user.get_id())
    else:
        sites = authenticate_sites(sites)
    ss = []
    for site in sites:
        r, s = site.split("_")
        ss.append("(region='" + r + "' and site='" + s + "') ")
    qs = "or ".join(ss)
    nn = pd.read_sql("select region, site, name from site", db.engine)
    dd = pd.read_sql("select region, site, min(DateTime_UTC) as startdate, " +\
        "max(DateTime_UTC) as enddate from data where " + qs + "group by " +\
        "region, site", db.engine)
    # dd = pd.read_sql_table('data',db.engine)[['region','site','DateTime_UTC']]
    # dd = pd.concat([dd.groupby(['region','site']).DateTime_UTC.min(),dd.groupby(['region','site']).DateTime_UTC.max()], axis=1)
    # dd.columns = ['startdate','enddate']
    # dd = dd.reset_index()
    dx = nn.merge(dd, on=['region','site'], how='right')
    dx['regionsite'] = [x[0] + "_" + x[1] for x in zip(dx.region, dx.site)]
    dx.startdate = dx.startdate.apply(lambda x: x.strftime('%Y-%m-%d'))
    dx.enddate = dx.enddate.apply(lambda x: x.strftime('%Y-%m-%d'))
    dx.name = dx.region + " - " + dx.name
    sitedict = sorted([tuple(x) for x in dx[['regionsite','name','startdate',
        'enddate']].values], key=lambda tup: tup[1])

    return render_template('model.html', sites=sitedict)

@app.route('/map')
def site_map():

    core_sites = pd.read_csv('static/sitelist.csv')
    core_sites = list(core_sites['REGIONID'] + '_' + core_sites['SITEID'])

    site_data = pd.read_sql('select id, region, site, name, latitude, ' +\
        'longitude, datum, usgs, addDate, embargo, site.by, contact, contactEmail ' +\
        'from site where `by` != -902;', db.engine)
    site_data.addDate = site_data.addDate.astype('str')
    site_dict = site_data.to_dict('records')

    powell_data = pd.read_sql('select id, region, site, name, latitude, ' +\
        'longitude, datum, usgs, addDate, embargo, site.by, contact, contactEmail ' +\
        'from site where `by` = -902;', db.engine)
    powell_data.addDate = powell_data.addDate.astype('str')
    powell_dict = powell_data.to_dict('records')
    #powell_sites = pd.read_csv('static/map/powell_sites.csv')
    #powell_dict = powell_sites.to_dict('records')

    return render_template('map.html', site_data=site_dict,
        core_sites=core_sites, powell_sites=powell_dict)

if __name__=='__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
