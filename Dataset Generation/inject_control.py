from flask import Flask, request
import os, random
app = Flask(__name__)

@app.route('/get_results')
def get_results():
    file = open('transcript.txt', 'r')
    lines = file.readlines()
    file.close()

    data = ""
    for line in lines:
        if len(line) < 500:
            data = data+line

    return data

@app.route('/specify_order/<pids>')
def specify_order(pids):
    file = open("automigrate.rc", 'w')
    file.write("getsystem\n")
    p = pids.split(",")
    #random.shuffle(p)
    for pid in p:
        file.write("migrate "+pid+"\n")
    file.write("quit")
    file.close()
    return "OK"

@app.route('/still_injecting')
def still_injecting():
    file = open("transcript.txt", 'r')
    data =file.readlines()
    file.close()

    q = "resource (automigrate.rc)> quit"

    if len(data) > 2 and (q in data[-1] or q in data[-2] or q in data[-3]):
        return "{'status': 'complete'}"

    return "{'status': 'incomplete'}"

@app.route('/reset_transcript')
def reset_transcript():
    file = open("transcript.txt", 'r')
    data =file.read()
    file.close()

    os.system("echo > transcript.txt")

    return data

app.run('0.0.0.0', port=8000)
