import openai
from openai.error import InvalidRequestError
import json
from pythonosc import udp_client, dispatcher, osc_server
import os
import subprocess
from flask import Flask, render_template, request, redirect, url_for, send_file, jsonify
from dotenv import load_dotenv
# from flask_scss import Scss
import threading
from database import *
import webbrowser
from chatGPT import chatGPT

load_dotenv() 

# Define openAPI key
api_key = os.getenv("API_KEY")
openai.api_key = api_key

with open("server-config.json", "r") as file:
    server_config = json.load(file)

# Set the IP address and port of the OSC server
ip_address = server_config["ip_address"]
server_port = server_config["ports"]["server"]
pde_port = server_config["ports"]["server_to_pde"]
transcript_port_client = server_config["ports"]["server_to_transcript"]
transcript_port_server = server_config["ports"]["transcript_to_server"]

# Create database
# createDB()

# Load config
res = getDBConfig(True)
gpt_role = res["gpt_role"]
gpt_context = res["gpt_context"]
gpt_action = res["gpt_action"]
gpt_temp = res["gpt_temp"]

res = getDBTransConfig()
transcription_silence = res["transcription_silence"]
transcription_restart = res["transcription_restart"]
language = res["language"]
talk = res["talk"]
model = res["model"]

resetDBModes()

gpt = chatGPT(ip_address,transcript_port_client)
gpt.appendHistory({"role": "system", "content": gpt_role})
gpt.appendHistory({"role": "system", "content": gpt_context})
gpt.appendHistory({"role": "system", "content": gpt_action})

# Create an OSC client
client = udp_client.SimpleUDPClient(ip_address, pde_port)

osc_address = "/status/"
osc_message = 'listening'
client.send_message(osc_address, osc_message)
gpt.sendStatusMessage(osc_message)

playing_mode = "play"

# Create the OSC server dispatcher and register the handler function

def speak(text, language='fr'):
    subprocess.run(["say", "-v", f"{language}", text])

def sendTranscriptionConfig():
    trans_config = getDBTransConfig()
    osc_address = "/config/"
    gpt.sendConfigMessage([
        trans_config["transcription_silence"], 
        trans_config["transcription_restart"],
        trans_config["language"]
    ])

def handle_get_config_message(address, *args):
    sendTranscriptionConfig()

def handle_speech_message(address, *args):
    
    global gpt

    if ( playing_mode == "pause" ):
        return

    transcription = str(args[0])
    gpt.setTranscription(transcription)
    started_on_processing = (bool(args[1]))

    if (transcription == "Stop"):
        gpt.setEndIt(True)
  
    elif (gpt.getStatus() == "waiting" and not started_on_processing and transcription != ''):
        osc_message = transcription.encode('utf-8')
        osc_address = "/prompt/"
        client.send_message(osc_address, osc_message)

def handle_stop_message(address, *args):

    global gpt
    if ( gpt.getStatus() == "processing"):
        gpt.setEndIt(True)
        osc_address = "/stopped/"
        gpt.sendStopMessage()

def handle_end_speech_message(address, *args):

    global gpt
    global playing_mode

    if ( playing_mode == "pause" ):
        return
    
    started_on_processing = (bool(args[0]))
    transcription = gpt.getTranscription()

    # Traitement du message OSC reçu
    if (gpt.getStatus() == "waiting" and not started_on_processing and transcription != ''):
        call_openai_gpt(transcription)
    
    gpt.clearTranscription()

    if ( gpt.getStatus() == "will_waiting"):
        gpt.setStatus("waiting")
        osc_address = "/status/"
        osc_message = 'listening'
        client.send_message(osc_address, osc_message)
        gpt.sendStatusMessage(osc_message)

def start_osc_server():

    # Création du dispatcher qui gère les messages OSC reçus
    dispatch = dispatcher.Dispatcher()
    dispatch.map("/speech/", handle_speech_message)    
    dispatch.map("/end-speech/", handle_end_speech_message)    
    dispatch.map("/stop/", handle_stop_message)    
    dispatch.map("/get-config/", handle_get_config_message)    

    # Création du serveur OSC
    server = osc_server.ThreadingOSCUDPServer((ip_address, transcript_port_server), dispatch)
    print("OSC server started on {}:{}".format(ip_address, transcript_port_server))

    # Démarrage du serveur OSC dans un thread dédié
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.start()

