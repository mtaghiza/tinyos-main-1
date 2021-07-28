import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output

import dash
from dash.dependencies import Input, Output
from app import app
from pages import label_start, deploy_start, deploy_select, label_program, label_label

app.layout = html.Div([
    dcc.Location(id='url', refresh=False),
    html.Div(id='page-content')
])


@app.callback(Output('page-content', 'children'),
              [Input('url', 'pathname')])
def display_page(pathname):
    if pathname == '/label_start':
        return label_start.layout
    elif pathname == '/deploy_start':
        return deploy_start.layout
    elif pathname == '/deploy_select_port_and_deployment':
        return deploy_select.layout
    elif pathname == '/program':
        return label_program.layout
    elif pathname == '/label_label':
        return label_label.layout
    else:
        return deploy_start.layout


if __name__ == '__main__':
    app.run_server(debug=True)
