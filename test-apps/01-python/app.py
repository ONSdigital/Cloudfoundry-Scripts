#!/usr/bin/python

import os

from flask import Flask
app = Flask(__name__)

@app.route("/")
def main():
	return "<h1>Hello World from Python Flask courtesy of Cloudfoundry</h1>"

if __name__ == "__main__":
	app.run(host='0.0.0.0', port=os.getenv('PORT',8080))
