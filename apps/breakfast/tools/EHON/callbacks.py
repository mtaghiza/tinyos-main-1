from dash.dependencies import Input, Output
from app import app
from tools.serial.tools.list_ports import comports

current_ports = {}


# Select Port Dropdown
@app.callback(Output('port-dropdown', 'options'),
              [Input('interval-component', 'n_intervals'),
               Input('port-dropdown', 'value')])
def update_port(n_intervals, port_selected):
    # print("hello")
    new_ports = {}
    ports = sorted(comports())
    # print(ports)
    for port, desc, hwid in ports:
        if "Bluetooth" not in port:
            new_ports[port] = port
    if new_ports != current_ports:
        current_ports.clear()
        current_ports.update(new_ports)
    return [{'label': k, 'value': k} for k in current_ports.keys()]


# Place holder function for illustrative purpose only. Will need to adjust link to database later on.
def get_deployment_names():
    return ['JHU-Olin Hall', 'Cub Hill Experiment',
            'SERC Soil Moisture', 'USDA Agricultural Field', 'Ecuador Tropical Rain Forest']


@app.callback(Output('select-deployment-dropdown', 'options'),
              [Input('select-deployment-dropdown', 'value'),
               Input('port-dropdown', 'value')])
def update_select_deployment_dropdown(selection):
    print("test")
    return [{'label': i, 'value': i} for i in get_deployment_names()]
