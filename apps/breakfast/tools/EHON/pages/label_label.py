import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output, State
from app import app
from apps.breakfast.tools.EHON.tools.serial.tools.list_ports import comports
from HandlerWrapper import handler
import dash
import numpy as np
import dash_table
from pandas import DataFrame
import random

from apps.breakfast.tools.EHON.tools.labeler.BreakfastError import TagNotFoundError

label_top_disabled = [
    html.Img(id='JHU_Logo',
             src=app.get_asset_url('JHU-Logo1.svg'),
             style={'float': 'left', 'margin-top': '1vh', 'height': '7vh'}),
    html.Img(id='Label',
             src=app.get_asset_url('Label-Logo-Blue.svg'),
             style={'margin-left': '5vw', 'height': '10vh'}),
    html.Img(id='Deploy',
             src=app.get_asset_url('Deploy-Logo-Gray.svg'),
             style={'margin-left': '10vw', 'height': '10vh'}),
    html.Img(id='Data',
             src=app.get_asset_url('Data-Logo-Gray.svg'),
             style={'margin-left': '10vw', 'height': '10vh'}),
    html.Img(id='Share',
             src=app.get_asset_url('Share-Logo-Gray.svg'),
             style={'margin-left': '10vw', 'height': '10vh'}),
    html.Img(id='EHON1',
             src=app.get_asset_url('EHON-Logo.svg'),
             style={'margin-left': '0vw', 'height': '4vh',
                    'width': '36vh', 'float': 'right', 'margin-top': '3vh', 'margin-right': '3vw'})
]

