import dash_core_components as dcc
import dash_html_components as html
from app import app

deploy_top_disabled=[
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

deploy_start_layout=html.Div([
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

    html.Button(id='deploy_start_continue', children="Continue", n_clicks=0, style={'color': 'white', 'background-color': 'blue'})
], id="top")


deploy_select_port_and_deployment_layout=html.Div([
    html.Div(id='top-section', children=html.Div(id='Logos', children=deploy_top_disabled, style={'height': '10vh', 'overflow': 'hidden'})
             ),

    html.Hr(style={'margin-top': '1vh', 'background-color': 'red'}),

    dcc.Dropdown(
        id='port-dropdown'
    ),

    html.Button(id='btn',
            children="Download",
            n_clicks=0,
            style={'color': 'blue', 'background-color': 'white'}),

    dcc.Interval(
        id='interval-component',
        interval=1 * 1000,
        n_intervals=0)
], id="top")


label_start_layout=html.Div([
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

    html.Hr(style={'margin-top': '1vh', 'background-color': 'red'})
    ], id="top")