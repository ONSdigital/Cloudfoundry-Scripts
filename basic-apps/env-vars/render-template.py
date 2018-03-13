import sys, os, json, re
from flask import Flask, render_template


app = Flask(__name__)

@app.route("/")
def main():
	return render_template('environ.html',vars=sorted(os.environ.items()), json=json, re=re)

if __name__ == "__main__":
	app.run(host='0.0.0.0', port=int(os.environ.get('PORT','8080')))