def start_parameter_loop():

    global gpt

    global playing_mode
    global gpt_role
    global gpt_context
    global gpt_action
    global gpt_temp
    global talk
    global language
    global model

    def run_job():

        global playing_mode

        while True:

            c_playing_mode = getDBPlayingMode()

            if ( playing_mode == "play" and c_playing_mode == "pause" ):
                gpt.setStatus("waiting")
                gpt.clearTranscription()
                gpt.setEndIt(False)
                osc_address = "/status/"
                osc_message = 'pause'
                client.send_message(osc_address, osc_message)
                gpt.sendStatusMessage(osc_message)
                playing_mode = c_playing_mode
                print("pause")

            if ( playing_mode == "pause" and c_playing_mode == "play" ):
                osc_address = "/status/"
                osc_message = 'listening'
                client.send_message(osc_address, osc_message)
                gpt.sendStatusMessage(osc_message)
                playing_mode = c_playing_mode

            # Check if config or history should be updated (changes from html form)
            res = getDBUpdate()
            if (res):
                gpt_role = res["gpt_role"]
                gpt_context = res["gpt_context"]
                gpt_action = res["gpt_action"]
                gpt_temp = res["gpt_temp"]
                gpt.appendHistory({"role": "system", "content": gpt_role})
                gpt.appendHistory({"role": "system", "content": gpt_context})
                gpt.appendHistory({"role": "system", "content": gpt_action})

            #check if reset history
            res = getDBReset()
            if (res == 1):
                gpt.resetHistory()
                gpt.appendHistory({"role": "system", "content": gpt_role})
                gpt.appendHistory({"role": "system", "content": gpt_context})
                gpt.appendHistory({"role": "system", "content": gpt_action})
                setDBReset(0)

            res = getDBTransConfig()
            if(res):
                talk = res["talk"]
                language = res["language"]
                model = res["model"]


    thread = threading.Thread(target=run_job)
    thread.start()


app = Flask(__name__)
app.debug = True # needed to scss to compile
# Scss(app, static_dir='static/css/', asset_dir='static/scss/')

def call_openai_gpt(prompt):

    global gpt
    if ( playing_mode == "pause" ):
        return
    if prompt == '' :
        return

    gpt.callOpenAI(prompt, openai, gpt_role, gpt_context, gpt_action, model, gpt_temp, language, playing_mode, talk, True, client)


@app.route('/config')
def config(model= None, talk = None, language=None, gpt_role=None, gpt_context=None, gpt_action=None, gpt_temp=None, transcription_silence=None, transcription_restart=None, playing_mode=None):

    params_set = model and talk and language and gpt_role and gpt_context and gpt_action and gpt_temp and transcription_silence and transcription_restart
    request_set =  request.args.get('model') and request.args.get('talk') and request.args.get('language') and request.args.get('gpt_role')  and request.args.get('gpt_context')  and request.args.get('gpt_action') and request.args.get('gpt_temp') and request.args.get('transcription_silence') and request.args.get('transcription_restart')
    
    if not (params_set) :
        if not (request_set) :
            res = getDBConfig()
            gpt_role = res["gpt_role"]
            gpt_context = res["gpt_context"]
            gpt_action = res["gpt_action"]
            gpt_temp = res["gpt_temp"]
            updated = res["updated"]
            res = getDBTransConfig()
            transcription_silence = res["transcription_silence"]
            transcription_restart = res["transcription_restart"]
            language = res["language"]
            talk = res["talk"]
            model = res["model"]
        else :
            gpt_role = request.args.get('gpt_role')
            gpt_context = request.args.get('gpt_context')
            gpt_action = request.args.get('gpt_action')
            gpt_temp = request.args.get('gpt_temp')
            transcription_silence = request.args.get('transcription_silence')
            transcription_restart = request.args.get('transcription_restart')
            language = request.args.get('language')
            talk = request.args.get('talk')
            model = request.args.get('model')
   
    if not (playing_mode) and not (request.args.get('playing_mode')):
        playing_mode = getDBPlayingMode()

    return render_template('index.html', 
        gpt_role=gpt_role, 
        gpt_context=gpt_context, 
        gpt_action=gpt_action, 
        gpt_temp=gpt_temp,
        updated=updated,
        transcription_silence=transcription_silence,
        transcription_restart=transcription_restart,
        language=language,
        talk=talk,
        model=model,
        playing_mode=playing_mode
    )

@app.route('/submit_form', methods=['POST'])
def submit_form():

    gpt_role = request.form['gpt_role']
    gpt_context = request.form['gpt_context']
    gpt_action = request.form['gpt_action']
    gpt_temp = float(request.form['gpt_temp'])
    transcription_silence = float(request.form['transcription_silence'])
    transcription_restart = float(request.form['transcription_restart'])
    language = request.form['language']
    talk = request.form['talk']
    model = request.form['model']
    updateDB(gpt_role, gpt_context, gpt_action, gpt_temp)
    updateTransDB(transcription_silence, transcription_restart, language, talk, model)
    sendTranscriptionConfig()

    return redirect(url_for("config"))

@app.route('/play', methods=['POST'])
def play():
    setDBPlayingMode("play")
    return redirect(url_for("config"))

@app.route('/pause', methods=['POST'])
def pause():
    setDBPlayingMode("pause")
    return redirect(url_for("config"))

@app.route('/reset', methods=['POST'])
def reset():
    setDBReset(1)
    return redirect(url_for("config"))


if __name__ == "__main__":
         
    if os.environ.get('WERKZEUG_RUN_MAIN') != 'true':
        start_osc_server()
        start_parameter_loop()

    sendTranscriptionConfig()
    webbrowser.open('http://'+ip_address+':'+str(server_port)+'/config')

    osc_address = "/status/"
    full_reply_content = 'listening'
    osc_message = full_reply_content
    client.send_message(osc_address, osc_message)
    app.run(debug=True, host="0.0.0.0", port=server_port)

