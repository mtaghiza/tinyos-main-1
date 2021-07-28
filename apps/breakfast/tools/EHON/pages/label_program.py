import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output, State
from label_label import label_top_disabled
from app import app
import dash
from HandlerWrapper import handler
from tools.serial.tools.list_ports import comports
import time

# from HandlerWrapper import mock_handler

layout = html.Div(children=[
    html.Div(id='top-section',
             children=html.Div(id='Logos',
                               children=label_top_disabled,
                               style={'height': '10vh',
                                      'overflow': 'hidden'})
             ),

    html.Hr(style={'margin-top': '1vh'}),

    html.Div([html.Div(children=[
        html.H5("Program Setting",
                style={'margin-top': '7vh', 'margin-left': '2vw'}),

        dcc.Tabs([
            dcc.Tab(label='Basestation', children=[
                html.Div(
                    children=[
                        html.Div(children=[html.H6("Channel"),
                                           dcc.Dropdown(value='',
                                                        id='select-radio-channel',
                                                        placeholder='select channel',
                                                        options=[{'label':i, 'value':i} for i in range(0, 256, 32)]),
                                           ],
                                 style={'flex': '50vw'}),
                        html.Div(children=[],
                                 style={'flex': '50vw'})],
                    style={'display': 'flex'}
                ),
            ], id='type-base'),
            dcc.Tab(label='Leaf', children=[
                html.Div(
                    children=[
                        html.Div(children=[html.H6("Channel"),
                                           dcc.Dropdown(value='',
                                                        id='select-radio-channel-leaf',
                                                        placeholder='select channel',
                                                        options=[{'label':i, 'value':i} for i in range(0, 256, 32)]),
                                           html.H6("Sample Interval (min)"),
                                           dcc.Dropdown(value='',
                                                        id="select-sample-interval",
                                                        placeholder="select sample interval",
                                                        options=[{'label':i, 'value':i} for i in iter([1, 3, 5, 10, 15, 20, 30, 60, 120, 180])]),
                                           ],
                                 style={'flex': '50vw'}),
                        html.Div(children=[],
                                 style={'flex': '50vw'})],
                    style={'display': 'flex'}
                ),
            ], id='type-leaf'),
            dcc.Tab(label='Router', children=[
            ], id='type-router'),
        ], id='select-device-type-to-program'),
    ], id='program-setting-box',
        style={'flex': '36vw', 'height': '89vh',
               'border-right': '0.5px solid',
               'border-top': '0.5px solid',
               'margin-top': '0vh',
               'margin-left': '0vh'}),
        html.Div(children=[

            html.H5("Select Port", style={'display': 'block',
                                          'float': "left",
                                          'margin-top': '30vh',
                                          'margin-left': '10vw'}),
            html.Div(
                dcc.Dropdown(
                    id='port-dropdown-program',
                    style={'width': '40vw'},
                    placeholder='Select port...'
                ), style={'margin-left': '18vh'}),

            html.Button(id='connect-button-program',
                        children="Connect",
                        n_clicks=0,
                        style={'color': 'white',
                               'margin-top': '15vh',
                               'margin-left': ' 41.5vw',
                               'background-color': '#2185D0',
                               'display': 'inline'}),
            dcc.Link(html.Button(id='quit-button',
                                 children="Cancel",
                                 n_clicks=0,
                                 style={'color': '#414141',
                                        'margin-top': '15vh',
                                        'margin-left': ' 1vw',
                                        'display': 'inline',
                                        'background-color': '#E0E1E2'}), href='/label_start'),

            dcc.Interval(
                id='interval-component-program',
                interval=1 * 1000,
                n_intervals=0),

            dcc.Interval(
                id='programming-pin-interval',
                interval=1 * 1000,
                n_intervals=0),

            html.Div(id='program-status')

        ], id='select-port-box',
            style={'flex': '64vw',
                   'border-top': '0.5px solid',
                   'height': '89vh'})
    ],
        id='program-select-port-and-program-setting',
        style={'display': 'flex',
               'margin-top': '0vh',
               'margin-left': '0vh'}),
])

# TODO: change this into a hidden element to avoid the usage of global variable
current_ports_program = {}


# TODO compile binaries and implement custom programming with different channel / sample interval
@app.callback([Output('connect-button-program', 'children'),
               Output('connect-button-program', 'style'),
               Output('connect-button-program', 'disabled'),
               Output('port-dropdown-program', 'disabled'),
               Output('program-status', 'children'),
               Output('quit-button', 'disabled')],
              [Input('connect-button-program', 'n_clicks'),
               Input('programming-pin-interval', 'n_intervals')],
              [State('select-device-type-to-program', 'value'),
               State('port-dropdown-program', 'value')])
def program_device(n_clicks, n_intervals, device_type, port):
    busy_style = {'color': 'white', 'margin-top': '15vh', 'margin-left': ' 41.5vw', 'background-color': '#13900B',
                  'display': 'inline'}
    idle_style = {'color': 'white', 'margin-top': '15vh', 'margin-left': ' 41.5vw', 'background-color': '#2185D0',
                  'display': 'inline'}
    ctx = dash.callback_context
    if ctx.triggered[0]['prop_id'].split('.')[0] == 'programming-pin-interval':
        time.sleep(0.2)
        if handler.programming:
            return "Programming...", busy_style, True, True, "", True
        else:
            if handler.programmingStatus:
                return "Program", idle_style, False, False, "Programming successful", False
            else:
                return "Program", idle_style, False, False, "", False
    if n_clicks > 0:
        if not port:
            return "Program", idle_style, False, False, "No port selected", False
        if device_type == 'tab-1':
            print('program basestation')
            handler.programBasestation(port)
            return "Programming...", busy_style, True, True, "", True
        elif device_type == "tab-2":
            print('program leaf')
            handler.programLeaf(port)
            return "Programming...", busy_style, True, True, "", True
        elif device_type == "tab-3":
            print('program router')
            handler.programRouter(port)
            return "Programming...", busy_style, True, True, "", True
    else:
        return "Program", idle_style, False, False, "", False


# Select Port Dropdown
@app.callback(Output('port-dropdown-program', 'options'),
              [Input('interval-component-program', 'n_intervals'),
               Input('port-dropdown-program', 'value')])
def update_port(n_intervals, port_selected):
    new_ports = {}
    ports = sorted(comports())
    for port, desc, hwid in ports:
        if "Bluetooth" not in port:
            new_ports[port] = port
    if new_ports != current_ports_program:
        current_ports_program.clear()
        current_ports_program.update(new_ports)
    return [{'label': k, 'value': k} for k in current_ports_program.keys()]

