import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output

from app import app

layout = html.Div([
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