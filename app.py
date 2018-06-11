# -*- coding: utf-8 -*-
from flask import Flask, Markup, session, flash, render_template, request, jsonify, url_for, make_response, send_file, redirect, g
from flask_login import LoginManager, login_user, logout_user, current_user, login_required
from werkzeug.security import generate_password_hash, check_password_hash
from sunrise_sunset import SunriseSunset as suns
from werkzeug.utils import secure_filename
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import func
# from sqlalchemy.ext import serializer
from itsdangerous import URLSafeTimedSerializer
from datetime import datetime, timedelta
from dateutil import parser as dtparse
from math import log, sqrt, floor
import simplejson as json
from sklearn import svm
from operator import itemgetter
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
import config as cfg
import logging
import readline #needed for rpy2 import in conda env
os.environ['R_HOME'] = '/usr/lib/R' #needed for rpy2 to find R. has to be a better way
import rpy2.robjects as robjects
from rpy2.robjects import pandas2ri
import markdown

#another attempt at serverside sessions
# import pickle
# from uuid import uuid4
# from redis import Redis
# from werkzeug.datastructures import CallbackDict
# from flask.sessions import SessionInterface, SessionMixin
#
# class RedisSession(CallbackDict, SessionMixin):
#
#     def __init__(self, initial=None, sid=None, new=False):
#         def on_update(self):
#             self.modified = True
#         CallbackDict.__init__(self, initial, on_update)
#         self.sid = sid
#         self.new = new
#         self.modified = False
#
#
# class RedisSessionInterface(SessionInterface):
#     serializer = pickle
#     session_class = RedisSession
#
#     def __init__(self, redis=None, prefix='session:'):
#         if redis is None:
#             redis = Redis()
#         self.redis = redis
#         self.prefix = prefix
#
#     def generate_sid(self):
#         return str(uuid4())
#
#     def get_redis_expiration_time(self, app, session):
#         if session.permanent:
#             return app.permanent_session_lifetime
#         return timedelta(days=1)
#
#     def open_session(self, app, request):
#         sid = request.cookies.get(app.session_cookie_name)
#         if not sid:
#             sid = self.generate_sid()
#             return self.session_class(sid=sid, new=True)
#         val = self.redis.get(self.prefix + sid)
#         if val is not None:
#             data = self.serializer.loads(val)
#             return self.session_class(data, sid=sid)
#         return self.session_class(sid=sid, new=True)
#
#     def save_session(self, app, session, response):
#         domain = self.get_cookie_domain(app)
#         if not session:
#             self.redis.delete(self.prefix + session.sid)
#             if session.modified:
#                 response.delete_cookie(app.session_cookie_name,
#                                        domain=domain)
#             return
#         redis_exp = self.get_redis_expiration_time(app, session)
#         cookie_exp = self.get_expiration_time(app, session)
#         val = self.serializer.dumps(dict(session))
#         self.redis.setex(self.prefix + session.sid, val,
#                          int(redis_exp.total_seconds()))
#         response.set_cookie(app.session_cookie_name, session.sid,
#                             expires=cookie_exp, httponly=True,
#                             domain=domain)


# from rpy2.robjects.packages import importr

pandas2ri.activate() #for converting pandas df to R df

app = Flask(__name__)

# app.session_interface = RedisSessionInterface()

app.config['SECRET_KEY'] = cfg.SECRET_KEY
app.config['SQLALCHEMY_DATABASE_URI'] = cfg.SQLALCHEMY_DATABASE_URI
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = cfg.SQLALCHEMY_TRACK_MODIFICATIONS
app.config['UPLOAD_FOLDER'] = cfg.UPLOAD_FOLDER
app.config['META_FOLDER'] = cfg.META_FOLDER
app.config['GRAB_FOLDER'] = cfg.GRAB_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024 # 16 MB
app.config['SECURITY_PASSWORD_SALT'] = cfg.SECURITY_PASSWORD_SALT
#app.config['PROPAGATE_EXCEPTIONS'] = True

#error logging
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

# class Manual(db.Model):
#     id = db.Column(db.Integer, primary_key=True)
#     region = db.Column(db.String(10))
#     site = db.Column(db.String(50))
#     DateTime_UTC = db.Column(db.DateTime)
#     variable = db.Column(db.String(50))
#     value = db.Column(db.Float)
#     def __init__(self, region, site, DateTime_UTC, variable, value):
#         self.region = region
#         self.site = site
#         self.DateTime_UTC = DateTime_UTC
#         self.variable = variable
#         self.value = value
#     def __repr__(self):
#         return '<Manual %r, %r, %r, %r>' % (self.region, self.site, self.DateTime_UTC, self.variable)

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

# class Tag(db.Model):
#     id = db.Column(db.Integer, primary_key=True)
#     region = db.Column(db.String(10))
#     site = db.Column(db.String(50))
#     startDate = db.Column(db.DateTime)
#     endDate = db.Column(db.DateTime)
#     variable = db.Column(db.String(50))
#     tag = db.Column(db.String(50))
#     comment = db.Column(db.String(255))
#     by = db.Column(db.Integer) # user ID
#     def __init__(self, region, site, startDate, endDate, variable, tag, comment, by):
#         self.region = region
#         self.site = site
#         self.startDate = startDate
#         self.endDate = endDate
#         self.variable = variable
#         self.tag = tag
#         self.comment = comment
#         self.by = by
#     def __repr__(self):
#         return '<Tag %r, %r>' % (self.tag, self.comment)

class Site(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    region = db.Column(db.String(10))
    site = db.Column(db.String(50))
    name = db.Column(db.String(50))
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)
    usgs = db.Column(db.String(20))
    addDate = db.Column(db.DateTime)
    embargo = db.Column(db.Integer)
    by = db.Column(db.Integer)
    contact = db.Column(db.String(50))
    contactEmail = db.Column(db.String(255))
    def __init__(self, region, site, name, latitude, longitude, usgs, addDate, embargo, by, contact, contactEmail):
        self.region = region
        self.site = site
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
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
    def __init__(self, region, site, rawcol, dbcol):
        self.region = region
        self.site = site
        self.rawcol = rawcol
        self.dbcol = dbcol
    def __repr__(self):
        return '<Cols %r, %r, %r>' % (self.region, self.site, self.dbcol)

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
        self.token = binascii.hexlify(os.urandom(10))
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
        return unicode(self.id)
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
    # version = db.Column(db.Integer)

    def __init__(self, filename):
        self.filename = filename

    def __repr__(self):
        return '<Upload %r>' % (self.filename)

class Grabupload(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(100))
    # version = db.Column(db.Integer)

    def __init__(self, filename):
        self.filename = filename

    def __repr__(self):
        return '<Grabupload %r>' % (self.filename)


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
core['SITECD'] = list(core["REGIONID"].map(str) +"_"+ core["SITEID"])
core = core.set_index('SITECD')

variables = ['DateTime_UTC', 'DO_mgL', 'satDO_mgL', 'DOsat_pct', 'WaterTemp_C',
'WaterPres_kPa', 'AirTemp_C', 'AirPres_kPa', 'Level_m', 'Depth_m',
'Discharge_m3s', 'Velocity_ms', 'pH', 'pH_mV', 'CDOM_ppb', 'CDOM_mV',
'Turbidity_NTU', 'Turbidity_mV', 'Nitrate_mgL', 'SpecCond_mScm',
'SpecCond_uScm', 'CO2_ppm', 'Light_lux', 'Light_PAR', 'underwater_PAR', 'Light2_lux',
'Light2_PAR', 'Light3_lux', 'Light3_PAR', 'Light4_lux', 'Light4_PAR',
'Light5_lux', 'Light5_PAR', 'Battery_V']


