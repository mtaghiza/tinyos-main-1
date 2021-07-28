import dash_core_components as dcc
import dash_html_components as html
from app import app
layout = html.Div(children=[
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
    ], style={'height': '10vh', 'overflow': 'hidden'})),

    html.Hr(style={'margin-top': '1vh'}),

    html.Div(
        children=
        [dcc.Link(html.Img(id='Devices', src=app.get_asset_url('Devices.svg'), style={'margin-left': '16vw', 'height': '35vh', 'margin-top':'10vh'
        }), href=""),
         dcc.Link(html.Img(id='Program', src=app.get_asset_url('Program.svg'), style={'margin-left': '5vw', 'height': '35vh','margin-top':'10vh'
        }), href="/program"),
         dcc.Link(html.Img(id='Barcode', src=app.get_asset_url('Barcode.svg'), style={'margin-left': '5vw', 'height': '35vh', 'margin-top':'10vh'
        }), href="/label_label")]
    ),
])




