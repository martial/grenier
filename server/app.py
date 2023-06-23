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
openai.organization = "org-c7k4c7JQxMzf6Osi2dbircdN"
test = openai.Model.list()
#save result as json file
with open("models.json", "w") as file:
    json.dump(test, file)
    
with open("server-config.json", "r") as file:
    server_config = json.load(file)

# Set the IP address and port of the OSC server
ip_address = server_config["ip_address"]
server_port = server_config["ports"]["server"]
pde_port = server_config["ports"]["server_to_pde"]
pde_port2 = server_config["ports2"]["server_to_pde"]
transcript_port_client = server_config["ports"]["server_to_transcript"]
transcript_port_server = server_config["ports"]["transcript_to_server"]
transcript_port_client2 = server_config["ports2"]["server_to_transcript"]
transcript_port_server2 = server_config["ports2"]["transcript_to_server"]
log_port = server_config["log"]["port"]

# Create database
createDB()

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
toggle_listen = res["toggle_listen"]
model = res["model"]

resetDBModes()

# Create an OSC client
client = udp_client.SimpleUDPClient(ip_address, pde_port)
client2 = udp_client.SimpleUDPClient(ip_address, pde_port2)
log_client = udp_client.SimpleUDPClient(ip_address, log_port)


gpt = chatGPT(ip_address,transcript_port_client, 1, log_client)
gpt.appendHistory({"role": "system", "content": gpt_role})
gpt.appendHistory({"role": "system", "content": gpt_context})
gpt.appendHistory({"role": "system", "content": gpt_action})
gpt2 = chatGPT(ip_address,transcript_port_client2, 2, log_client)
gpt2.appendHistory({"role": "system", "content": gpt_role})
gpt2.appendHistory({"role": "system", "content": gpt_context})
gpt2.appendHistory({"role": "system", "content": gpt_action})

playing_mode = "play"
playing_mode_2 = "play"

if (toggle_listen == 1):
    setDBPlayingMode("pause")
    playing_mode = "pause"
    playing_mode_2 = "pause"
    osc_address = "/status/"
    osc_message = 'pause'
    client.send_message(osc_address, osc_message)
    client2.send_message(osc_address, osc_message)
    gpt.sendStatusMessage(osc_message)
    gpt2.sendStatusMessage(osc_message)
else:
    osc_address = "/status/"
    osc_message = 'listening'
    client.send_message(osc_address, osc_message)
    client2.send_message(osc_address, osc_message)
    gpt.sendStatusMessage(osc_message)
    gpt2.sendStatusMessage(osc_message)

# Create the OSC server dispatcher and register the handler function

def speak(text, language='fr'):
    subprocess.run(["say", "-v", f"{language}", text])

def sendTranscriptionConfig():
    trans_config = getDBTransConfig()
    osc_address = "/config/"
    gpt.sendConfigMessage([
        trans_config["transcription_silence"], 
        trans_config["transcription_restart"],
        trans_config["language"],
        trans_config["mic_index_1"]
    ])
def sendTranscriptionConfig2():
    trans_config = getDBTransConfig()
    osc_address = "/config/"
    gpt2.sendConfigMessage([
        trans_config["transcription_silence"], 
        trans_config["transcription_restart"],
        trans_config["language"],
        trans_config["mic_index_2"]
    ])

def handle_get_config_message(address, *args):
    sendTranscriptionConfig()
def handle_get_config_message2(address, *args):
    sendTranscriptionConfig2()

def handle_speech_message(address, *args):
    
    global gpt

    log_client.send_message("/log/", "Receive Speech 1, "+str(args[0]))
    
    if ( playing_mode == "pause" ):
        log_client.send_message("/log/", "1 paused, returns")
        return

    transcription = str(args[0])

    gpt.setTranscription(transcription)
    started_on_processing = (bool(args[1]))

    print(gpt.getStatus())

    if (transcription == "Stop"):

        log_client.send_message("/log/", "Stop 1")
        gpt.setEndIt(True)

    elif (gpt.getStatus() == "waiting" and not started_on_processing and transcription != ''):

        log_client.send_message("/log/", "Send 1 to promp")
        osc_message = transcription.encode('utf-8')
        osc_address = "/prompt/"
        client.send_message(osc_address, osc_message)