o = 'other'
# fltr_methods = ['IC', 'FIA', 'TOC-TN', 'spectrophotometer']
# fltr_opts = ['filtered-45mm', 'filtered-other', 'unfiltered']
grab_variables = [
{'var': 'Br', 'unit': 'Bromide (molar)', 'method': ['IC',o]},
{'var': 'Ca', 'unit': 'Calcium (molar)', 'method': ['IC',o]},
{'var': 'Cl', 'unit': 'Chloride (molar)', 'method': ['IC',o]},
{'var': 'K', 'unit': 'Potassium (molar)', 'method': ['IC',o]},
{'var': 'Mg', 'unit': 'Magnesium (molar)', 'method': ['IC',o]},
{'var': 'Na', 'unit': 'Sodium (molar)', 'method': ['IC',o]},
{'var': 'NH4', 'unit': 'Ammonium (molar)', 'method': ['FIA',o]},
{'var': 'NO3', 'unit': 'Nitrate (molar)', 'method': ['IC','FIA',o]},
{'var': 'PO4', 'unit': 'Phosphate (molar)', 'method': ['IC','FIA',o]},
{'var': 'SiO2', 'unit': 'Silica (molar)', 'method': ['FIA','spectrophotometer',o]},
{'var': 'SO4', 'unit': 'Sulfate (molar)', 'method': ['IC',o]},
{'var': 'Total_Fe', 'unit': 'Total Fe (molar)', 'method': ['spectroscopy','FIA',o]},
{'var': 'Total_Mn', 'unit': 'Total Mn (molar)', 'method': ['spectroscopy','FIA',o]},
{'var': 'TOC', 'unit': 'TOC (ppm)', 'method': ['TOC-TN',o]},
{'var': 'TN', 'unit': 'TN (ppm)', 'method': ['TOC-TN',o]},
{'var': 'TDP', 'unit': 'TDP (mg/L)', 'method': ['Ascorbic Acid Method',o]},
{'var': 'DOC', 'unit': 'DOC (ppm)', 'method': ['combustion','oxidation',o]},
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
{'var': 'Light_Atten', 'unit': 'Light Atten. (m^-1)', 'method': ['pyranometer',o]},
{'var': 'Illuminance', 'unit': 'Illuminance (lux)', 'method': ['lux meter',o]},
{'var': 'PAR', 'unit': 'PAR (W/m^2)', 'method': ['pyranometer',o]},
{'var': 'UV_Absorbance', 'unit': 'UV Absorbance (cm^-1)', 'method': ['spectrophotometer',o]},
{'var': 'Canopy_Cover', 'unit': 'Canopy Cover (LAI)', 'method': ['field measurement','remote sensing','model',o]},
{'var': 'Width', 'unit': 'Width (m)', 'method': ['field measurement',o]},
{'var': 'Depth', 'unit': 'Depth (m)', 'method': ['field measurement',o]},
{'var': 'Distance', 'unit': 'Distance (m)', 'method': ['field measurement',o]},
{'var': 'Discharge', 'unit': 'Discharge (m^3/s)', 'method': ['flow meter','salt slug',o]},
{'var': 'k', 'unit': 'k (min^-1)', 'method': ['argon','propane','SF6','radon','floating chamber',o]},
{'var': 'Water_Temp', 'unit': 'Water Temp (C)', 'method': ['sonde',o]},
{'var': 'Air_Temp', 'unit': 'Air Temp (C)', 'method': ['sonde',o]},
{'var': 'Water_Pres', 'unit': 'Water Pres (kPa)', 'method': ['sonde',o]},
{'var': 'Air_Pres', 'unit': 'Air Pres (kPa)', 'method': ['sonde',o]}
]
# #'Substrate',  Bed_Cover?, Flow,

# o = u'other'
# grab_variables = {
# 'Br': ('Br (molar)', ['IC',o]),
# 'Ca': ('Ca (molar)', ['IC',o]),
# 'Cl': ('Cl (molar)', ['IC',o]),
# 'K': ('K (molar)', ['IC',o]),
# 'Mg': ('Mg (molar)', ['IC',o]),
# 'Na': ('Na (molar)', ['IC',o]),
# 'NH4': ('NH4 (molar)', ['FIA',o]),
# 'NO3': ('NO3 (molar)', ['IC','FIA',o]),
# 'PO4': ('PO4 (molar)', ['IC','FIA',o]),
# 'SiO2': ('SiO2 (molar)', ['FIA','spectrophotometer',o]),
# 'SO4': ('SO4 (molar)', ['IC',o]),
# 'Total_Fe': ('Total_Fe (molar)', ['spectroscopy','FIA',o]),
# 'Total_Mn': ('Total_Mn (molar)', ['spectroscopy','FIA',o]),
# 'TOC': ('TOC (ppm)', ['TOC-TN',o]),
# 'TN': ('TN (ppm)', ['TOC-TN',o]),
# 'TDP': ('TDP (mg/L)', ['Ascorbic Acid Method',o]),
# 'DOC': ('DOC (ppm)', ['combustion','oxidation',o]),
# 'TSS': ('TSS (ppm)', ['dry mass','backscatter',o]),
# 'fDOM': ('fDOM (ppb)', ['sonde',o]),
# 'CO2': ('CO2 (ppm)', ['sonde','GC',o]),
# 'CH4': ('CH4 (ug/L)', ['GC',o]),
# 'N2O': ('N2O (ug/L)', ['GC',o]),
# 'DO': ('DO (mg/L)', ['sensor',o]),
# 'DO_Sat': ('DO_Sat (%)', ['sensor',o]),
# 'Chlorophyll-a': ('Chlorophyll-a (mg/L)', ['spectrophotometer',o]),
# 'Alkalinity': ('Alkalinity (meq/L)', ['FIA','titration',o]),
# 'pH': ('pH', ['ISFET',o]),
# 'Spec_Cond': ('Spec_Cond (mS/cm)', ['sonde',o]),
# 'Turbidity': ('Turbidity (NTU)', ['turbidimeter',o]),
# 'Light_Atten': ('Light_Atten (m^-1)', ['pyranometer',o]),
# 'Illuminance': ('Illuminance (lux)', ['lux meter',o]),
# 'PAR': ('PAR (W/m^2)', ['pyranometer',o]),
# 'UV_Absorbance': ('UV_Absorbance (cm^-1)', ['spectrophotometer',o]),
# 'Canopy_Cover': ('Canopy_Cover (LAI)', ['field measurement','remote sensing','model',o]),
# 'Width': ('Width (m)', ['field measurement',o]),
# 'Depth': ('Depth (m)', ['field measurement',o]),
# 'Distance': ('Distance (m)', ['field measurement',o]),
# 'Discharge': ('Discharge (m^3/s)', ['flow meter','salt slug',o]),
# 'k': ('k (min^-1)', ['argon','propane','SF6','radon','floating chamber',o]),
# 'Water_Temp': ('Water_Temp (C)', ['sonde',o]),
# 'Air_Temp': ('Air_Temp (C)', ['sonde',o]),
# 'Water_Pres': ('Water_Pres (kPa)', ['sonde',o]),
# 'Air_Pres': ('Air_Pres (kPa)', ['sonde',o])
# }
#'Substrate',  Bed_Cover?, Flow,


# #corresponding elements of grab_variables, grab_vars_with_units, grab_methods,
# #and grab_filters must remain aligned. If you add a new variable, update all
# #four lists with a new element and put it at the same index for each.
# grab_variables = ['Br', 'Ca', 'Cl', 'K',
# 'Mg', 'Na', 'NH4', 'NO3', 'PO4',
# 'SiO2', 'SO4', 'Total_Fe',
# 'Total_Mn', 'TOC', 'TN', 'TDP', 'DOC',
# 'TSS', 'fDOM', 'CO2', 'CH4', 'N2O',
# 'DO', 'DO_Sat', 'Chlorophyll-a', 'Alkalinity', 'pH',
# 'Spec_Cond', 'Turbidity', 'Light_Atten',
# 'Illuminance', 'PAR', 'UV_Absorbance',
# 'Canopy_Cover', 'Width', 'Depth', 'Distance',
# 'Discharge', 'k', 'Water_Temp',
# 'Air_Temp', 'Water_Pres', 'Air_Pres']
# #'Substrate',  Bed_Cover?, Flow,
#
# grab_vars_with_units = ['Br (molar)', 'Ca (molar)', 'Cl (molar)', 'K (molar)',
# 'Mg (molar)', 'Na (molar)', 'NH4 (molar)', 'NO3 (molar)', 'PO4 (molar)',
# 'SiO2 (molar)', 'SO4 (molar)', 'Total_Fe (molar)',
# 'Total_Mn (molar)', 'TOC (ppm)', 'TN (ppm)', 'TDP (mg/L)', 'DOC (ppm)',
# 'TSS (ppm)', 'fDOM (ppb)', 'CO2 (ppm)', 'CH4 (ug/L)', 'N2O (ug/L)',
# 'DO (mg/L)', 'DO_Sat (%)', 'Chlorophyll-a (mg/L)', 'Alkalinity (meq/L)', 'pH',
# 'Spec_Cond (mS/cm)', 'Turbidity (NTU)', 'Light_Atten (m^-1)',
# 'Illuminance (lux)', 'PAR (W/m^2)', 'UV_Absorbance (cm^-1)',
# 'Canopy_Cover (LAI)', 'Width (m)', 'Depth (m)', 'Distance (m)',
# 'Discharge (m^3/s)', 'k (min^-1)', 'Water_Temp (C)',
# 'Air_Temp (C)', 'Water_Pres (kPa)', 'Air_Pres (kPa)']
# #'Substrate ()',  Bed_Cover? (), Flow (Laminar, etc.),
#
# o = 'other'
# grab_methods = [['IC',o], ['IC',o], ['IC',o], ['IC',o],
# ['IC',o], ['IC',o], ['FIA',o], ['IC','FIA',o], ['IC','FIA',o],
# ['FIA','spectrophotometer',o], ['IC',o], ['spectroscopy','FIA',o],
# ['spectroscopy','FIA',o], ['TOC-TN',o], ['TOC-TN',o], ['Ascorbic Acid Method',o], ['combustion','oxidation',o],
# ['dry mass','backscatter',o], ['sonde',o], ['sonde','GC',o], ['GC',o], ['GC',o],
# ['sensor',o], ['sensor',o], ['spectrophotometer',o], ['FIA','titration',o], ['ISFET',o],
# ['sonde',o], ['turbidimeter',o], ['pyranometer',o],
# ['lux meter',o], ['pyranometer',o], ['spectrophotometer',o],
# ['field measurement','remote sensing','model',o], ['field measurement',o], ['field measurement',o], ['field measurement',o],
# ['flow meter','salt slug',o], ['argon','propane','SF6','radon','floating chamber',o], ['sonde',o],
# ['sonde',o], ['sonde',o], ['sonde',o]]
# #'Substrate',  Bed_Cover?, Flow,

