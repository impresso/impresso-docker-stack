import urllib.parse
from .settings import *
import os

DEBUG = True
CORS_ORIGIN_WHITELIST = []
ALLOWED_HOSTS = "*"

SOLR_USERNAME = urllib.parse.quote(os.environ.get("SOLR_READER_USERNAME"))
SOLR_PASSWORD = urllib.parse.quote(os.environ.get("SOLR_READER_PASSWORD"))
SOLR_BASE_URL_NO_AUTH = os.environ.get("SOLR_BASE_URL")
SOLR_BASE_URL = SOLR_BASE_URL_NO_AUTH.replace(
    "://", f"://{SOLR_USERNAME}:{SOLR_PASSWORD}@"
)

SOLR_TOPICS_COLLECTION = "impresso_topics_dev"
