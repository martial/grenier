import openai
from openai.error import InvalidRequestError
import json
from pythonosc import udp_client, dispatcher, osc_server
import os
from flask import Flask, render_template, request, redirect, url_for, send_file, jsonify
from dotenv import load_dotenv
from flask_scss import Scss
#from vosk import Model, KaldiRecognizer, SetLogLevel
import threading
from database import createDB, getDBConfig, getDBUpdate, updateDB, getDBTransConfig, updateTransDB
import webbrowser

load_dotenv() 

with open("server-config.json", "r") as file:
    server_config = json.load(file)

# Set the IP address and port of the OSC server
ip_address = server_config["ip_address"]
server_port = server_config["ports"]["server"]
pde_port = server_config["ports"]["server_to_pde"]
transcript_port_client = server_config["ports"]["server_to_transcript"]
transcript_port_server = server_config["ports"]["transcript_to_server"]

# Create an OSC client
client = udp_client.SimpleUDPClient(ip_address, pde_port)
transcription_client = udp_client.SimpleUDPClient(ip_address, transcript_port_client)

osc_address = "/status/"
full_reply_content = 'listening'
osc_message = full_reply_content
client.send_message(osc_address, osc_message)
transcription_client.send_message(osc_address, osc_message)

transcription = "";

# Create the OSC server dispatcher and register the handler function

def sendTranscriptionConfig():

    trans_config = getDBTransConfig()
    osc_address = "/config/"
    transcription_client.send_message(osc_address, [
        trans_config["transcription_silence"], 
        trans_config["transcription_restart"],
        trans_config["language"]
    ])

def handle_get_config_message(address, *args):
    sendTranscriptionConfig()

def handle_speech_message(address, *args):
    
    global transcription
    global status

    transcription = str(args[0])
    started_on_processing = (bool(args[1]))

    if (transcription == "Stop"):
        endOpenai()

    # if (status == "waiting" and started_on_processing and transcription != ''):
    #     print("quiet")
    #     osc_address = "/quiet/"
    #     client.send_message(osc_address, "")
    
    elif (status == "waiting" and not started_on_processing and transcription != ''):

        osc_message = transcription.encode('utf-8')
        osc_address = "/prompt/"
        client.send_message(osc_address, osc_message)

def handle_stop_message(address, *args):

    global status

    if ( status == "processing"):
        endOpenai()
        osc_address = "/stopped/"
        transcription_client.send_message(osc_address, [1])

def handle_end_speech_message(address, *args):

    global status
    global transcription

    started_on_processing = (bool(args[0]))

    # Traitement du message OSC reçu
    if (status == "waiting" and not started_on_processing and transcription != ''):
        call_openai_gpt(transcription)
    
    transcription = ""

    if ( status == "will_waiting"):
        status = "waiting"
        osc_address = "/status/"
        osc_message = 'listening'
        client.send_message(osc_address, osc_message)
        transcription_client.send_message(osc_address, osc_message)

def start_osc_server():

    # Création du dispatcher qui gère les messages OSC reçus
    dispatch = dispatcher.Dispatcher()
    dispatch.map("/speech", handle_speech_message)    
    dispatch.map("/end-speech", handle_end_speech_message)    
    dispatch.map("/stop", handle_stop_message)    
    dispatch.map("/get-config", handle_get_config_message)    

    # Création du serveur OSC
    server = osc_server.ThreadingOSCUDPServer((ip_address, transcript_port_server), dispatch)
    print("OSC server started on {}:{}".format(ip_address, transcript_port_server))

    # Démarrage du serveur OSC dans un thread dédié
    server_thread = threading.Thread(target=server.serve_forever)
    server_thread.start()


# Define openAPI key
api_key = os.getenv("API_KEY")

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

openai.api_key = api_key
state = None
conversation_history = [{"role": "system", "content": gpt_role}]
conversation_history.append({"role": "system", "content": gpt_context})
conversation_history.append({"role": "system", "content": gpt_action})

app = Flask(__name__)
app.debug = True # needed to scss to compile
Scss(app, static_dir='static/css/', asset_dir='static/scss/')

status = "waiting"
end_it = False

def endOpenai():
    global end_it
    end_it = True