#R code for outlier detection
with open('find_outliers.R', 'r') as f:
    find_outliers_string = f.read()
find_outliers = robjects.r(find_outliers_string)

# File uploading function
ALLOWED_EXTENSIONS = set(['txt', 'dat', 'csv'])
def allowed_file(filename):
    return '.' in filename and \
           filename.rsplit('.', 1)[1] in ALLOWED_EXTENSIONS

def read_hobo(f):
    xt = pd.read_csv(f, skiprows=[0])
    cols = [x for x in xt.columns.tolist() if re.match("^#$|Coupler|File|" +\
        "Host|Connected|Attached|Stopped|End|Unnamed|Good|Bad",x) is None]
    xt = xt[cols]
    m = [re.sub(" ","",x.split(",")[0]) for x in xt.columns.tolist()]
    u = [x.split(",")[1].split(" ")[1] for x in xt.columns.tolist()]
    tzoff = re.sub("GMT(.[0-9]{2}):([0-9]{2})","\\1",u[0])
    logger_regex = ".*/\\w+_\\w+_[0-9]{4}-[0-9]{2}-[0-9]{2}_([A-Z]{2}" +\
        "(?:[0-9]+)?)(?:v[0-9]+)?\\.\\w{3}"
    ll = re.sub(logger_regex, "\\1", f)
    # ll = f.split("_")[3].split(".")[0].split("v")[0]
    inum = re.sub("[A-Z]{2}","",ll)
    uu = [re.sub("\\ |\\/|°","",x) for x in u[1:]]
    uu = [re.sub(r'[^\x00-\x7f]',r'', x) for x in uu] # get rid of unicode
    newcols = ['DateTime']+[nme+unit for unit,nme in zip(uu,m[1:])]
    xt = xt.rename(columns=dict(zip(xt.columns.tolist(),newcols)))
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
    xt.columns = [cc+inum for cc in xt.columns]
    cols = xt.columns.tolist()
    xx = xt[cols[-1:]+cols[1:-1]]
    return xx

def read_csci(f, gmtoff):
    xt = pd.read_csv(f, header=0, skiprows=[0,2,3])
    xt['DateTimeUTC'] = [dtparse.parse(x)-timedelta(hours=gmtoff) for x in xt.TIMESTAMP]
    cols = xt.columns.tolist()
    return xt[cols[-1:]+cols[1:-1]]

def read_manta(f, gmtoff):

    #manta has a weird custom of repeating two header rows every time the power
    #cycles. these additional headers get removed below.

    xt = pd.read_csv(f, skiprows=[0]) #skip the first row that just has site name
    if 'Eureka' in xt.columns[0]:#if the wrong header row is first, replace it
        xt.columns = xt.loc[0].tolist()
    xt = xt[xt.DATE.str.contains('[0-9]+/[0-9]+/[0-9]{4}')] #drop excess header/blank rows
    xt['DateTime'] = xt['DATE'] + " " + xt['TIME']
    xt['DateTimeUTC'] = [dtparse.parse(x) - timedelta(hours=gmtoff) for x in xt.DateTime]
    xt.drop(["DATE","TIME","DateTime"], axis=1, inplace=True)
    xt = xt[[x for x in xt.columns.tolist() if " ." not in x and x!=" "]]
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
        upID = max(last_upID[0], max(pending_upIDs)) + 1
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
        xx = map(lambda x: load_file(x, gmtoff, logger), f)
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
            xx = map(lambda x: load_multi_file(ff, gmtoff, x), logger)
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

def get_usgs(regionsite, startDate, endDate, vvv=['00060','00065']):
    # regionsite is a list
    # vvv is a list of variable codes
    #00060 is cfs, discharge; 00065 is feet, height
    xs = pd.read_sql("select * from site",db.engine)
    xs['regionsite'] = xs["region"].map(str)+"_"+xs["site"]
    # for each region site...
    sitex = xs.loc[xs.regionsite.isin(regionsite)].usgs.tolist()
    sitedict = dict(zip(sitex,regionsite))
    sitex = [x for x in sitex if x is not None]
    usgs = ",".join(sitex)
    #lat,lng = sitex.loc[:,['latitude','longitude']].values.tolist()[0]
    if(len(sitex) == 0 or usgs is None):
        return []
    vcds = '00060,00065'#",".join(vvv)
    #request usgs water service data in universal time (T01:15 makes it line up with our datasets)
    url = "https://nwis.waterservices.usgs.gov/nwis/iv/?format=json&sites=" + \
        usgs + "&startDT=" + startDate + "T01:15Z&endDT=" + endDate + \
        "T23:59Z&parameterCd=" + vcds + "&siteStatus=all"
    r = requests.get(url)
    print r.status_code
    if r.status_code != 200:
        return 'USGS_error'
    xf = r.json()
    xx = map(lambda x: panda_usgs(x, xf), range(len(xf['value']['timeSeries'])))
    xoo = []
    for s in sitex:
        x2 = [k.values()[0] for k in xx if k.keys()[0]==s]
        x2 = reduce(lambda x,y: x.merge(y,how='outer',left_index=True,right_index=True), x2)
        x2 = x2.sort_index().apply(lambda x: pd.to_numeric(x, errors='coerce')).resample('15Min').mean()
        x2['site']=sitedict[s]
        xoo.append(x2.reset_index())
    #
    xx = pd.concat(xoo)
    xx = xx.set_index(['DateTime_UTC','site'])
    xx.columns.name='variable'
    xx = xx.stack()
    xx.name="value"
    xx = xx.reset_index()
    xx[['region','site']] = xx['site'].str.split("_",expand=True)
    # xx.head()

    return xx[['DateTime_UTC','region','site','variable','value']]

    # else:
        # xx = pd.DataFrame({'DateTime_UTC':[], 'region':[], 'site':[],
        #     'variable':[], 'value':[]})
        # return xx

def authenticate_sites(sites,user=None,token=None):
    ss = []
    for site in sites:
        r,s = site.split("_")
        ss.append("(region='"+r+"' and site='"+s+"') ")
    qs = "or ".join(ss)
    xx = pd.read_sql("select region, site, embargo, addDate, site.by from site where "+qs, db.engine)
    if token is not None:
        tt = pd.read_sql("select * from user where token='"+token+"'", db.engine)
        if(len(tt)==1):
            user = str(tt.id[0])
    embargoed = [(datetime.utcnow()-x).days+1 for x in xx['addDate']] > xx['embargo']*365
    if user is not None: # return public sites and authenticated sites
        xx = xx[(embargoed)|(xx['by']==int(user))]
    else: # return only public sites
        xx = xx[(embargoed)] # return
    return [x[0]+"_"+x[1] for x in zip(xx.region,xx.site)]

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

# def send_email(to, subject, template):
#     mail.send_message(subject, recipients=[to], html=template)

########## PAGES
@app.route('/register' , methods=['GET','POST'])
def register():
    if request.method == 'GET':
        return render_template('register.html')
    user = User(request.form['username'], request.form['password'], request.form['email'])
    db.session.add(user)
    db.session.commit()
    flash('User successfully registered', 'alert-success')
    return redirect(url_for('login'))

@app.route('/_reset_sp_pass', methods=['GET','POST'])
@login_required
def resetpass():
    if request.method == 'GET':
        return render_template('reset.html')
    email = request.form['email']
    try:
        user = User.query.filter(User.email==email).first_or_404()
    except: # email is not confirmed
        flash("We couldn't find an account with that email.", 'alert-danger')
        return redirect(url_for('resetpass'))
    token = generate_confirmation_token(email)
    register_url = url_for('resetpass_confirm', token=token, _external=True)
    return jsonify(account=email, reset_url=register_url, note="This link is valid for 24 hours.")

@app.route('/resetpass/<token>' , methods=['GET','POST'])
def resetpass_confirm(token):
    if request.method == 'GET':
        try:
            email = confirm_token(token)
            user = User.query.filter(User.email==email).first_or_404()
        except: # email is not confirmed
            flash('The confirmation link is invalid or has expired.', 'alert-danger')
            return redirect(url_for('index'))
        return render_template('resetpass.html', email=email) # email is good.
    # posting new password
    user = User.query.filter(User.email==request.form['email']).first_or_404()
    user.password = generate_password_hash(request.form['password'])
    db.session.add(user)
    db.session.commit()
    flash('Successfully reset, please login.', 'alert-success')
    return redirect(url_for('login'))

