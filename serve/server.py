import http.server
import socketserver
import os

PORT = 8080
DIR = os.path.dirname(os.path.abspath(__file__))

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIR, **kwargs)

with socketserver.ThreadingTCPServer(("", PORT), Handler) as httpd:
    print(f"Serving {DIR} on port {PORT}")
    httpd.serve_forever()
