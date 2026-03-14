#!/usr/bin/env python3
"""Simple HTTP server for reviewing SVG artworks."""
import http.server
import os
import sys

PORT = 8765
DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

os.chdir(DIRECTORY)
handler = http.server.SimpleHTTPRequestHandler
httpd = http.server.HTTPServer(("", PORT), handler)
print(f"Serving {DIRECTORY} on http://localhost:{PORT}")
sys.stdout.flush()
httpd.serve_forever()