def handle_speech_message2(address, *args):
    
    global gpt2

    log_client.send_message("/log/", "Receive Speech 2, "+str(args[0]))

    if ( playing_mode_2 == "pause" ):
        log_client.send_message("/log/", "2 paused, returns")
        return

    transcription = str(args[0])

    gpt2.setTranscription(transcription)
    started_on_processing = (bool(args[1]))

    if (transcription == "Stop"):

        log_client.send_message("/log/", "Stop 2")
        gpt2.setEndIt(True)

    elif (gpt2.getStatus() == "waiting" and not started_on_processing and transcription != ''):
        
        log_client.send_message("/log/", "Send 2 to promp")
        osc_message = transcription.encode('utf-8')
        osc_address = "/prompt/"
        client2.send_message(osc_address, osc_message)

def handle_stop_message(address, *args):

    global gpt

    log_client.send_message("/log/", "Receive Stop 1")

    if ( playing_mode == "pause" ):
        log_client.send_message("/log/", "1 paused, returns")
        return

    if ( gpt.getStatus() == "processing"):

        log_client.send_message("/log/", "Stop 1")
        gpt.setEndIt(True)
        osc_address = "/stopped/"
        gpt.sendStopMessage()

def handle_stop_message2(address, *args):

    global gpt2

    log_client.send_message("/log/", "Receive Stop 2")

    if ( playing_mode_2 == "pause" ):
        log_client.send_message("/log/", "2 paused, returns")
        return

    if ( gpt2.getStatus() == "processing"):

        log_client.send_message("/log/", "Stop 2")
        gpt2.setEndIt(True)
        osc_address = "/stopped/"
        gpt2.sendStopMessage()


def end_speech_message(started_on_processing) :

    global gpt
    global playing_mode

    log_client.send_message("/log/", "Receive End Speech 1, started on processing "+str(started_on_processing))

    if ( playing_mode == "pause" ):
        log_client.send_message("/log/", "1 paused, returns")
        return
    
    transcription = gpt.getTranscription()

    # Traitement du message OSC reçu
    if (gpt.getStatus() == "waiting" and not started_on_processing and transcription != ''):
        log_client.send_message("/log/", "Call open AI 1")
        gpt.callOpenAI(transcription, openai, gpt_role, gpt_context, gpt_action, model, gpt_temp, language, playing_mode, talk, True, client)
    else:
        return
    
    gpt.clearTranscription()

    #if ( gpt.getStatus() == "will_waiting"):
    gpt.setStatus("waiting")
    osc_address = "/status/"
    osc_message = 'listening'
    if (getDBPlayingMode1() == "pause"):
        osc_message = 'pause'
    client.send_message(osc_address, osc_message)
    gpt.sendStatusMessage(osc_message)



def handle_end_speech_message(address, *args):

    started_on_processing = (bool(args[0]))
    thread = threading.Thread(target=end_speech_message, args=(started_on_processing,))
    thread.start()


def end_speech_message2(started_on_processing) :

    global gpt2
    global playing_mode_2

    log_client.send_message("/log/", "Receive End Speech 2, started on processing "+str(started_on_processing))

    if ( playing_mode_2 == "pause" ):
        log_client.send_message("/log/", "2 paused, returns")
        return
    
    transcription = gpt2.getTranscription()

    # Traitement du message OSC reçu
    if (gpt2.getStatus() == "waiting" and not started_on_processing and transcription != ''):
        log_client.send_message("/log/", "Call open AI 2")
        gpt2.callOpenAI(transcription, openai, gpt_role, gpt_context, gpt_action, model, gpt_temp, language, playing_mode_2, False, True, client2)
    else:
        return
    
    gpt2.clearTranscription()

    #if ( gpt2.getStatus() == "will_waiting"):
    gpt2.setStatus("waiting")
    osc_address = "/status/"
    osc_message = 'listening'
    if (getDBPlayingMode2() == "pause"):
        osc_message = 'pause'
    client2.send_message(osc_address, osc_message)
    gpt2.sendStatusMessage(osc_message)


def handle_end_speech_message2(address, *args):

    started_on_processing = (bool(args[0]))
    thread = threading.Thread(target=end_speech_message2, args=(started_on_processing,))
    thread.start()


def handle_mic_index_message(address, *args):
    mic_index = (int(args[0]))
    setDBMicIndex1(mic_index)

def handle_mic_index_message2(address, *args):
    mic_index = (int(args[0]))
    setDBMicIndex2(mic_index)