@app.route('/login',methods=['GET','POST'])
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

@app.route('/')
@app.route('/index')
def index():
    nuse = pd.read_sql("select count(id) as n from user", db.engine)
    nobs = pd.read_sql("select count(id) as n from data", db.engine)
    nsit = pd.read_sql("select count(id) as n from site", db.engine)
    return render_template('index.html',nobs="{:,}".format(nobs.n.sum()), nuse=nuse.n[0], nsit=nsit.n[0])

@app.route('/sitelist')
def sitelist():
    ss = pd.read_sql_table('site',db.engine).set_index(['site','region'])
    sqlq = 'select region, site, count(region) as value from data group by region, site'
    xx = pd.read_sql(sqlq, db.engine).set_index(['site','region'])
    res = xx.merge(ss,"left",left_index=True,right_index=True)
    res = res.reset_index()
    res = res[['region','site','name','latitude','longitude','value']]
    res = res.rename(columns={'region':'Region','site':'Site','name':'Name','latitude':'Latitude','longitude':'Longitude','value':'Observations'}).fillna(0).sort_values(['Region','Site'],ascending=True)
    res.Observations = res.Observations.astype(int)
    return render_template('sitelist.html', dats=Markup(res.to_html(index=False, classes=['table','table-condensed'])))

@app.route('/upload_choice')
def upload_choice():
    return render_template('upload_choice.html')

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

        replace = False if request.form.get('replace') is None else True

        #checks
        if 'file' not in request.files:
            flash('No file part','alert-danger')
            return redirect(request.url)
        ufiles = request.files.getlist("file")
        ufnms = [x.filename for x in ufiles]
        if len(ufnms[0]) == 0:
            flash('No files selected.','alert-danger')
            return redirect(request.url)

        #get list of all files in spupload directory
        upfold = app.config['UPLOAD_FOLDER']
        ld = os.listdir(upfold)

        #check names of uploaded files
        ffregex = "^[A-Z]{2}_.*_[0-9]{4}-[0-9]{2}-[0-9]{2}_[A-Z]{2}" +\
            "(?:[0-9]+)?.[a-zA-Z]{3}$" # core sites
        ffregex2 = "^[A-Z]{2}_.*_[0-9]{4}-[0-9]{2}-[0-9]{2}.csv$" #leveraged sites
        pattern = re.compile(ffregex+"|"+ffregex2)
        if not all([pattern.match(f) is not None for f in ufnms]):
            flash('Please name your files in the specified format.',
                'alert-danger')
            return redirect(request.url)

        if not replace: #if user has not checked replace box

            #get lists of new and existing files, filter uploaded files by new
            new = [fn not in ld for fn in ufnms]
            existing = [ufnms[f] for f in xrange(len(ufnms)) if not new[f]]
            ufiles = [ufiles[f] for f in xrange(len(ufiles)) if new[f]]
            ufnms = [ufnms[f] for f in xrange(len(ufnms)) if new[f]]

            if not ufnms: #if no files left in list
                if len(existing) == 1:
                    msgc = ['This file has', 'its']
                else:
                    msgc = ['These files have', 'their']

                flash(msgc[0] + ' already been ' +\
                    'uploaded. Check the box if you want to replace ' +\
                    msgc[1] + ' contents in the database.', 'alert-danger')
                return redirect(request.url)

            if existing: #if some uploaded files aready exist

                if len(existing) > 1:
                    insrt1 = ('These files', 'exist'); insrt2 = 'them'
                if len(existing) == 1:
                    insrt1 = ('This file', 'exists'); insrt2 = 'it'

                flash('%s already %s: ' % insrt1 + ', '.join(existing) +\
                    '. You may continue, or click "Cancel" at the bottom of ' +\
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
                # sb.upload_file_to_item(sbupf, fup) #broken (need to get credentials)

                filenames.append(filename) #fname list passed on for display
                fnlong.append(fup) #list of files that get processed
            else: #name may be messed up or something else could have gone wrong
                msg = Markup('Error 002. Please <a href="mailto:vlahm13@gmail.com" class="alert-link">email Mike Vlah</a> with the error number and a copy of the file you tried to upload.')
                flash(msg,'alert-danger')
                return redirect(request.url)

        #persist filenames across requests
        session['filenamesNoV'] = filenamesNoV
        session['fnlong'] = fnlong

        #make sure LOGGERID formats are valid
        for i in xrange(len(filenamesNoV)):
            logger = re.search(".*\\d{4}-\\d{2}-\\d{2}(_[A-Z]{2})?" +\
                "(?:[0-9]+)?\\.\\w{3}", filenamesNoV[i][0]).group(1)

            if logger: #if there is a LOGGERID format
                logger = logger[1:len(logger)] #remove underscore

                if logger not in ['CS','HD','HW','HA','HP','EM','XX']:
                    flash('"' + str(logger) + '" is an invalid LOGGERID. ' +\
                        'See formatting instructions.', 'alert-danger')
                    [os.remove(f) for f in fnlong]
                    return redirect(request.url)

        # PROCESS the data and save as tmp file
        try:
            if site[0] in core.index.tolist():
                gmtoff = core.loc[site].GMTOFF[0]
                x = sp_in(fnlong, gmtoff)
            else:
                if len(fnlong) > 1:
                    flash('For non-core sites, please merge files prior ' +\
                        'to upload.', 'alert-danger')
                    [os.remove(f) for f in fnlong]
                    return redirect(request.url)
                x = sp_in_lev(fnlong[0])

            #save combined input files to a temporary csv
            tmp_file = site[0].encode('ascii') + "_" +\
                binascii.hexlify(os.urandom(6))
            out_file = os.path.join(upfold, tmp_file + ".csv")
            x.to_csv(out_file, index=False)

            #get data to pass on to confirm columns screen
            columns = x.columns.tolist() #col names
            columns.remove('upload_id')
            rr, ss = site[0].split("_") #region and site
            cdict = pd.read_sql("select * from cols where region='" + rr +\
                "' and site='" + ss + "'", db.engine)
            cdict = dict(zip(cdict['rawcol'],cdict['dbcol'])) #varname mappings
            flash("Please double check your variable name matching.",
                'alert-warning')

        except:
            msg = Markup('Error 001. Please <a href="mailto:vlahm13@gmail.com" class="alert-link">email Mike Vlah</a> with the error number and a copy of the file you tried to upload.')
            flash(msg,'alert-danger')
            [os.remove(f) for f in fnlong]
            return redirect(request.url)

        # check if existing site
        try:
            allsites = pd.read_sql("select concat(region, '_', site) as" +\
                " sitenm from site",db.engine).sitenm.tolist()
            existing = True if site[0] in allsites else False

            #go to next webpage
            return render_template('upload_columns.html', filenames=filenames,
                columns=columns, tmpfile=tmp_file, variables=variables, cdict=cdict,
                existing=existing, sitenm=site[0], replacing=replace)

        except: #thrown when there are unreadable symbols (like deg) in the csv
            msg = Markup('Error 004. Check for unusual characters in your column names (degree symbol, etc.). If problem persists, <a href="mailto:vlahm13@gmail.com" class="alert-link">Email Mike Vlah</a> with the error number and a copy of the file you tried to upload.')
            flash(msg, 'alert-danger')
            [os.remove(f) for f in fnlong]
            return redirect(request.url)

    if request.method == 'GET': #?
        xx = pd.read_sql("select distinct region, site from data", db.engine)
        vv = pd.read_sql("select distinct variable from data",
            db.engine)['variable'].tolist()
        sites = [x[0]+"_"+x[1] for x in zip(xx.region,xx.site)]
        sitedict = sorted([getsitenames(x) for x in sites],
            key=lambda tup: tup[1])
        return render_template('series_upload.html', sites=sitedict,
            variables=map(str,vv))

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

            #list format no longer useful; extract items
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

        except:
            msg = Markup('Error 001. Please <a href=' +\
                '"mailto:vlahm13@gmail.com" class="alert-link">' +\
                'email Mike Vlah</a> with the error number and a copy of ' +\
                'the file you tried to upload.')
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
            urs = [ureg + '_' + s for s in usites]
            coldict = pd.read_sql("select * from grabcols where site in ('" +\
                "', '".join(usites) + "') and region='" + ureg + "';",
                db.engine)
            cdict = dict(zip(coldict['rawcol'], coldict['dbcol'])) #varname mappings
            mdict = dict(zip(coldict['rawcol'], coldict['method'])) #method mappings
            wdict = dict(zip(coldict['rawcol'], coldict['write_in'])) #more method mappings
            adict = dict(zip(coldict['rawcol'], coldict['addtl'])) #additional mappings

        except:
            msg = Markup('Error 002. Please <a href=' +\
                '"mailto:vlahm13@gmail.com" class="alert-link">' +\
                'email Mike Vlah</a> with the error number and a copy of ' +\
                'the file you tried to upload.')
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

        except:
            msg = Markup('Error 003. Please <a href=' +\
                '"mailto:vlahm13@gmail.com" class="alert-link">' +\
                'email Mike Vlah</a> with the error number and a copy of ' +\
                'the file you tried to upload.')
            flash(msg, 'alert-danger')
            try:
                os.remove(fnlong)
            except:
                pass
            finally:
                return redirect(request.url)

@app.route("/upload_cancel",methods=["POST"])
def cancelcolumns(): #only used when cancelling series_upload
    ofiles = request.form['ofiles'].split(",")
    tmpfile = request.form['tmpfile']+".csv"
    ofiles.append(tmpfile)
    [os.remove(os.path.join(app.config['UPLOAD_FOLDER'],x)) for x in ofiles] # remove tmp files
    flash('Upload cancelled.','alert-primary')
    return redirect(url_for('series_upload'))

# @app.route("/_addmanualdata",methods=["POST"])
# def manual_upload():
#     rgn, ste = request.json['site'].split("_")
#     data = [d for d in request.json['data'] if None not in d] # get all complete rows
#     dd = pd.DataFrame(data,columns=["DateTime_UTC","variable","value"])
#     dd['DateTime_UTC'] = pd.to_datetime(dd['DateTime_UTC'],format='%Y-%m-%d %H:%M')
#     dd['DateTime_UTC'] = pd.DatetimeIndex(dd['DateTime_UTC']).round("15Min")
#     dd['region'] = rgn
#     dd['site'] = ste
#     dd['value'] = pd.to_numeric(dd['value'], errors='coerce')
#     # region site datetime variable value
#     dd = dd[['region','site','DateTime_UTC','variable','value']]
#     dd.to_sql("manual", db.engine, if_exists='append', index=False, chunksize=1000)
#     return jsonify(result="success")

@app.route("/policy")
def datapolicy():
    return render_template("datapolicy.html")

def updatecdict(region, site, cdict):
    rawcols = pd.read_sql("select * from cols where region='"+region+"' and site ='"+site+"'", db.engine)
    rawcols = rawcols['rawcol'].tolist()
    for c in cdict.keys():
        if c in rawcols: # update
            cx = Cols.query.filter_by(rawcol=c).first()
            cx.dbcol = cdict[c] # assign column to value
            # db.session.commit()
        else: # add
            cx = Cols(region, site, c, cdict[c])
            db.session.add(cx)
            # db.session.commit()

def chunker_ingester(df, chunksize=100000):

    #determine chunks based on number of records (chunksize)
    n_full_chunks = df.shape[0] / chunksize
    partial_chunk_len = df.shape[0] % chunksize

    #convert directly to dict if small enough, otherwise do it chunkwise
    if n_full_chunks == 0:
        xdict = df.to_dict('records')
        db.session.bulk_insert_mappings(Data, xdict) #ingest all records
    else:
        for i in xrange(n_full_chunks):
            chunk = df.head(chunksize)
            df = df.drop(df.head(chunksize).index)
            chunk = chunk.to_dict('records')
            db.session.bulk_insert_mappings(Data, chunk)

        if partial_chunk_len:
            lastchunk = df.to_dict('records')
            db.session.bulk_insert_mappings(Data, lastchunk)

def updatedb(xx, fnamelist, replace=False):

    if replace:

        #get list of existing upload ids and table of flagged obs to be replaced
        upIDs = pd.read_sql("select id from upload where filename in ('" +\
            "', '".join(fnamelist) + "')", db.engine)
        upIDs = [str(i) for i in upIDs.id]
        flagged_obs = pd.read_sql("select * from data where upload_id in ('" +\
            "', '".join(upIDs) + "') and flag is not null", db.engine)

        #delete records that are being replaced (this could be sped up)
        if list(upIDs):
            d = Data.query.filter(Data.upload_id.in_(list(upIDs))).all()
            for rec in d:
                db.session.delete(rec)

        #insert new (replacement) data (chunk it if > 100k records)
        chunker_ingester(xx)

        #reconstitute flags
        for ind, r in flagged_obs.iterrows():
            try:
                d = Data.query.filter(Data.region==r['region'], Data.site==r['site'],
                    Data.upload_id==r['upload_id'], Data.variable==r['variable'],
                    Data.DateTime_UTC==r['DateTime_UTC']).first()
                d.flag = r['flag']
                db.session.add(d)
            except:
                continue

    else: #if not replacing, just insert new data
        chunker_ingester(xx)

def grab_updatecdict(region, sitelist, cdict, mdict, wdict, adict):

    #get input variable name list
    rawcols = pd.read_sql("select * from grabcols where region='" + region +\
        "' and site in ('" + "', '".join(sitelist) + "')", db.engine)
    rawcols = set(rawcols['rawcol'].tolist())

    #update or establish varname, method, addtl mappings
    for c in cdict.keys():
        for s in sitelist:
            if c in rawcols: # update
                cx = Grabcols.query.filter_by(rawcol=c, site=s).first()
                cx.dbcol = cdict[c] # assign new dbcol value for this rawcol
                cx.method = mdict[c] # assign new method
                cx.write_in = wdict[c] # assign new write-in method
                cx.addtl = adict[c] # assign new additional attributes
            else: # add
                cx = Grabcols(region, s, c, cdict[c], mdict[c], wdict[c], adict[c])
                db.session.add(cx)

def grab_updatedb(xx, fnamelist, replace=False):

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
        n_full_chunks = xx.shape[0] / 100000
        partial_chunk_len = xx.shape[0] % 100000

        if n_full_chunks == 0:
            xx = xx.to_dict('records')
            db.session.bulk_insert_mappings(Grabdata, xx) #ingest all records
        else:
            for i in xrange(n_full_chunks): #ingest full (100k-record) chunks
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

@app.route("/upload_confirm", methods=["POST"])
def confirmcolumns():

    #get combined inputs (tmpfile), varname mappings (cdict), and filenames
    cdict = json.loads(request.form['cdict'])
    tmpfile = request.form['tmpfile']
    cdict = dict([(r['name'], r['value']) for r in cdict])
    fnlong = session.get('fnlong')
    filenamesNoV = session.get('filenamesNoV')

    try:

        #load and format dataframe
        xx = pd.read_csv(os.path.join(app.config['UPLOAD_FOLDER'],
            tmpfile + ".csv"), parse_dates=[0])
        upid_col = xx['upload_id']
        xx = xx[cdict.keys()].rename(columns=cdict) #assign canonical names

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
            embargo = 1 # automatically embargo for 1 year, can change later in database...
            usgss = None if request.form['usgs']=="" else request.form['usgs']
            sx = Site(region=region, site=site, name=request.form['sitename'],
                latitude=request.form['lat'], longitude=request.form['lng'],
                usgs=usgss, addDate=datetime.utcnow(), embargo=embargo,
                by=current_user.get_id(), contact=request.form['contactName'],
                contactEmail=request.form['contactEmail'])
            db.session.add(sx)

            #give uploading user access to this site
            add_site_permission(current_user, region, site)

            # make a new text file with the metadata
            metastring = request.form['metadata']
            metafilepath = os.path.join(app.config['META_FOLDER'],
                region + "_" + site + "_metadata.txt")
            with open(metafilepath, 'a') as metafile:
                metafile.write(metastring)

        #format df for database entry
        xx = xx.set_index(["DateTime_UTC", "upload_id"])
        xx.columns.name = 'variable'
        xx = xx.stack() #one col each for vars and vals
        xx.name="value"
        xx = xx.reset_index()
        xx = xx.groupby(['DateTime_UTC','variable']).mean().reset_index() #dupes
        xx['region'] = region
        xx['site'] = site
        xx['flag'] = None
        xx = xx[['region','site','DateTime_UTC','variable','value','flag',
            'upload_id']]

        replace = True if request.form['replacing'] == 'yes' else False

        #add new filenames to upload table in db
        fn_to_db = [i[0] for i in filenamesNoV]
        filenamesNoV = sorted(filenamesNoV, key=itemgetter(1))
        filenamesNoV = [i for i in filenamesNoV if i[1] is not None]
        if filenamesNoV:
            for f in filenamesNoV:
                uq = Upload(f[0])
                db.session.add(uq)

    except:
        flash('Error 008. Please try again', 'alert-danger')
        os.remove(os.path.join(app.config['UPLOAD_FOLDER'], tmpfile + ".csv"))
        [os.remove(f) for f in fnlong]
        return redirect(url_for('series_upload'))

    try:
        #add data and mappings to db
        updatedb(xx, fn_to_db, replace)
        updatecdict(region, site, cdict)

    except:
        msg = Markup('Error 009. This is a particularly nasty error. Please <a href="mailto:vlahm13@gmail.com" class="alert-link">email Mike Vlah</a> with the error number and a copy of the file(s) you tried to upload.')
        os.remove(os.path.join(app.config['UPLOAD_FOLDER'], tmpfile + ".csv"))
        return redirect(url_for('series_upload'))

    os.remove(os.path.join(app.config['UPLOAD_FOLDER'], tmpfile + ".csv"))
    db.session.commit() #persist all db changes made during upload
    flash('Uploaded ' + str(len(xx.index)) + ' values, thank you!',
        'alert-success')

    return redirect(url_for('series_upload'))

@app.route("/grab_upload_confirm", methods=["POST"])
def grab_confirmcolumns():

    # try:

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

        # automatically embargo for 1 year
        embargo = 1

        #for each new site included in the uploaded csv...
        newsitelist = []
        for i in xrange(int(request.form['newlen'])):

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
                usgs=usgss, addDate=datetime.utcnow(), embargo=embargo,
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

    #replace user varnames with database varnames; attach upload_id column
    # xx_pre = xx.iloc[:,0:2]
    # xx_post = xx.iloc[:,2:]
    # xx_post = xx_post[cdict.keys()].rename(columns=cdict) #assign names
    # xx = pd.concat([xx_pre, xx_post], axis=1)
    cols_to_drop = [i for i in xx.columns[2:] if i not in cdict.keys()]
    xx = xx.drop(cols_to_drop, axis=1)
    xx['upload_id'] = upID

    #format df for database entry
    xx = xx.set_index(["DateTime_UTC", "upload_id", "Sitecode"])
    xx.columns.name = 'variable'
    xx = xx.stack() #one col each for vars and vals
    xx.name = "value"
    xx = xx.reset_index()

    for i in cdict.keys():
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
        uq = Grabupload(filenameNoV)
        db.session.add(uq)

    #add data and varname mappings to db tables
    grab_updatedb(xx, [filenameNoV], replace)
    sitelist = list(set(xx.site))
    grab_updatecdict(region, sitelist, cdict, mdict, wdict, adict)

    # except:
        # msg = Markup('Error 005. Please <a href=' +\
        #     '"mailto:vlahm13@gmail.com" class="alert-link">' +\
        #     'email</a> Mike Vlah with the error number and a copy of ' +\
        #     'the file you tried to upload.')
        # flash(msg, 'alert-danger')
        # return redirect(request.url)

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
    site_permiss = site_permiss[0] + ',' + regsites
    cx = User.query.filter_by(username=user.username).first()
    cx.qaqc = site_permiss

def getsitenames(regionsite):
    region, site = regionsite.split("_")
    names = pd.read_sql("select name from site where region='"+region+"' and site ='"+site+"'", db.engine)
    return (regionsite, region+" - "+names.name[0])

@app.route('/download')
def download():
    vv = pd.read_sql("select distinct region, site, variable from data", db.engine)
    sites = [x[0]+"_"+x[1] for x in zip(vv.region,vv.site)]
    if current_user.is_authenticated:
        sites = authenticate_sites(sites, user=current_user.get_id())
    else:
        sites = authenticate_sites(sites)
    ss = []
    for site in sites:
        r,s = site.split("_")
        ss.append("(region='"+r+"' and site='"+s+"') ")
    qs = "or ".join(ss)
    nn = pd.read_sql("select region, site, name from site",db.engine)
    dd = pd.read_sql("select region, site, min(DateTime_UTC) as startdate, max(DateTime_UTC) as enddate from data where "+qs+"group by region, site", db.engine)
    vv = vv.groupby(['region','site'])['variable'].unique().reset_index()
    dx = pd.merge(vv, nn.merge(dd, on=['region','site'], how='right'), on=['region','site'], how='right')
    dx['regionsite'] = [x[0]+"_"+x[1] for x in zip(dx.region,dx.site)]
    dx.startdate = dx.startdate.apply(lambda x: x.strftime('%Y-%m-%d'))
    dx.enddate = dx.enddate.apply(lambda x: x.strftime('%Y-%m-%d'))
    dx.name = dx.region+" - "+dx.name
    dvv = dx[['regionsite','name','startdate','enddate','variable']].values
    sitedict = sorted([tuple(x) for x in dvv], key=lambda tup: tup[1])
    return render_template('download.html', sites=sitedict)

@app.route('/_getstats',methods=['POST'])
def getstats():
    sitenm = request.json['site']
    xx = pd.read_sql("select * from data where concat(region,'_',site) in ('"+"', '".join(sitenm)+"') and flag is NULL", db.engine)
    startDate = xx.DateTime_UTC.min().strftime("%Y-%m-%d")
    endDate = (xx.DateTime_UTC.max()+timedelta(days=1)).strftime("%Y-%m-%d")
    initDate = (xx.DateTime_UTC.max()-timedelta(days=13)).strftime("%Y-%m-%d")
    #xx = pd.read_sql("select distinct variable from data", db.engine)
    variables = list(set(xx.variable))#xx['variable'].tolist()
    return jsonify(result="Success", startDate=startDate, endDate=endDate, initDate=initDate, variables=variables, site=sitenm)

@app.route('/_getcsv',methods=["POST"])
def getcsv():

    #retrieve form specifications
    sitenm = request.form['sites'].split(",")
    startDate = request.form['startDate']#.split("T")[0]
    endDate = request.form['endDate']
    variables = request.form['variables'].split(",")
    email = request.form.get('email')

    #deal with user info and login creds
    if current_user.get_id() is None: # not logged in
        uid = None
        if email is not None: # record email address
            elist = open("static/email_list.csv","a")
            elist.write(email+"\n")
            elist.close()
    else: # get logged in email
        uid = int(current_user.get_id())
        myuser = User.query.filter(User.id==uid).first()
        email = myuser.email

    # add download stats to db table
    dnld_stat = Downloads(timestamp=datetime.utcnow(), userID=uid, email=email,
        dnld_sites=request.form['sites'], dnld_date0=startDate,
        dnld_date1=endDate, dnld_vars=request.form['variables'])
    db.session.add(dnld_stat)
    db.session.commit() #should be at end of function

    # get more form data; make temp directory to pass to user
    aggregate = request.form['aggregate']
    dataform = request.form['dataform'] # wide or long format
    tmp = tempfile.mkdtemp()

    # add the data policy to the folder
    shutil.copy2("static/streampulse_data_policy.txt", tmp)

    #get data, metadata, etc for each site and put in temp directory
    nograbsites = []
    for s in sitenm:

        # get sensor data and flags for site s
        sqlq = "select data.*, flag.flag as flagtype, flag.comment as " +\
            "flagcomment from data " +\
            "left join flag on data.flag=flag.id where concat(data.region, " +\
            "'_', data.site)='" + s + "' and data.DateTime_UTC > '" +\
            startDate + "' and data.DateTime_UTC < '" + endDate + "' " +\
            "and data.variable in ('" + "', '".join(variables) + "');"
        xx = pd.read_sql(sqlq, db.engine)

        if len(xx) < 1:
            continue #why?

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
            xu = get_usgs([s], xx['DateTime_UTC'].min().strftime("%Y-%m-%d"), xx['DateTime_UTC'].max().strftime("%Y-%m-%d"))
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

        #put metadata in folder if metdata file exists
        mdfile = os.path.join(app.config['META_FOLDER'], s + "_metadata.txt")
        if os.path.isfile(mdfile):
            shutil.copy2(mdfile, tmp)

    #zip all files in temp dir as new zip dir, pass on to user
    writefiles = os.listdir(tmp) # list files in the temp directory
    zipname = 'SPdata_' + datetime.now().strftime("%Y-%m-%d") + '.zip'
    with zipfile.ZipFile(tmp + '/' + zipname, 'w') as zf:
        [zf.write(tmp + '/' + f, f) for f in writefiles]
    #flash('File sent: '+zipname, 'alert-success')

    if nograbsites:
        flash('No manually collected data available at specified time for ' +\
            'site(s): ' + ', '.join(nograbsites) + '.', 'alert-warning')

    return send_file(tmp + '/' + zipname, 'application/zip',
        as_attachment=True, attachment_filename=zipname)

@app.route('/visualize')
# @login_required
def visualize():
    vv = pd.read_sql("select distinct region, site, variable from data", db.engine)
    sites = [x[0]+"_"+x[1] for x in zip(vv.region,vv.site)]
    if current_user.is_authenticated:
        sites = authenticate_sites(sites, user=current_user.get_id())
    else:
        sites = authenticate_sites(sites)
    ss = []
    for site in sites:
        r,s = site.split("_")
        ss.append("(region='"+r+"' and site='"+s+"') ")
    qs = "or ".join(ss)
    nn = pd.read_sql("select region, site, name from site",db.engine)
    dd = pd.read_sql("select region, site, min(DateTime_UTC) as startdate, max(DateTime_UTC) as enddate from data where "+qs+"group by region, site", db.engine)
    vv = vv.groupby(['region','site'])['variable'].unique().reset_index()
    dx = pd.merge(vv, nn.merge(dd, on=['region','site'], how='right'), on=['region','site'], how='right')
    dx['regionsite'] = [x[0]+"_"+x[1] for x in zip(dx.region,dx.site)]
    dx.startdate = dx.startdate.apply(lambda x: x.strftime('%Y-%m-%d'))
    dx.enddate = dx.enddate.apply(lambda x: x.strftime('%Y-%m-%d'))
    dx.name = dx.region+" - "+dx.name
    dvv = dx[['regionsite','name','startdate','enddate','variable']].values
    sitedict = sorted([tuple(x) for x in dvv], key=lambda tup: tup[1])
    return render_template('visualize.html',sites=sitedict)

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

    print grabvarunits
    return jsonify(variables=grabvars, varsandunits=grabvarunits)

@app.route('/_getgrabviz', methods=["POST"])
def getvgrabviz():

    # region, site = request.json['regionsite'].split(",")[0].split("_")
    region, site = request.json['regionsite'].split("_")
    startDate = request.json['startDate']
    endDate = request.json['endDate']
    variables = request.json['grabvars']
    # variables = variables] if len(variables)
    # print region, site, startDate, endDate, variables

    #query partly set up for when this function will need to handle multiple vars
    sqlq = "select DateTime_UTC as date, value from grabdata where region='" +\
        region + "' and site='" +\
        site + "' " + "and DateTime_UTC>'" + startDate + "' "+\
        "and DateTime_UTC<'" + endDate + "' "+\
        "and variable in ('" + "', '".join(variables) + "');"
    xx = pd.read_sql(sqlq, db.engine)
    # xx.loc[xx.flag==0,"value"] = None # set NaNs
    # flagdat = xx[['DateTime_UTC','variable','flag']].dropna().drop(['flag'],
    #     axis=1).to_json(orient='records',date_format='iso') # flag data
    # xx = xx.drop_duplicates().set_index(["DateTime_UTC","variable"])

    # xx = xx.loc[xx.variable.isin(variables)]
    xx = xx.groupby(xx.date).mean().reset_index()
    xx = xx.to_json(orient='records', date_format='iso')

    return jsonify(grabdat=xx)

@app.route('/_getviz',methods=["POST"])
def getviz():
    region, site = request.json['site'].split(",")[0].split("_")
    startDate = request.json['startDate']
    endDate = request.json['endDate']#.split("T")[0]
    variables = request.json['variables']
    # print region, site, startDate, endDate, variables
    sqlq = "select * from data where region='"+region+"' and site='"+site+"' "+\
        "and DateTime_UTC>'"+startDate+"' "+\
        "and DateTime_UTC<'"+endDate+"' "+\
        "and variable in ('"+"', '".join(variables)+"')"
    xx = pd.read_sql(sqlq, db.engine)
    xx.loc[xx.flag==0,"value"] = None # set NaNs
    flagdat = xx[['DateTime_UTC','variable','flag']].dropna().drop(['flag'],axis=1).to_json(orient='records',date_format='iso') # flag data
    xx = xx.drop(['id','upload_id'], axis=1).drop_duplicates()\
      .set_index(["DateTime_UTC","variable"])\
      .drop(['region','site','flag'],axis=1)
    xx = xx[~xx.index.duplicated(keep='last')].unstack('variable') # get rid of duplicated date/variable combos
    xx.columns = xx.columns.droplevel()
    xx = xx.reset_index()
    # Get sunrise sunset data
    sxx = pd.read_sql("select * from site where region='"+region+"' and site='"+site+"'",db.engine)
    sdt = datetime.strptime(startDate,"%Y-%m-%d")
    edt = datetime.strptime(endDate,"%Y-%m-%d")
    ddt = edt-sdt
    lat = sxx.latitude[0]
    lng = sxx.longitude[0]
    rss = []
    for i in range(ddt.days + 1):
        rise, sets = list(suns(sdt+timedelta(days=i-1), latitude=lat, longitude=lng).calculate())
        if rise>sets:
            sets = sets + timedelta(days=1) # account for UTC
        rss.append([rise, sets])
    #
    rss = pd.DataFrame(rss, columns=("rise","set"))
    rss.set = rss.set.shift(1)
    sunriseset = rss.loc[1:].to_json(orient='records',date_format='iso')
    return jsonify(variables=variables, dat=xx.to_json(orient='records',date_format='iso'), sunriseset=sunriseset, flagdat=flagdat)

@app.route('/logbook')
def print_log():
    with open('templates/logbook.md', 'r') as f:
        logbook_md = f.read()
    logbook_md = Markup(markdown.markdown(logbook_md))
    return render_template('logbook.html', **locals())

@app.route('/clean')
@login_required
def qaqc():
    xx = pd.read_sql("select distinct region, site from data", db.engine)
    sitesa = [x[0]+"_"+x[1] for x in zip(xx.region,xx.site)]
    qaqcuser = current_user.qaqc_auth()
    sites = [z for z in sitesa if z in qaqcuser]
    #xx = pd.read_sql("select distinct flag from flag", db.engine)
    #flags = xx['flag'].tolist()
    flags = ['Interesting', 'Questionable', 'Bad Data']
    sitedict = sorted([getsitenames(x) for x in sites], key=lambda tup: tup[1])
    return render_template('qaqc.html',sites=sitedict,flags=flags, tags=[''])

@app.route('/_getqaqc',methods=["POST"])
def getqaqc():
    region, site = request.json['site'].split(",")[0].split("_")
    sqlq = "select * from data where region='"+region+"' and site='"+site+"'"
    xx = pd.read_sql(sqlq, db.engine) #this is what makes it take so long. read in 4w chunks
    xx.loc[xx.flag==0,"value"] = None # set NaNs
    flagdat = xx[['DateTime_UTC','variable','flag']].dropna().drop(['flag'],
        axis=1).to_json(orient='records',date_format='iso') # flag data
    #xx.dropna(subset=['value'], inplace=True) # remove rows with NA value
    variables = list(set(xx['variable'].tolist()))
    xx = xx.drop('id', axis=1).drop_duplicates()\
      .set_index(["DateTime_UTC","variable"])\
      .drop(['region','site','flag','upload_id'], axis=1)
    xx = xx[~xx.index.duplicated(keep='last')].unstack('variable') # get rid of duplicated date/variable combos
    xx.columns = xx.columns.droplevel()
    xx = xx.reset_index()
    # Get sunrise sunset data
    sxx = pd.read_sql("select * from site where region='"+region+"' and site='"+site+"'",db.engine)
    sdt = min(xx.DateTime_UTC).replace(hour=0, minute=0,second=0,microsecond=0)
    edt = max(xx.DateTime_UTC).replace(hour=0, minute=0,second=0,microsecond=0)+timedelta(days=1)

    ddt = edt-sdt
    lat = sxx.latitude[0]
    lng = sxx.longitude[0]
    rss = []
    for i in range(ddt.days + 1):
        rise, sets = list(suns(sdt+timedelta(days=i-1), latitude=lat, longitude=lng).calculate())
        if rise>sets:
            sets = sets + timedelta(days=1) # account for UTC
        rss.append([rise, sets])
    #
    rss = pd.DataFrame(rss, columns=("rise","set"))
    rss.set = rss.set.shift(1)
    sunriseset = rss.loc[1:].to_json(orient='records',date_format='iso')
    # Get 2wk plot intervals
    def daterange(start, end):
        r = (end+timedelta(days=1)-start).days
        if r%14 > 0:
            r = r+14
        return [(end-timedelta(days=i)).strftime('%Y-%m-%d') for i in range(0,r,28)]
    #drr = pd.date_range(sdt,edt,freq="14D").tolist()[::-1] # need to reverse
    #drr = [da.strftime('%Y-%m-%d') for da in drr]
    drr = daterange(sdt,edt)
    return jsonify(variables=variables, dat=xx.to_json(orient='records',date_format='iso'), sunriseset=sunriseset, flagdat=flagdat, plotdates=drr)

@app.route('/_outlierdetect',methods=["POST"])
def outlier_detect():
    dat_chunk = pd.DataFrame(request.json)
    # dat_chunk.to_csv('~/Dropbox/streampulse/data/test_outl2.csv', index=False)

    outl_ind_r = find_outliers(dat_chunk) #call R code for outlier detect

    outl_ind = {}
    for j in xrange(1, len(outl_ind_r) + 1): #loop through R-ified list

        if outl_ind_r.rx2(j)[0] == 'NONE':
            outl_ind[outl_ind_r.names[j-1]] = None
            continue

        tmp_lst = []
        for i in outl_ind_r.rx2(j):
            tmp_lst.append(int(i))
        outl_ind[outl_ind_r.names[j-1]] = tmp_lst

    return jsonify(outliers=outl_ind)

@app.route('/_addflag',methods=["POST"])
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

# @app.route('/_addtag',methods=["POST"])
# def addtag():
#     rgn, ste = request.json['site'].split("_")
#     sdt = dtparse.parse(request.json['startDate'])
#     edt = dtparse.parse(request.json['endDate'])
#     var = request.json['var']
#     tag = request.json['tagid']
#     cmt = request.json['comment']
#     for vv in var:
#         ttt = Tag(rgn, ste, sdt, edt, vv, tag, cmt, int(current_user.get_id()))
#         db.session.add(ttt)
#         db.session.commit()
#     # flgdat = Data.query.filter(Data.region==rgn,Data.site==ste,Data.DateTime_UTC>=sdt,Data.DateTime_UTC<=edt,Data.variable==var).all()
#     # for f in flgdat:
#     #     f.flag = fff.id
#     # db.session.commit()
#     return jsonify(result="success")

# @app.route('/_addna',methods=["POST"])
# def addna():
#     rgn, ste = request.json['site'].split("_")
#     sdt = dtparse.parse(request.json['startDate'])
#     edt = dtparse.parse(request.json['endDate'])
#     var = request.json['var']
#     # add NA flag = 0
#     flgdat = Data.query.filter(Data.region==rgn,Data.site==ste,Data.DateTime_UTC>=sdt,Data.DateTime_UTC<=edt,Data.variable==var).all()
#     for f in flgdat:
#         f.flag = 0
#     db.session.commit()
#     # new query
#     sqlq = "select * from data where region='"+rgn+"' and site='"+ste+"'"
#     xx = pd.read_sql(sqlq, db.engine)
#     xx.loc[xx.flag==0,"value"] = None # set NaNs
#     xx.dropna(subset=['value'], inplace=True) # remove rows with NA value
#     xx = xx.drop(['id','upload_id'], axis=1).drop_duplicates()\
#       .set_index(["DateTime_UTC","variable"])\
#       .drop(['region','site','flag'],axis=1)
#     xx = xx[~xx.index.duplicated(keep='last')].unstack('variable') # get rid of duplicated date/variable combos
#     xx.columns = xx.columns.droplevel()
#     xx = xx.reset_index()
#     return jsonify(dat=xx.to_json(orient='records',date_format='iso'))

# @app.route('/cleandemo')
# def qaqcdemo():
#     sqlq = "select * from data where region='NC' and site='NHC' and "+\
#         "DateTime_UTC>'2016-09-23' and DateTime_UTC<'2016-10-07' and "+\
#         "variable in ('DO_mgL','WaterPres_kPa','CDOM_mV','Turbidity_mV','WaterTemp_C','pH','SpecCond_mScm')"
#     # sqlq = "select * from data where region='NC' and site='Mud'"
#     xx = pd.read_sql(sqlq, db.engine) # training data
#     # xx.loc[xx.flag==0,"value"] = None # set NaNs existing flags
#     flagdat = xx[['DateTime_UTC','variable','flag']].dropna().drop(['flag'],axis=1).to_json(orient='records',date_format='iso') # flag data
#     variables = list(set(xx['variable'].tolist()))
#     xx = xx.drop(['id','upload_id'], axis=1).drop_duplicates()\
#       .set_index(["DateTime_UTC","variable"])\
#       .drop(['region','site','flag'],axis=1)\
#       .unstack('variable')
#     xx.columns = xx.columns.droplevel()
#     xx = xx.reset_index()
#         # get anomaly dates
#     xtrain = xx[(xx.DateTime_UTC<'2016-09-29')].dropna()# training data first portion
#     clf = svm.OneClassSVM(nu=0.01,kernel='rbf',gamma='auto')
#     xsvm = xtrain.as_matrix(variables)
#     clf.fit(xsvm)
#     # xss.assign(pred=clf.predict(xsvm))
#     xss = xx.dropna()
#     xpred = xss.as_matrix(variables)
#     xss['pred'] = clf.predict(xpred).tolist()
#     anomaly = xss[xss.pred==-1].DateTime_UTC.to_json(orient='records',date_format='iso')
#     # Get sunrise sunset data
#     sxx = pd.read_sql("select * from site where region='NC' and site='NHC'",db.engine)
#     sdt = min(xx.DateTime_UTC).replace(hour=0, minute=0,second=0,microsecond=0)
#     edt = max(xx.DateTime_UTC).replace(hour=0, minute=0,second=0,microsecond=0)+timedelta(days=1)
#     ddt = edt-sdt
#     lat = sxx.latitude[0]
#     lng = sxx.longitude[0]
#     rss = []
#     for i in range(ddt.days + 1):
#         rise, sets = list(suns(sdt+timedelta(days=i-1), latitude=lat, longitude=lng).calculate())
#         if rise>sets:
#             sets = sets + timedelta(days=1) # account for UTC
#         rss.append([rise, sets])
#     #
#     rss = pd.DataFrame(rss, columns=("rise","set"))
#     rss.set = rss.set.shift(1)
#     sunriseset = rss.loc[1:].to_json(orient='records',date_format='iso')
#     return render_template('qaqcdemo.html', variables=variables, dat=xx.to_json(orient='records',date_format='iso'), sunriseset=sunriseset, flagdat=flagdat, anomaly=anomaly)

@app.route('/api')
def api():

    #pull in requests
    startDate = request.args.get('startdate')
    endDate = request.args.get('enddate')
    variables = request.args.get('variables')
    sites = request.args['sitecode'].split(',')

    #tests
    if request.headers.get('Token') is not None:
        sites = authenticate_sites(sites, token=request.headers['Token'])
    elif current_user.is_authenticated:
        sites = authenticate_sites(sites, user=current_user.get_id())
    else:
        sites = authenticate_sites(sites)

    #assemble sql queries for data and metadata
    ss = []; ss2 = []
    for site in sites:
        r,s = site.split("_")
        ss.append("(region='"+r+"' and site='"+s+"') ")
        ss2.append("(data.region='"+r+"' and data.site='"+s+"') ")

    qs = "or ".join(ss)
    qs2 = "or ".join(ss2)

    meta = pd.read_sql("select region, site, name, latitude as lat, " +\
        "longitude as lon, usgs as usgsid from site where " + qs, db.engine)

    sqlq = "select data.region, data.site, data.DateTime_UTC, " +\
        "data.variable, data.value, flag.flag as flagtype, flag.comment as " +\
        "flagcomment from data left join flag on data.flag = flag.id where " +\
        qs2

    if startDate is not None:
        sqlq = sqlq+"and data.DateTime_UTC>'"+startDate+"' "
    if endDate is not None:
        sqlq = sqlq+"and data.DateTime_UTC<'"+endDate+"' "
    if variables is not None:
        vvv = variables.split(",")
        sqlq = sqlq+"and data.variable in ('"+"', '".join(vvv)+"')"

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
                max(xx.DateTime_UTC).strftime("%Y-%m-%d"))
            if len(xu) == 1 and xu == 'USGS_error':
                return jsonify(data=xu)
        if "Depth_m" in variables and "Depth_m" not in vv and len(xu) is 0:
            xu = get_usgs(sites, min(xx.DateTime_UTC).strftime("%Y-%m-%d"),
                max(xx.DateTime_UTC).strftime("%Y-%m-%d"))
            if len(xu) == 1 and xu == 'USGS_error':
                return jsonify(data=xu)

    if len(xu) is not 0:
        # subset usgs data based on each site's dates
        xx = pd.concat([xx,xu])

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