layout = html.Div(children=[
    html.Div(id='top-section',
             children=html.Div(id='Logos',
                               children=label_top_disabled,
                               style={'height': '10vh',
                                      'overflow': 'hidden'})
             ),

    html.Div([html.Div(children=[

        html.H5("Select Device Type", style={'float': "left",
                                             'margin-top': '3vh',
                                             'margin-left': '3vw'}),
        html.Div(dcc.Dropdown(
            id='label-device-type',
            options=[
                {'label': 'Bacon Node', 'value': 'bacon'},
                {'label': 'Toast Multiplexer & Sensors', 'value': 'toast'}
            ],
            placeholder='Select device type to label',
            style={'width': '30vw'}
        ),
            style={'margin-left': '3vw',
                   'margin-top': '3vh'}),

        html.H5("Select Port", style={'float': "left",
                                      'margin-top': '3vh',
                                      'margin-left': '3vw'}),
        html.Div(
            dcc.Dropdown(
                id='port-dropdown',
                style={'width': '30vw'},
                placeholder='Select port...'
            ), style={'margin-left': '3vw'}),

        html.Button(id='connect-for-label',
                    children="Connect",
                    n_clicks=0,
                    style={'color': 'white',
                           'background-color': '#2185D0',
                           'margin-top': '15vh',
                           'margin-left': ' 3vw',
                           'display': 'inline', }),
        dcc.Link(html.Button(id='quit',
                             children="Cancel",
                             n_clicks=0,
                             style={'color': '#414141',
                                    'margin-top': '15vh',
                                    'margin-left': ' 1vw',
                                    'display': 'inline',
                                    'background-color': '#E0E1E2'}), href='/label_start'),

        html.Div(id='connect-status-box'),

        dcc.Interval(
            id='interval-component',
            interval=1 * 1000,
            n_intervals=0)

    ], id='program-setting-box',
        style={'flex': '36vw',
               'height': '89vh',
               'border-right': '0.5px solid',
               'border-top': '0.5px solid',
               'margin-top': '0vh',
               'margin-left': '0vh'}),
        html.Div(children=[
            html.Img(id='device-pic',
                     src=app.get_asset_url("Basestation.svg"),
                     style={'height': "60vh",
                            'margin-left': '10vw',
                            'margin-top': '7vh',
                            'border': 'solid',
                            'border-width': '0.5px'
                            }),
        ], id='image-box',
            style={'flex': '64vw',
                   'border-top': '0.5px solid',
                   'height': '89vh'})
    ],
        id='label-connect-body',
        style={'display': 'flex',
               'margin-top': '0vh',
               'margin-left': '0vh'}),

    html.Div(
        children=[html.H4("Label bacon node"),
                  html.Div(children=[
                      html.H4('Current Bacon ID: Barcode Not Set', id='bacon-barcode-box'),
                      html.H4('Mfr ID: FILLER MANUFACTURER ID', id='bacon-mfr-box'),
                      dcc.Input(id='bacon-id-input-box',
                                placeholder="Enter new node id to label",
                                style={'width': '40vw'}),
                      html.Div(id='bacon-warning-box')
                  ],
                      style={
                          'width': '40vw',
                          'height': '30vh',
                          'margin-left': '25vw',
                          'margin-top': '14vh',
                          'border': '0.5px solid',
                          'border-radius': '10px'}
                  ),
                  html.Div(
                      children=[html.Div(html.Button('Label'), id='bacon-label-button', n_clicks=0),
                                html.Div(dcc.Link(html.Button('Cancel'), href="label_start"),
                                         style={'margin-left': '3vw'})],
                      style={'display': 'flex', 'margin-top': '3vh', 'margin-left': '47vw'}
                  ),

                  # check updated bacon info
                  dcc.Interval(id="bacon-status-check-interval",
                               interval=2 * 1000,
                               n_intervals=0),
                  ],
        id='label-label-bacon',
        style={'display': 'none',
               'margin-top': '0vh',
               'margin-left': '0vh'}
    ),

    html.Div(
        id='label-label-toast',
        children=[
            html.Div(children=[
                html.Div(children=[
                    html.H5('Labelling toast multiplexer', style={"margin-top": "5vh"})
                ], style={'height': '9vh', 'border-bottom': '0.5px solid'}),
                html.Div(children=[
                    html.H6("Current ID: Barcode Not Set", id="toast-barcode-box"),
                    html.H6("Mfr ID: XXXXXXXXXXXXXXXX", id="toast-mfr-id-box"),
                    html.H6("New Node ID"),
                    dcc.Input(placeholder="Scan or Type in Toast ID", style={"width": "30vh"}, id="toast-id-input-box"),
                    html.Button("Save", style={'color': 'white', 'background-color': '#2185D0'})
                ], style={'height': '25vh', 'border-bottom': '0.5px solid'}),
                html.Div(children=[
                    html.H6("Channel Assignment"),
                    html.Div(id="sensor-table-container")
                ],
                    style={'height': '49vh'},
                    id=''),
            ], id='toast-label-box',
                style={'display': 'block',
                       'flex': '36vw',
                       'height': '89vh',
                       'border-right': '0.5px solid',
                       'border-top': '0.5px solid',
                       'margin-top': '0vh',
                       'margin-left': '0vh'}),

            dcc.Interval(id='sensor-update-timer', interval=1000, n_intervals=0),

            html.Div(children=[
                dcc.Graph(
                    figure=dict(
                        data=[
                            dict(
                                x=[1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003,
                                   2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012],
                                y=[219, 146, 112, 127, 124, 180, 236, 207, 236, 263,
                                   350, 430, 474, 526, 488, 537, 500, 439],
                                name='Channel 0',
                                marker=dict(
                                    color='rgb(55, 83, 109)'
                                )
                            ),
                            dict(
                                x=[1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003,
                                   2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012],
                                y=[16, 13, 10, 11, 28, 37, 43, 55, 56, 88, 105, 156, 270,
                                   299, 340, 403, 549, 499],
                                name='Channel 1',
                                marker=dict(
                                    color='rgb(26, 118, 255)'
                                )
                            )
                        ],
                        layout=dict(
                            title='Sensor Readings',
                            showlegend=True,
                            legend=dict(
                                x=0,
                                y=1.0
                            ),
                            margin=dict(l=40, r=0, t=40, b=30)
                        )
                    ),
                    style={'height': '80vh', 'width': '60vw'},
                    id='sensor-graph'
                )
            ], id='sensor-image-box',
                style={'flex': '64vw',
                       'border-top': '0.5px solid',
                       'height': '89vh',
                       'margin-top': '0vh'})
        ],
        style={'display': 'none',
               'margin-top': '0vh',
               'margin-left': '0vh'}
    )
])


@app.callback(Output("sensor-graph", "figure"),
              Input("bacon-status-check-interval", "n_intervals"),
              State("sensor-graph", "figure"))
def update_sensor_graph(n_intervals, figure):
    if n_intervals > 0:
        figure["data"][0]["x"].append(figure["data"][0]["x"][-1]+ 1)
        figure["data"][0]["y"].append(figure["data"][0]["y"][-1] + np.random.normal(scale=0.05))
        figure["data"][1]["x"].append(figure["data"][1]["x"][-1]+ 1)
        figure["data"][1]["y"].append(figure["data"][1]["y"][-1] + np.random.normal(scale=0.05))

    else:
        figure = dict(
            data=[
                dict(
                    x=[1],
                    y=[3],
                    name='Channel 0',
                    marker=dict(
                        color='rgb(55, 83, 109)'
                    )
                ),
                dict(
                    x=[1],
                    y=[2.5],
                    name='Channel 1',
                    marker=dict(
                        color='rgb(26, 118, 255)'
                    )
                )
            ],
            layout=dict(
                title='Sensor Readings',
                showlegend=True,
                legend=dict(
                    x=0,
                    y=1.0
                ),
                margin=dict(l=40, r=0, t=40, b=30)
            )
        )

    return figure

