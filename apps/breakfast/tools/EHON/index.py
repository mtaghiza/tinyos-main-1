import dash_core_components as dcc
import dash_html_components as html
import dash
from dash.dependencies import Input, Output, State
from tools.serial.tools.list_ports import comports
from app import app
from layouts import label_start_layout, deploy_start_layout, deploy_select_port_and_deployment_layout

app.layout = html.Div([
    dcc.Location(id='url', refresh=False),
    html.Div(id='page-content')
])


@app.callback(Output('page-content', 'children'),
              [Input('url', 'pathname')])
def display_page(pathname):
    if pathname == '/label_start':
        return label_start_layout
    elif pathname == '/deploy_start':
        return deploy_start_layout
    elif pathname == '/deploy_select_port_and_deployment':
        return deploy_select_port_and_deployment_layout
    else:
        return deploy_start_layout


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


def generate_table(deployment_name):
    return [html.Thead(
        html.Tr([html.Th("Field"), html.Th("Value")])
    ),
        html.Tbody([
            html.Tr([html.Td("Initial Deployment"), html.Td("2014-03-21")]),
            html.Tr([html.Td("Last Download"), html.Td("2020-08-10")]),
            html.Tr([html.Td("Next Download"), html.Td("2020-08-28")]),
            html.Tr([html.Td("No. Motes"), html.Td("23")]),
            html.Tr([html.Td("No. Sensors"), html.Td("94")]),
        ])
    ]


@app.callback([Output('select-deployment-dropdown', 'options'),
               Output('deployment-preview-table', 'children')],
              [Input('select-deployment-dropdown', 'value')])
def update_select_deployment_dropdown(selection):
    # print("test")
    return [{'label': i, 'value': i} for i in get_deployment_names()], generate_table(selection)


@app.callback([Output('deploy-select-port-and-deployment-content', 'style'),
               Output('create-or-edit-deployment', 'style')],
              [Input('edit-selected-deployment', 'n_clicks'), Input('create-selected-deployment', 'n_clicks')],
              [State('select-deployment-dropdown', 'value')])
def go_to_edit_deployment_page(edit_click, create_click, selected_deployment):
    if edit_click == 0 and create_click == 0:
        return {'display': 'flex', 'margin-top': '0vh', 'margin-left': '0vh'}, \
               {'display': 'flex', 'margin-top': '0vh', 'margin-left': '0vh', 'display': 'none'}
    else:
        changed_id = [p['prop_id'] for p in dash.callback_context.triggered][0]
        if 'edit-selected-deployment' in changed_id:
            return {'display': 'flex',
                    'margin-top': '0vh',
                    'margin-left': '0vh',
                    'display': 'none'}, \
                   {'display': 'flex',
                    'margin-top': '0vh',
                    'margin-left': '0vh',
                    'display': 'flex'}
        else:
            return {'display': 'flex',
                    'margin-top': '0vh',
                    'margin-left': '0vh',
                    'display': 'none'}, \
                   {'display': 'flex',
                    'margin-top': '0vh',
                    'margin-left': '0vh',
                    'display': 'flex'}

@app.callback(Output('deployment-on-off-button', 'src'),
              [Input('deployment-on-off-button', 'n_clicks')])
def deployment_on_off_button_update(n_clicks):
    if n_clicks % 2 == 0:
        return app.get_asset_url("On_Button.svg")
    else:
        return app.get_asset_url("Off_Button.svg")

if __name__ == '__main__':
    app.run_server(debug=True)