def start_osc_server():

    # Création du dispatcher qui gère les messages OSC reçus
    dispatch = dispatcher.Dispatcher()

    dispatch.map("/speech/", handle_speech_message)    
    dispatch.map("/end-speech/", handle_end_speech_message)    
    dispatch.map("/stop/", handle_stop_message)    
    dispatch.map("/get-config/", handle_get_config_message)   
    dispatch.map("/mic-index/", handle_mic_index_message)   

    dispatch2 = dispatcher.Dispatcher()

    dispatch2.map("/speech/", handle_speech_message2)    
    dispatch2.map("/end-speech/", handle_end_speech_message2)    
    dispatch2.map("/stop/", handle_stop_message2)    
    dispatch2.map("/get-config/", handle_get_config_message2)    
    dispatch2.map("/mic-index/", handle_mic_index_message2)   

    # # Création du serveur OSC
    server = osc_server.ThreadingOSCUDPServer((ip_address, transcript_port_server), dispatch)
    print("OSC server started on {}:{}".format(ip_address, transcript_port_server))

    server2 = osc_server.ThreadingOSCUDPServer((ip_address, transcript_port_server2), dispatch2)
    print("OSC server started on {}:{}".format(ip_address, transcript_port_server2))

    # Démarrage du serveur OSC dans un thread dédié
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.start()

    server_thread2 = threading.Thread(target=server2.serve_forever)
    server_thread2.start()

def start_parameter_loop():

    global gpt

    global playing_mode
    global playing_mode_2
    global gpt_role
    global gpt_context
    global gpt_action
    global gpt_temp
    global talk
    global toggle_listen
    global language
    global model

    def run_job():

        global playing_mode
        global playing_mode_2

        global gpt_role
        global gpt_context
        global gpt_action

        while True:

            c_playing_mode = getDBPlayingMode1()
            c_playing_mode_2 = getDBPlayingMode2()

            if ( playing_mode == "play" and c_playing_mode == "pause" ):

                thread = threading.Thread(target=end_speech_message, args=(False,))
                thread.start()

                #if gpt.getStatus() == "listening" :
                #     gpt.setStatus("waiting")
                #     gpt.clearTranscription()
                #     gpt.setEndIt(True)

                #osc_address = "/status/"
                #osc_message = 'pause'
                #client.send_message(osc_address, osc_message)
                #gpt.sendStatusMessage(osc_message)

                playing_mode = c_playing_mode

            if ( playing_mode_2 == "play" and c_playing_mode_2 == "pause" ):

                thread = threading.Thread(target=end_speech_message2, args=(False,))
                thread.start()

                #if gpt.getStatus() == "listening" :
                #    gpt2.setStatus("waiting")
                #    gpt2.clearTranscription()
                #    gpt2.setEndIt(True)

                #osc_address = "/status/"
                #osc_message = 'pause'
                #client2.send_message(osc_address, osc_message)
                #gpt2.sendStatusMessage(osc_message)

                playing_mode_2 = c_playing_mode_2

            if ( playing_mode == "pause" and c_playing_mode == "play" ):

                osc_address = "/status/"
                osc_message = 'listening'
                gpt.setEndIt(False)

                client.send_message(osc_address, osc_message)
                gpt.sendStatusMessage(osc_message)
                playing_mode = c_playing_mode

            if ( playing_mode_2 == "pause" and c_playing_mode_2 == "play" ):

                osc_address = "/status/"
                osc_message = 'listening'
                gpt2.setEndIt(False)

                client2.send_message(osc_address, osc_message)
                gpt2.sendStatusMessage(osc_message)
                playing_mode_2 = c_playing_mode_2

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
                gpt2.appendHistory({"role": "system", "content": gpt_role})
                gpt2.appendHistory({"role": "system", "content": gpt_context})
                gpt2.appendHistory({"role": "system", "content": gpt_action})

            #check if reset history
            res = getDBReset1()
            if (res == 1):
                gpt.setEndIt(True)
                gpt.resetHistory()
                gpt.appendHistory({"role": "system", "content": gpt_role})
                gpt.appendHistory({"role": "system", "content": gpt_context})
                gpt.appendHistory({"role": "system", "content": gpt_action})
                setDBReset1(0)
                osc_address = "/reset/"
                osc_message = ""
                client.send_message(osc_address, osc_message)

            res = getDBReset2()
            if (res == 1):
                gpt2.setEndIt(True)
                gpt2.resetHistory()
                gpt2.appendHistory({"role": "system", "content": gpt_role})
                gpt2.appendHistory({"role": "system", "content": gpt_context})
                gpt2.appendHistory({"role": "system", "content": gpt_action})
                setDBReset2(0)
                osc_address = "/reset/"
                osc_message = ""
                client2.send_message(osc_address, osc_message)

            res = getDBStop1()
            if (res == 1):
                gpt.setEndIt(True)
                setDBStop1(0)

            res = getDBStop2()
            if (res == 1):
                gpt2.setEndIt(True)
                setDBStop2(0)

            res = getDBTransConfig()
            if(res):
                talk = res["talk"]
                toggle_listen = res["toggle_listen"]
                language = res["language"]
                model = res["model"]
            
            #time.sleep(1./30)



    thread = threading.Thread(target=run_job)
    thread.start()


