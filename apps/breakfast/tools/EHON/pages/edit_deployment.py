import dash_core_components as dcc
import dash_html_components as html
from datetime import date as dt
layout=html.Div(children=[
        html.Div(children=[
            html.Div("", style={'display' : "none"}, id="hidden-element"),
            html.H4("Deployment Info", style={'margin-top': '7vh', 'margin-left': '2vw'}),
            html.H6("Deployment Name", style={'margin-top': '6vh', 'margin-left': '2vw'}),
            dcc.Input(id="deployment-name", style={'margin-top': '0.5vh', 'margin-left': '2vw', 'width': '25vw'}),
            html.H6("Setup Date", style={'margin-top': '5vh', 'margin-left': '2vw'}),
            dcc.DatePickerSingle(
                id='my-date-picker-single',
                min_date_allowed=dt(2000, 1, 1),
                max_date_allowed=dt(2099, 12, 31),
                initial_visible_month=dt.today(),
                date=str(dt.today()),
                style={'margin-left': '2vw', 'width': '25vw'}
            ),
            html.H6("Download Interval", style={'margin-top': '5vh', 'margin-left': '2vw'}),

            html.Div(
                dcc.Dropdown(id='download-interval-dropdown',
                             options=[{"label": "Every " + str(i + 1) + " weeks", "value": (i + 1) * 7} for i in
                                      range(12)],
                             value=14,
                             style={'margin-top': '0vh', 'width': '25vw'}),
                style={'margin-left': '2vw'}
            ),

            html.H6("Active", style={'margin-top': '5vh', 'margin-left': '2vw'}),

            html.Img(id='deployment-on-off-button', n_clicks=0, style={'margin-left': '2vw'})
        ],
            id='edit-left-column',
            style={'flex': '33vw',
                   'border-top': '0.5px solid',
                   'border-right': '0.5px solid',
                   'height': '89vh'}),
        html.Div(children=[
            html.H4("Manage Deployment", style={'margin-top': '7vh', 'margin-left': '2vw'}),
            html.Table(
                [html.Thead(
                    html.Tr([html.Th("Bacon ID"), html.Th("No. Toast"), html.Th("No. Sensor")])
                ),
                    html.Tbody()
                ],

                style={'margin-left': '1vw', 'margin-top': '1vh'},
                id='deployment-detail-table'
            )
        ],
            id='edit-mid-column',
            style={'flex': '33vw',
                   'border-top': '0.5px solid',
                   'border-right': '0.5px solid',
                   'height': '89vh'}),
        html.Div(children=[
            html.H4("Edit Unit", style={'margin-top': '7vh', 'margin-left': '2vw'}),
            html.Div(id="sensor-table"),
            # html.H6("Node ID", style={'margin-top': '5vh', 'margin-left': '2vw'}),
            # dcc.Input(id="node-id", style={'margin-top': '0.5vh', 'margin-left': '2vw', 'width': '25vw'}),
            # html.H6("GPS coordinates (decimal)", style={'margin-top': '5vh', 'margin-left': '2vw'}),
            # html.Div([html.H6("x:", style={'display': 'inline', 'margin-left': '2vw'}),
            #          dcc.Input(id="deployment-x-coordinate",
            #                    style={'margin-top': '0.5vh', 'margin-left': '2vw', 'width': '22vw',
            #                           'display': 'inline'})]),
            # html.Div([html.H6("y:", style={'display': 'inline', 'margin-left': '2vw'}),
            #          dcc.Input(id="deployment-y-coordinate",
            #                    style={'margin-top': '0.5vh', 'margin-left': '2vw', 'width': '22vw',
            #                           'display': 'inline'})]),
            # html.Div([html.Table(
            #     [html.Thead(
            #        html.Tr([html.Th("ID"), html.Th("Type"), html.Th("Toast ID"), html.Th("Deployment Note")])
            #    ),
            #        html.Tbody()
            #    ],
            #
            #    style={'margin-left': '2vw', 'margin-top': '5vh'}
            # )], id='unit-detail-table'),

            html.Button('Save Settings', id='save-settings-button', n_clicks=0, style={'margin-top':'25vh', 'margin-left': '5vw'}),

            html.A(html.Button('Discard Change', id='discard-settings-button', n_clicks=0, style={'margin-top':'25vh', 'margin-left': '0vw'}), href="/deploy_select_port_and_deployment")
        ],
            id='edit-right-column',
            style={'flex': '33vw',
                   'border-top': '0.5px solid',
                   'height': '89vh'}),

    ],
        id='create-or-edit-deployment',
        style={'margin-top': '0vh',
               'margin-left': '0vh',
               'display': 'none'})