def call_openai_gpt(prompt):

    global status
    global end_it

    global conversation_history
    global gpt_role
    global gpt_context
    global gpt_action

    global gpt_temp

    # Returns if empty prompt
    if prompt == '' :
        return

    # Retuns if alreay processing (call_opainai_gpt is threaded)
    if status == "processing":
        return
    if status == "will_waiting":
        return

    # Check if config or history should be updated (changes from html form)
    res = getDBUpdate()
    if (res):
        gpt_role = res["gpt_role"]
        gpt_context = res["gpt_context"]
        gpt_action = res["gpt_action"]
        gpt_temp = res["gpt_temp"]
        conversation_history.append({"role": "system", "content": gpt_role})
        conversation_history.append({"role": "system", "content": gpt_context})
        conversation_history.append({"role": "system", "content": gpt_action})

    # We will go to processing mode now
    status = "processing"

    print("REQUETTE "+prompt)

    # Send the prompt to Pde
    osc_address = '/chat/'
    full_reply_content = ''
    osc_message = full_reply_content
    client.send_message(osc_address, osc_message)

    # Send the new status to Pde
    osc_address = "/status/"
    full_reply_content = 'requesting'
    osc_message = full_reply_content
    client.send_message(osc_address, osc_message)
    full_reply_content = 'processing'
    osc_message = full_reply_content
    transcription_client.send_message(osc_address, osc_message)

    # Append prompt to history
    conversation_history.append({"role": "user", "content": prompt})

    # ChatGPT query
    try:
        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",#gpt-4
            messages=conversation_history,
            max_tokens=2048,
            n=1,
            stop=None,
            temperature=gpt_temp,
            stream=True
        )
    except InvalidRequestError as e:
        print(e)
        osc_message = ("InvalidRequestError — Tokens exceeeded").encode('utf-8')
        osc_address = "/chat/"
        client.send_message(osc_address, osc_message)
        status = "will_waiting"
        end_it = False
        return
        
    osc_address = "/status/"
    full_reply_content = 'processing'
    osc_message = full_reply_content
    client.send_message(osc_address, osc_message)

    # Process ChatGPT response, word to word
    collected_chunks = []
    collected_messages = []
    for chunk in response:
        collected_chunks.append(chunk)
        chunk_message = chunk['choices'][0]['delta']
        collected_messages.append(chunk_message)

        full_reply_content = ''.join([m.get('content', '') for m in collected_messages])

        # We stop the processing loop if we get a "stop" message
        if end_it: 
            break

        if full_reply_content:

            # Send the chatGPT response to Pde
            osc_message = full_reply_content.encode('utf-8')
            osc_address = "/chat/"
            client.send_message(osc_address, osc_message)

            #print(full_reply_content)
    
    # Append chatGPT response to history
    full_reply_content = ''.join([m.get('content', '') for m in collected_messages])
    conversation_history.append({"role": "assistant", "content": full_reply_content})

    status = "will_waiting"
    end_it = False

# Mapping function, map a value from input interval to output interval
def map_range(value, from_min, from_max, to_min, to_max):
    return (value - from_min) * (to_max - to_min) / (from_max - from_min) + to_min


@app.route('/config')
def config(language=None, gpt_role=None, gpt_context=None, gpt_action=None, gpt_temp=None, transcription_silence=None, transcription_restart=None):

    params_set = language and gpt_role and gpt_context and gpt_action and gpt_temp and transcription_silence and transcription_restart
    request_set = request.args.get('language') and request.args.get('gpt_role')  and request.args.get('gpt_context')  and request.args.get('gpt_action') and request.args.get('gpt_temp') and request.args.get('transcription_silence') and request.args.get('transcription_restart')
    
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
        else :
            gpt_role = request.args.get('gpt_role')
            gpt_context = request.args.get('gpt_context')
            gpt_action = request.args.get('gpt_action')
            gpt_temp = request.args.get('gpt_temp')
            transcription_silence = request.args.get('transcription_silence')
            transcription_restart = request.args.get('transcription_restart')
            language = request.args.get('language')

    return render_template('index.html', 
        language=language,
        gpt_role=gpt_role, 
        gpt_context=gpt_context, 
        gpt_action=gpt_action, 
        gpt_temp=gpt_temp,
        updated=updated,
        transcription_silence=transcription_silence,
        transcription_restart=transcription_restart
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

    updateDB(gpt_role, gpt_context, gpt_action, gpt_temp)
    updateTransDB(transcription_silence, transcription_restart, language)
    sendTranscriptionConfig()

    return redirect(url_for("config"))#,gpt_role=gpt_role, gpt_temp=gpt_temp))

if __name__ == "__main__":
        
        
    if os.environ.get('WERKZEUG_RUN_MAIN') != 'true':
        start_osc_server()

        # try:
        # finally:
        #     client._sock.close()
        #     transcription_client._sock.close()

    sendTranscriptionConfig()
    webbrowser.open('http://'+ip_address+':'+str(server_port)+'/config')
    app.run(debug=True, host="0.0.0.0", port=server_port)

