import dash_core_components as dcc
import dash_html_components as html

deploy_select_port=html.Div([html.Div(children=[
        html.H5("Select Deployment",
                style={'margin-top': '7vh', 'margin-left': '2vw'}),
        html.Div(
            dcc.Dropdown(id='select-deployment-dropdown',
                         value='',
                         style={'width': '25vw'},
                         placeholder='Select deployment...'),
            style={'margin-left': '2vw'}),

        html.H5("Selected Deployment Info",
                style={'margin-top': '7vh', 'margin-left': '2vw'}),

        html.Table(id='deployment-preview-table', style={'margin-left': '2vw'}),
        html.Button('Edit Selected Deployment',
                    n_clicks=0,
                    id='edit-selected-deployment',
                    style={'margin-top': '6vh'}),
        html.Button('Create new Deployment',
                    n_clicks=0,
                    id='create-selected-deployment',
                    style={'margin-left': '1vw'})
    ], id='select-deployment-box',
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
                    id='port-dropdown',
                    style={'width': '40vw'},
                    placeholder='Select port...'
                ), style={'margin-left': '18vh'}),

            html.Button(id='connect-button',
                        children="Connect",
                        n_clicks=0,
                        style={'color': 'white',
                               'margin-top': '15vh',
                               'margin-left': ' 41.5vw',
                               'background-color': '#2185D0',
                               'display': 'inline'}),
            dcc.Link(html.Button(id='quit',
                                 children="Cancel",
                                 n_clicks=0,
                                 style={'color': '#414141',
                                        'margin-top': '15vh',
                                        'margin-left': ' 1vw',
                                        'display': 'inline',
                                        'background-color': '#E0E1E2'}), href='/deploy_start'),

            dcc.Interval(
                id='interval-component',
                interval=1 * 1000,
                n_intervals=0)

        ], id='select-port-box',
            style={'flex': '64vw',
                   'border-top': '0.5px solid',
                   'height': '89vh'})
    ],
        id='deploy-select-port-and-deployment-content',
        style={'display': 'flex',
               'margin-top': '0vh',
               'margin-left': '0vh'})