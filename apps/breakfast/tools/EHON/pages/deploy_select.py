import dash
import dash_table
import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output, State
from tools.serial.tools.list_ports import comports
from app import app
from datetime import date as dt
import select_port
import edit_deployment
import download_page
import sqlite3
import database
from datetime import datetime, timedelta
from pandas import DataFrame

deploy_top_disabled = [
    html.Img(id='JHU_Logo',
             src=app.get_asset_url('JHU-Logo1.svg'),
             style={'float': 'left', 'margin-top': '1vh', 'height': '7vh'}),
    html.Img(id='Label',
             src=app.get_asset_url('Label-Logo-Gray.svg'),
             style={'margin-left': '5vw', 'height': '10vh'}),
    html.Img(id='Deploy',
             src=app.get_asset_url('Deploy-Logo-Blue.svg'),
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

layout = html.Div([
    html.Div(id='top-section',
             children=html.Div(id='Logos',
                               children=deploy_top_disabled,
                               style={'height': '10vh',
                                      'overflow': 'hidden'})
             ),

    dcc.ConfirmDialog(
        id='delete-node-confirm',
        message='Danger danger! Are you sure you want to continue?',
    ),

    # html.Hr(style={'margin-top': '1vh', 'margin-bottom': '0vh'}),
    select_port.deploy_select_port,

    edit_deployment.layout,

    download_page.layout,

    html.Div(style={'display': 'none'}, id='deployment-storage'),
], id="top")

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


# Place holder function for illustrative purpose only. Will need to ad
# just link to database later on.
def get_deployment_names():
    conn = sqlite3.connect("./ehon.db")
    names = database.get_deployment_name_and_id(conn)
    conn.close()
    return names


def get_deployment_info_by_id(id):
    conn = sqlite3.connect("./ehon.db")
    info = database.get_deployment_info_by_id(conn, id)
    conn.close()
    return info


def get_no_motes_by_deployment(id):
    conn = sqlite3.connect("./ehon.db")
    no_motes = database.get_no_motes_by_deployment(conn, id)
    conn.close()
    return no_motes


def get_no_sensors_by_deployment(id):
    conn = sqlite3.connect("./ehon.db")
    no_sensors = database.get_no_sensors_by_deployment(conn, id)
    conn.close()
    return no_sensors


def get_node_information_by_deployment(id):
    conn = sqlite3.connect("./ehon.db")
    info = database.get_node_information_by_deployment(conn, id)
    # print(info)
    conn.close()
    return info


def generate_table(did, set_up_date, download_interval, last_download):
    setup = datetime.fromtimestamp(set_up_date).strftime("%Y-%m-%d")
    last = datetime.fromtimestamp(last_download).strftime("%Y-%m-%d")
    next = (datetime.fromtimestamp(last_download) + timedelta(days=download_interval)).strftime("%Y-%m-%d")
    no_motes = get_no_motes_by_deployment(did)
    no_sensors = get_no_sensors_by_deployment(did)
    # print(no_sensors)
    return [html.Thead(
        html.Tr([html.Th("Field"), html.Th("Value")])
    ),
        html.Tbody([
            html.Tr([html.Td("Initial Deployment"), html.Td(setup)]),
            html.Tr([html.Td("Last Download"), html.Td(last)]),
            html.Tr([html.Td("Next Download"), html.Td(next)]),
            html.Tr([html.Td("No. Motes"), html.Td(no_motes)]),
            html.Tr([html.Td("No. Sensors"), html.Td(no_sensors)]),
        ], id='table-entries')
    ]


@app.callback(Output('select-deployment-dropdown', 'options'),
              [Input('select-deployment-dropdown', 'value'),
               Input('port-dropdown', 'value')])
def update_select_deployment_dropdown(selection, port):
    return [{'label': i[0], 'value': i[1]} for i in get_deployment_names()]


@app.callback(Output('deployment-preview-table', 'children'),
              Input('select-deployment-dropdown', 'value'))
def update_select_deployment_dropdown(selection):
    if selection:
        deployment_id, name, set_up_date, download_interval, last_download, db, active \
            = get_deployment_info_by_id(selection)
        return generate_table(deployment_id, set_up_date, download_interval, last_download)
    else:
        return None


@app.callback([Output('deploy-select-port-and-deployment-content', 'style'),
               Output('create-or-edit-deployment', 'style'),
               Output('download-page', 'style'),
               Output('deployment-storage', 'children')],
              [Input('connect-button', 'n_clicks'),
               Input('edit-selected-deployment', 'n_clicks'),
               Input('create-selected-deployment', 'n_clicks')],
              State('select-deployment-dropdown', 'value'))
def change_view(connect_button, edit_button, create_button, selection):
    ctx = dash.callback_context
    if connect_button == 0 and edit_button == 0 and create_button == 0:
        return {'margin-top': '0vh',
                'margin-left': '0vh',
                'display': 'flex'}, \
               {'margin-top': '0vh',
                'margin-left': '0vh',
                'display': 'none'}, \
               {'margin-top': '0vh',
                'margin-left': '0vh',
                'display': 'none'}, \
               None
    elif ctx.triggered[0]['prop_id'].split('.')[0] == 'edit-selected-deployment':
        return {'margin-top': '0vh',
                'margin-left': '0vh',
                'display': 'none'}, \
               {'margin-top': '0vh',
                'margin-left': '0vh',
                'display': 'flex'}, \
               {'margin-top': '0vh',
                'margin-left': '0vh',
                'display': 'none'}, \
               selection
    elif ctx.triggered[0]['prop_id'].split('.')[0] == 'connect-button':
        # print("download??")
        return {'margin-top': '0vh',
                'margin-left': '0vh',
                'display': 'none'}, \
               {'margin-top': '0vh',
                'margin-left': '0vh',
                'display': 'none'}, \
               {'margin-top': '0vh',
                'margin-left': '0vh',
                'display': 'flex'}, \
               None


@app.callback([Output('deployment-name', 'value'),
               Output('my-date-picker-single', 'date'),
               Output('download-interval-dropdown', 'value'),
               Output('deployment-on-off-button', 'n_clicks')
               ],
              [Input('deployment-storage', 'children')])
def fill_in_deployment_info(selection):
    if selection:
        deployment_id, name, set_up_date, download_interval, last_download, db, active \
            = get_deployment_info_by_id(selection)
        return name, datetime.fromtimestamp(set_up_date).strftime("%Y-%m-%d"), download_interval, active
    else:
        return None, None, None, 0


def output_deploy_table(selection):
    df = DataFrame(get_node_information_by_deployment(selection), columns=["Bacon Id", "No. Toast", "No. Sensor"])
    return dash_table.DataTable(
        id="datatable-interactivity",
        columns=[{"name": i, "id": i} for i in df.columns],
        data=df.to_dict('records'),
        style_cell={'fontSize': 15, 'font-family': 'sans-serif', 'width': '200%', 'padding': '10px'},
        style_as_list_view=True,
        style_header={
            'backgroundColor': 'white',
            'fontWeight': 'bold'
        },
        row_selectable="single",
        row_deletable=True,
    )


def output_sensor_table(node_id):
    print(node_id)
    df = DataFrame(get_sensor_info_by_node_id(int(node_id)),
                   columns=["Toast ID", "Sensor ID", "Sensor Type", "Active", "Depth", "X Coordinate", "Y Coordinate"])
    return dash_table.DataTable(
        id="datatable-sensor",
        columns=[{"name": i, "id": i} for i in df.columns],
        data=df.to_dict('records'),
        style_cell={'fontSize': 15, 'font-family': 'sans-serif', 'width': '200%', 'padding': '10px'},
        style_as_list_view=True,
        style_header={
            'backgroundColor': 'white',
            'fontWeight': 'bold'
        },
        editable=True,
        row_selectable="single",
        row_deletable=True)


def get_sensor_info_by_node_id(node_id):
    conn = sqlite3.connect("./ehon.db")
    info = database.get_sensor_info_by_node_id(conn, node_id)
    conn.close()
    return info


@app.callback([Output('deployment-detail-table', 'children')],
              [Input('deployment-storage', 'children')])
def update_deploy_detail_table_body(selection):
    return ([output_deploy_table(selection), dcc.Dropdown(), html.Button("Add Bacon", id="add-bacon-button")],)


@app.callback([Output('datatable-interactivity', 'style_data_conditional'),
               Output('sensor-table', 'children')],
              [Input('datatable-interactivity', "selected_rows"),
               Input('datatable-interactivity', "derived_virtual_data")])
def update_graphs(selected_rows, data):
    if selected_rows is None:
        selected_rows = []
        return [], None
    else:
        node_id = data[selected_rows[0]]['Bacon Id']
        return [{'if': {'row_index': i}, 'background_color': '#D2F3FF'} for i in selected_rows], \
               [output_sensor_table(node_id), dcc.Dropdown(id="add-toast-dropdown"), html.Button('Add Toast', id='editing-rows-button', n_clicks=0)]


@app.callback([Output('delete-node-confirm', 'displayed'),
               Output('delete-node-confirm', 'message'),
               Output('hidden-element', "children")],
              [Input('datatable-interactivity', 'data_previous')],
              [State('datatable-interactivity', 'data')])
def delete_node_alert(previous, current):
    if previous is None:
        dash.exceptions.PreventUpdate()
        return False, "", None
    else:
        deleted_id = [e for e in previous if e not in current][0]["Bacon Id"]
        return True, "Deleting a node from the deployment metadata. " \
                     "The operation CANNOT be reverted. Click OK to permanently delete." \
                     " Otherwise, click CANCEL and refresh page.", str(deleted_id)


@app.callback(Output('delete-node-confirm', 'displayed'),
              Input('delete-node-confirm', 'submit_n_clicks'),
              State("hidden-element", "children"))
def delete_node(submit_n_clicks, node_id):
    if submit_n_clicks:
        conn = sqlite3.connect("./ehon.db")
        database.recursive_delete_by_node_id(conn, int(node_id))
        conn.close()
        return False


@app.callback(
    Output('datatable-sensor', 'data'),
    Input('editing-rows-button', 'n_clicks'),
    State('datatable-sensor', 'data'),
    State('datatable-sensor', 'columns'))
def add_row(n_clicks, rows, columns):
    if n_clicks > 0:
        rows.append({c['id']: '' for c in columns})
    return rows
