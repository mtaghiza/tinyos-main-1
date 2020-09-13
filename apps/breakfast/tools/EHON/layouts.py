import dash_core_components as dcc
import dash_html_components as html
from app import app
from datetime import date as dt

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

deploy_start_layout = html.Div([
    html.Div(id='top-section', children=html.Div(id='Logos', children=[
        html.Img(id='JHU_Logo',
                 src=app.get_asset_url('JHU-Logo1.svg'),
                 style={'float': 'left', 'margin-top': '1vh', 'height': '7vh'}),
        dcc.Link(html.Img(id='Label',
                          src=app.get_asset_url('Label-Logo.svg'),
                          style={'margin-left': '5vw', 'height': '10vh'}), href='/label_start'),
        dcc.Link(html.Img(id='Deploy',
                          src=app.get_asset_url('Deploy-Logo-Blue.svg'),
                          style={'margin-left': '10vw', 'height': '10vh'}), href='/deploy_start'),
        dcc.Link(html.Img(id='Data',
                          src=app.get_asset_url('Data-Logo.svg'),
                          style={'margin-left': '10vw', 'height': '10vh'}), href='/data_start'),
        dcc.Link(html.Img(id='Share',
                          src=app.get_asset_url('Share-Logo.svg'),
                          style={'margin-left': '10vw', 'height': '10vh'}), href='/share_start'),
        html.Img(id='EHON1',
                 src=app.get_asset_url('EHON-Logo.svg'),
                 style={'margin-left': '0vw', 'height': '4vh',
                        'width': '36vh', 'float': 'right', 'margin-top': '3vh', 'margin-right': '3vw'})
    ], style={'height': '10vh', 'overflow': 'hidden'})
             ),

    html.Hr(style={'margin-top': '1vh'}),

    html.H3("Insert Basestation", style={'margin-left': '10vh'}),

    html.Img(id='basestation_pic',
             src=app.get_asset_url("Basestation.svg"), style={'height': "50vh",
                                                              'margin-left': '27vw',
                                                              'margin-top': '7vh',
                                                              'border': 'solid',
                                                              'border-width': '0.5px'
                                                              }),

    dcc.Link(html.Button(id='deploy_start_continue',
                         children="Continue",
                         style={'color': 'white',
                                'background-color': '#2185D0',
                                'float': 'right',
                                'margin-top': '53vh',
                                'margin-right': '15vw'},
                         ),
             href='/deploy_select_port_and_deployment')
], id="top")

deploy_select_port_and_deployment_layout = html.Div([
    html.Div(id='top-section',
             children=html.Div(id='Logos',
                               children=deploy_top_disabled,
                               style={'height': '10vh',
                                      'overflow': 'hidden'})
             ),

    # html.Hr(style={'margin-top': '1vh', 'margin-bottom': '0vh'}),

    html.Div([html.Div(children=[
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

            html.Button(id='btn',
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
               'margin-left': '0vh'}),
    html.Div(children=[
        html.Div(children=[
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
                             options=[{"label": "Every " + str(i + 2) + " weeks", "value": (i + 2) * 7} for i in
                                      range(11)],
                             value=14,
                             style={'margin-top': '0vh', 'width': '25vw'}),
                style={'margin-left': '2vw'}
            ),
            html.H6("Channel Selection", style={'margin-top': '5vh', 'margin-left': '2vw'}),

            html.Div(
                dcc.Dropdown(id='channel-dropdown',
                             options=[{"label": "Channel " + str(i), "value": i} for i in
                                      range(128)],
                             value=0,
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
                    html.Tr([html.Th("Bacon Node ID"), html.Th("No. Toast"), html.Th("No. Sensors"), html.Th("Active")])
                ),
                    html.Tbody()
                ],

                style={'margin-left': '2vw', 'margin-top': '5vh'},
                id='deployment-detail-table'
            )
        ],
            id='edit-mid-column',
            style={'flex': '33vw',
                   'border-top': '0.5px solid',
                   'border-right': '0.5px solid',
                   'height': '89vh'}),
        html.Div(children=[],
                 id='edit-right-column',
                 style={'flex': '33vw',
                        'border-top': '0.5px solid',
                        'height': '89vh'})
    ],
        id='create-or-edit-deployment',
        style={'display': 'flex',
               'margin-top': '0vh',
               'margin-left': '0vh',
               'display': 'none'})
], id="top")

label_start_layout = html.Div([
    html.Div(id='top-section', children=html.Div(id='Logos', children=[
        html.Img(id='JHU_Logo',
                 src=app.get_asset_url('JHU-Logo1.svg'),
                 style={'float': 'left', 'margin-top': '1vh', 'height': '7vh'}),
        dcc.Link(html.Img(id='Label',
                          src=app.get_asset_url('Label-Logo-Blue.svg'),
                          style={'margin-left': '5vw', 'height': '10vh'}), href='/label_start'),
        dcc.Link(html.Img(id='Deploy',
                          src=app.get_asset_url('Deploy-Logo.svg'),
                          style={'margin-left': '10vw', 'height': '10vh'}), href='/deploy_start'),
        dcc.Link(html.Img(id='Data',
                          src=app.get_asset_url('Data-Logo.svg'),
                          style={'margin-left': '10vw', 'height': '10vh'}), href='/data_start'),
        dcc.Link(html.Img(id='Share',
                          src=app.get_asset_url('Share-Logo.svg'),
                          style={'margin-left': '10vw', 'height': '10vh'}), href='/share_start'),
        html.Img(id='EHON1',
                 src=app.get_asset_url('EHON-Logo.svg'),
                 style={'margin-left': '0vw', 'height': '4vh',
                        'width': '36vh', 'float': 'right', 'margin-top': '3vh', 'margin-right': '3vw'})
    ], style={'height': '10vh', 'overflow': 'hidden'})
             ),

    html.Hr(style={'margin-top': '1vh', 'background-color': 'red'})
], id="top")
