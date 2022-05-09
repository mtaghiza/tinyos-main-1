from SciServer import Authentication
from flask import redirect, url_for, request, render_template, session
from luyfdash import app, sciserver_portal_login_url, sciserver_portal_logout_url, website_url, webapp_root

from datetime import timedelta
import urllib
from functools import wraps


def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if (session.get('logged_in') != True) or (session.get('user_token') is None) :
            return redirect(url_for('login', next=request.url))
        return f(*args, **kwargs)
    return decorated_function

# -------------------------------------------------------------------------------------------------------------- #
# endpoint definitions

@app.route('/')
def index():

    token = session.get("user_token")
    if session.get('logged_in') and (token is not None):
        # TODO check that user token is valid before redirecting
        return render_template('index.html', user_name=session.get('user_name'), WEBAPP_ROOT=webapp_root)
    else:
        try:
            return render_template('index.html', user_name=session.get('user_name'), WEBAPP_ROOT=webapp_root)
        except Exception as e:
            error = str(e)
            error = "An error occurred."
            return render_template('index.html', error=error, user_name=session.get('user_name'), WEBAPP_ROOT=webapp_root)


@app.route('/login',methods = ['POST', 'GET'])
def login():
    error = None
    token=session.get('user_token')
    if ( session.get('logged_in') != True) or (token is None) :
        try:

            sciserver_token = request.args.get('token')
            if sciserver_token is not None and sciserver_token != "":
                user = Authentication.getKeystoneUserWithToken(sciserver_token)

                session['user_name'] = user.userName
                session['user_id'] = user.id
                session['error_message'] = None
                session['logged_in'] = True
                session['user_token'] = sciserver_token

                session.permanent = True
                app.permanent_session_lifetime = timedelta(days=999999)  # never expire
                session.modified = True
                return redirect(url_for('dashboard'))

            else:

                callback_url = urllib.parse.quote(website_url + url_for("login"))
                sciserver_login_url = sciserver_portal_login_url + "?callbackUrl=" +  callback_url
                return redirect(sciserver_login_url)

        except Exception as e:
            error = str(e)
            session['logged_in'] = False
            session['user_token'] = None
            return render_template('index.html', error=error, WEBAPP_ROOT=webapp_root)
    else:
        return redirect(url_for('index'))

@app.route('/logout', methods=['GET'])
def logout():
    session.clear()
    session['logged_in'] = False
    session['user_name'] = None
    session['user_token'] = None
    callback_url = urllib.parse.quote(website_url + url_for("index"))
    return redirect(sciserver_portal_logout_url + "?callbackUrl=" + callback_url)


@app.route('/dashboard', methods = ['GET'])
@login_required
def dashboard():

    error = None
    user_name = session['user_name']
    user_id = session['user_id']
    sciserver_token = session['user_token']
    try:
        return render_template('dashboard.html', user_name=user_name, SCISERVER_TOKEN=sciserver_token, WEBAPP_ROOT=webapp_root)
    except Exception as e:
        error = str(e)
        return render_template('dashboard.html', user_name=user_name, error=error, sciserver_token=sciserver_token, WEBAPP_ROOT=webapp_root)

@app.route('/api/ping', methods = ['GET'])
def ping():
    return app.response_class(status=200, response="App is alive.")

@app.route('/api/health', methods = ['GET'])
def health():
    # for now
    return app.response_class(status=200, response="App is healthy.")


@app.after_request
def after_request(response):
    #response.headers["Cache-Control"] = "must-revalidate"
    return response
