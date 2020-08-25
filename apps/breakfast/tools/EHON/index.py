import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output
from app import app
from layouts import deploy_start_layout, label_start_layout
import callbacks

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
    else:
        return '404'

if __name__ == '__main__':
    app.run_server(debug=True)