@app.callback(Output('device-pic', 'src'),
              Input('label-device-type', 'value'))
def update_label_device_picture(value):
    if value == 'toast':
        return app.get_asset_url("Toast.svg")
    else:
        return app.get_asset_url("Basestation.svg")


@app.callback([Output('label-connect-body', 'style'),
               Output('label-label-bacon', 'style'),
               Output('label-label-toast', 'style')],
              Input('interval-component', 'n_intervals'),
              State('label-device-type', 'value'),
              State('port-dropdown', 'value')
              )
def update_label_setup_bacon_toast(n_intervals, device_type, port):
    hide = {'display': 'none', 'margin-top': '0vh', 'margin-left': '0vh'}
    flex = {'display': 'flex', 'margin-top': '0vh', 'margin-left': '0vh'}
    block = {'display': 'block', 'margin-top': '0vh', 'margin-left': '0vh'}
    # if port and handler.autoToastDone:
    if port:
        # handler.autoToastDone=False
        if device_type == 'bacon':
            return hide, block, hide
        elif device_type == "toast":
            return hide, hide, flex
        else:
            return flex, hide, hide
    else:
        return flex, hide, hide


@app.callback(Output('connect-status-box', 'children'), Input('connect-for-label', 'n_clicks'),
              [State('label-device-type', 'value'),
               State('port-dropdown', 'value')])
def check_install_firmware(n_click, device_type, port):
    if port:
        handler.connect(port)
        if handler.programming:
            return "Reinstalling firmware, please wait..."


def connectSignal(connected):
    if connected:
        mfrStr = "Not available"
        try:
            mfrStr = handler.getMfrID()
        except Exception:
            mfrVar = "Connection error"
            handler.programToaster()


@app.callback(Output('bacon-warning-box', 'children'),
              Input('bacon-label-button', 'n_clicks'),
              State('bacon-id-input-box', 'value'))
def set_bacon_barcode(n_clicks, new_barcode):
    if n_clicks > 0:
        try:
            handler.setBaconBarcode(new_barcode)
        except ValueError:
            return "Not an integer"
        except TypeError:
            # TODO: check whether there is a type error all the time.
            return "Incorrect type"
        except:
            return "Update failed"
        else:
            handler.databaseBacon()
            return ""


@app.callback([Output("bacon-barcode-box", "children"),
               Output("bacon-mfr-box", "children")],
              Input("bacon-status-check-interval", "n_intervals"))
def update_bacon_mfr_barcode(n_intervals):
    if n_intervals > 0:
        mfrStr = ""
        barcode_str = ""
        try:
            mfrStr = handler.getMfrID()
        except Exception:
            mfrStr = "Mfr ID: Connection Error"

        try:
            barcode_str = handler.getBaconBarcode()
        except TagNotFoundError:
            barcode_str = "Current Bacon ID: barcode not set"
            return mfrStr, barcode_str
        except:
            barcode_str = "Current Bacon ID: connection error"
            return mfrStr, barcode_str
        else:
            return mfrStr, barcode_str
    else:
        mfrStr = "Mfr ID: connection error"
        barcode_str = "Current Bacon ID: connection error"
        return mfrStr, barcode_str


@app.callback(Output('sensor-table-container', 'children'),
              Input('bacon-status-check-interval', 'n_intervals'))
def sensor_assignment_table(data):
    df = DataFrame({"Channels": ["Channel {}".format(i + 1) for i in range(8)],
                    "Type": ["N/A"] * 8,
                    "ID": ["N/A"] * 8,
                    "Barcode": ["N/A"] * 8})
    return dash_table.DataTable(
        id="sensor-assignment-table",
        columns=[{"name": i, "id": i} for i in df.columns],
        data=df.to_dict('records'),
        style_cell={'fontSize': 15, 'font-family': 'sans-serif', 'padding': '2px'},
        style_as_list_view=True,
        style_header={
            'backgroundColor': 'white',
            'fontWeight': 'bold'
        },
        editable=True
    )
