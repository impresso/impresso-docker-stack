import urllib.parse
from .settings import *
DEBUG = True
CORS_ORIGIN_WHITELIST = []
ALLOWED_HOSTS = '*'
SOLR_USERNAME=urllib.parse.quote('[!!!REPLACE] solr_username')
SOLR_PASSWORD=urllib.parse.quote('[!!!REPLACE] solr_password')
SOLR_BASE_URL_PART='[!!!REPLACE] solr.myimpresso.mycompany.com/solr'
SOLR_BASE_URL=f'https://{SOLR_USERNAME}:{SOLR_PASSWORD}@{SOLR_BASE_URL_PART}'