app = Flask(__name__)
app.debug = True # needed to scss to compile
# Scss(app, static_dir='static/css/', asset_dir='static/scss/')

@app.route('/config')
def config(model= None, talk = None, toggle_listen = None, language=None, gpt_role=None, gpt_context=None, gpt_action=None, gpt_temp=None, transcription_silence=None, transcription_restart=None, playing_mode=None, playing_mode_2=None):

    params_set = model and talk and toggle_listen and language and gpt_role and gpt_context and gpt_action and gpt_temp and transcription_silence and transcription_restart
    request_set =  request.args.get('model') and request.args.get('talk') and request.args.get('toggle_listen') and request.args.get('language') and request.args.get('gpt_role')  and request.args.get('gpt_context')  and request.args.get('gpt_action') and request.args.get('gpt_temp') and request.args.get('transcription_silence') and request.args.get('transcription_restart')
    
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
            toggle_listen = res["toggle_listen"]
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
            toggle_listen = request.args.get('toggle_listen')
            model = request.args.get('model')
   
    if not (playing_mode) and not (request.args.get('playing_mode')):
        playing_mode = getDBPlayingMode1()

    if not (playing_mode_2) and not (request.args.get('playing_mode_2')):
        playing_mode_2 = getDBPlayingMode2()

    if (toggle_listen==1):
        playing_mode = "pause"
        playing_mode_2 = "pause"
        setDBPlayingMode("pause")

    prompt = getPromptDB()

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
        toggle_listen=toggle_listen,
        model=model,
        playing_mode=playing_mode,
        playing_mode_2=playing_mode_2,
        prompt=prompt
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
    toggle_listen = request.form['toggle_listen']
    model = request.form['model']

    updateDB(gpt_role, gpt_context, gpt_action, gpt_temp)
    updateTransDB(transcription_silence, transcription_restart, language, talk, toggle_listen, model)

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

@app.route('/reset_1', methods=['POST'])
def reset_1():
    setDBReset1(1)
    response = {'message': 'ok'}
    return jsonify(response)

@app.route('/reset_2', methods=['POST'])
def reset_2():
    setDBReset2(1)
    response = {'message': 'ok'}
    return jsonify(response)

@app.route('/stop_1', methods=['POST'])
def stop_1():
    setDBStop1(1)
    response = {'message': 'ok'}
    return jsonify(response)

@app.route('/stop_2', methods=['POST'])
def stop_2():
    setDBStop2(1)
    response = {'message': 'ok'}
    return jsonify(response)

@app.route('/toggle_listen_1', methods=['POST'])
def toggle_listen():
    data = request.json.get('data')
    if (data == "on"):
        setDBPlayingMode1("play")
    else:
        setDBPlayingMode1("pause")    
    response = {'message': 'ok'}
    return jsonify(response)

@app.route('/toggle_listen_2', methods=['POST'])
def toggle_listen_2():
    data = request.json.get('data')
    if (data == "on"):
        setDBPlayingMode2("play")
    else:
        setDBPlayingMode2("pause")     
    response = {'message': 'ok'}
    return jsonify(response)

@app.route('/add_prompt', methods=['POST'])
def add_prompt():
    slot = request.json.get('slot')
    title = request.json.get('title')
    gpt_role = request.json.get('gpt_role')
    gpt_context = request.json.get('gpt_context')
    gpt_action = request.json.get('gpt_action')

    id = insertPromptDB(slot,title,gpt_role,gpt_context,gpt_action)
    response = {'id': id}
    return jsonify(response)

@app.route('/mod_prompt', methods=['POST'])
def mod_prompt():
    id = request.json.get('id')
    slot = request.json.get('slot')
    title = request.json.get('title')
    gpt_role = request.json.get('gpt_role')
    gpt_context = request.json.get('gpt_context')
    gpt_action = request.json.get('gpt_action')

    updatePromptDB(id, slot,title,gpt_role,gpt_context,gpt_action)
    response = {'message': 'ok'}
    return jsonify(response)

@app.route('/del_prompt', methods=['POST'])
def del_prompt():
    id = request.json.get('id')
    deletePromptDB(id)
    response = {'message': 'ok'}
    return jsonify(response)

if __name__ == "__main__":
         
    if os.environ.get('WERKZEUG_RUN_MAIN') != 'true':
        start_osc_server()
        start_parameter_loop()

    sendTranscriptionConfig()
    sendTranscriptionConfig2()
    webbrowser.open('http://'+ip_address+':'+str(server_port)+'/config')

    app.run(debug=False, host="127.0.0.1", port=server_port)

