import dash_core_components as dcc
import dash_html_components as html
layout=html.Div(children=[
        html.Div(children=[
            html.Div(
                id='deployment-info-box',
                children=[html.H3("Placeholder Deployment",
                                  style={'margin-top': '1.5vh',
                                         'margin-left': '9vw'},
                                  id='download-deployment-name'
                                  )
                          # html.H6("Last Download: 08/08/2020 6:04 PM", style={'margin-left: 9vw'})
                          ],
                style={'height': '6vh',
                       'border-bottom': '0.5px solid'}
            ),

            html.H5("Downloading Data..."),
            html.Div("Total Progress:", className='progress-text'),
            html.Div(html.Div(className='progress-inner'),
                     className='progress-boundary'),
            html.Div("Node 113 Progress:", className='progress-text'),
            html.Div(html.Div(className='progress-inner'),
                     className='progress-boundary'),

            html.Div(
                html.Button("Stop Download", style={'margin-top': '2vh',
                                                    'margin-right': '4vw',
                                                    'float': 'right',
                                                    'display': 'block'})
            ),
            html.Div(children=[
                html.Div("Successfully downloaded from 49/50 nodes.", className='success-msg'),
                html.Div("Download was incomplete in 1/50 nodes.", className='incomplete-msg'),
                html.Div("Battery critically low in 2 nodes", className='battery-msg'),
                html.Div("Failed to download from 1/50 nodes", className='failure-msg')
            ], style={'margin-top': '10vh'}),

            html.Div(
                html.H6("Legacy View"),
                style={'margin-top': '5vh'}
            ),

            html.Div(children="Lorem ipsum dolor sit amet, consectetur adipiscing elit,"
                              " sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
                              " Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris "
                              "nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit "
                              "in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat "
                              "cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
                              "Lorem ipsum dolor sit amet, consectetur adipiscing elit,"
                              " sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
                              " Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris "
                              "nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit "
                              "in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat "
                     , style={'overflow': 'auto',
                            'background-color': '#CDC7C7',
                            'width': '90%', 'height': '20%',
                            'margin-top': '2vh'})

        ],
            id='download-left-column',
            style={'flex': '40vw',
                   'border-top': '0.5px solid',
                   'border-right': '0.5px solid',
                   'height': '89vh'}),
        html.Div(children=[
            html.Div([
                html.Div(
                    children = [
                        html.Div(children=[html.Div("Node {}".format(i + 6 * j),
                                                    id="node-name-{}".format(i + 6 * j), className="node-name"),
                                           html.Div("Battery 3.7V", id="node-bt-{}".format(i + 6 * j), className='battery-string'),
                                           html.Div("Last Contact", id="lc-string", className="lc-string"),
                                           html.Div("08/20/20\n 18:04", id="node-lc-{}".format(i), className="time-string")],
                                 id="node-{}".format(i + 6 * j),
                                 className="download-node-box") for i in range(6)
                    ],
                    id='download-grid-row-{}'.format(j)
                ) for j in range(5)
            ],
                className="download-grid"
            ),

           html.Div([
               html.Button("Download", style={"display": "inline-block"}),
               html.Button("Cancel", style={"display": "inline-block", "background-color": "grey"})
           ],  style={"float": "right", 'margin-top': '3%'}),
        ],
                 id='download-right-column',
                 style={'flex': '60vw',
                        'border-top': '0.5px solid',
                        'height': '89vh'})
    ], style={
        'display': 'flex',
        'margin-top': '0vh',
        'margin-left': '0vh',
        'display': 'none'},
        id='download-page')