#!/bin/bash
cd /var/www/luyfdash/prod/luyf-dashboard/
source ./venv/bin/activate 
gunicorn --workers 16 --bind 0.0.0.0:5007 luyfdash:app
