from flask import Flask
app = Flask(__name__, instance_relative_config=True)

app.config.from_object('config')
app.secret_key = app.config["SECRET_KEY"]
debug = app.config['DEBUG']
use_reloader = app.config["USE_RELOADER"]
host_ip = app.config['HOST_IP']
port_number = int(app.config["PORT"])
sciserver_portal_url = app.config["SCISERVER_PORTAL_URL"]
sciserver_portal_login_url = app.config["SCISERVER_PORTAL_LOGIN_URL"]
sciserver_portal_logout_url = app.config["SCISERVER_PORTAL_LOGOUT_URL"]
website_url = app.config["WEBSITE_URL"].rstrip("/")
webapp_root = app.config["WEBSITE_ROOT"] 

import luyfdash.views.controller