@app.route('/model')
def modelgen():
    xx = pd.read_sql("select distinct region, site from data", db.engine)
    sites = [x[0]+"_"+x[1] for x in zip(xx.region,xx.site)]
    if current_user.is_authenticated:
        sites = authenticate_sites(sites, user=current_user.get_id())
    else:
        sites = authenticate_sites(sites)
    ss = []
    for site in sites:
        r,s = site.split("_")
        ss.append("(region='"+r+"' and site='"+s+"') ")
    qs = "or ".join(ss)
    nn = pd.read_sql("select region, site, name from site",db.engine)
    dd = pd.read_sql("select region, site, min(DateTime_UTC) as startdate, max(DateTime_UTC) as enddate from data where "+qs+"group by region, site", db.engine)
    # dd = pd.read_sql_table('data',db.engine)[['region','site','DateTime_UTC']]
    # dd = pd.concat([dd.groupby(['region','site']).DateTime_UTC.min(),dd.groupby(['region','site']).DateTime_UTC.max()], axis=1)
    # dd.columns = ['startdate','enddate']
    # dd = dd.reset_index()
    dx = nn.merge(dd, on=['region','site'], how='right')
    dx['regionsite'] = [x[0]+"_"+x[1] for x in zip(dx.region,dx.site)]
    dx.startdate = dx.startdate.apply(lambda x: x.strftime('%Y-%m-%d'))
    dx.enddate = dx.enddate.apply(lambda x: x.strftime('%Y-%m-%d'))
    dx.name = dx.region+" - "+dx.name
    sitedict = sorted([tuple(x) for x in dx[['regionsite','name','startdate','enddate']].values], key=lambda tup: tup[1])
    return render_template('model.html',sites=sitedict)

if __name__=='__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
