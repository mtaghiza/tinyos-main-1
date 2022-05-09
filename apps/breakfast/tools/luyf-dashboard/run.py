#!python
from luyfdash import app, port_number, debug, host_ip, use_reloader

if __name__ == "__main__":
    app.run(debug=debug, port=port_number, host= host_ip, use_reloader=use_reloader)
