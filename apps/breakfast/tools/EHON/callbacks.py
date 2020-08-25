from dash.dependencies import Input, Output
from app import app
import subprocess
from tools.serial.tools.list_ports import comports

current_ports = {}
# Select Port Dropdown
@app.callback(Output('port-dropdown', 'options'),
              [Input('interval-component', 'n_intervals'),
               Input('port-dropdown', 'value')])
def update_port(n_intervals, port_selected):
    new_ports = {}
    ports = sorted(comports())
    for port, desc, hwid in ports:
        if "Bluetooth" not in port:
            new_ports[port] = port
    if new_ports != current_ports:
        current_ports.clear()
        current_ports.update(new_ports)
    return [{'label': k, 'value': k} for k in current_ports.keys()]


# Button that links to the old UI
@app.callback(Output('text', 'children'),
              [Input('btn', 'n_clicks')])
def download(number_clicks):
    if number_clicks > 0:
        subprocess.call("/Users/jianingfang/Desktop/tinyos-main-1/apps/breakfast/tools/Life/DashboardInternal.py")
    return "Called {} times".format(number_clicks)