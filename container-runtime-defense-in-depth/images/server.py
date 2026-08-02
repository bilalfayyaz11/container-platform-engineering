from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps(
            {
                "status": "healthy",
                "service": "container-security-runtime",
                "uid": os.getuid(),
                "gid": os.getgid(),
            }
        ).encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        return


HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
