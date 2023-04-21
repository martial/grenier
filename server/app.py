import openai
import json
from pythonosc import udp_client
import speech_recognition as sr
import time
import os
import subprocess
import requests
from PIL import Image
from io import BytesIO
from flask import Flask, render_template, request, send_file, jsonify
import uuid
import cv2
import numpy as np
from PIL import ImageOps
from dotenv import load_dotenv
from flask_scss import Scss
from vosk import Model, KaldiRecognizer, SetLogLevel
import pyaudio
import audioop
from flask import Response, stream_with_context
import threading
import time

# from gtts import gTTS
# from io import BytesIO
# from pygame import mixer

load_dotenv() 

# Set the IP address and port of the OSC server
ip_address = "127.0.0.1"
port = 8000

# Create an OSC client
client = udp_client.SimpleUDPClient(ip_address, port)
osc_address = "/status/"
full_reply_content = 'listening'
osc_message = full_reply_content
client.send_message(osc_address, osc_message)

# Define openAPI key
api_key = os.getenv("API_KEY")

# Load config
with open('config.json', 'r') as f:
    data = json.load(f)

conf_conv_history = data['conf_conv_history']
conf_gpt_temp = data['conf_gpt_temp']
# conf_listening_mode = data['conf_listening_mode']

openai.api_key = api_key
state = None
conversation_history = [{"role": "system", "content": conf_conv_history}]

app = Flask(__name__)
app.debug = True # needed to scss to compile
Scss(app, static_dir='static/css/', asset_dir='static/scss/')

# mixer.init()
# mixer.music.set_volume(0.7)

status = "waiting"
waiting_timeout = time.time()
stream_rec = []
end_it = False

def endOpenai():
    global end_it
    end_it = True

def call_openai_gpt(prompt):

    global stream_rec
    global waiting_timeout
    global status
    # global conf_listening_mode
    global end_it

    # if (conf_listening_mode == "always_listening"):    
    #     if prompt != '' :
    #         stream_rec.append(prompt)
    #     if ( len(stream_rec) > 0 ) :
    #         prompt = stream_rec.pop(0)
    # else :
    if prompt == '' :
        return

    
    # if prompt != '' :
    #     stream_rec.append(prompt)

    if status == "processing": #and conf_listening_mode != "always_listening":
        return


    # if ( len(stream_rec) > 0 ) :
    #     prompt = stream_rec.pop(0)
    # else :
    #     osc_address = "/status/"
    #     osc_message = 'listening'
    #     client.send_message(osc_address, osc_message)
    #     return 

    status = "processing"

    print("REQUETTE "+prompt)

    osc_address = '/chat/'
    full_reply_content = ''
    osc_message = full_reply_content
    client.send_message(osc_address, osc_message)

    osc_address = "/status/"
    full_reply_content = 'processing'
    osc_message = full_reply_content
    client.send_message(osc_address, osc_message)

    conversation_history.append({"role": "user", "content": prompt})

    response = openai.ChatCompletion.create(
        model="gpt-4",#3.5-turbo",
        messages=conversation_history,
        max_tokens=2048,
        n=1,
        stop=None,
        temperature=conf_gpt_temp,
        stream=True
    )

    collected_chunks = []
    collected_messages = []

    for chunk in response:
        collected_chunks.append(chunk)
        chunk_message = chunk['choices'][0]['delta']
        collected_messages.append(chunk_message)

        full_reply_content = ''.join([m.get('content', '') for m in collected_messages])

        if end_it: 
            break

        if full_reply_content:

            osc_message = prompt.encode('utf-8')
            osc_address = "/prompt/"
            client.send_message(osc_address, osc_message)

            osc_message = full_reply_content.encode('utf-8')
            osc_address = "/chat/"
            client.send_message(osc_address, osc_message)
            #print(full_reply_content)
            #print(f"Full conversation received: {osc_message}")
    
    full_reply_content = ''.join([m.get('content', '') for m in collected_messages])
    conversation_history.append({"role": "assistant", "content": full_reply_content})

    # # Generate speech
    # tts = gTTS(text=full_reply_content, lang='fr')
    # speech_stream = BytesIO()
    # tts.write_to_fp(speech_stream)
    # speech_stream.seek(0)

    # # Play speech
    # mixer.music.load(speech_stream)
    # mixer.music.play()
    # while mixer.music.get_busy():
    #     pass

    waiting_timeout = time.time()
    # osc_address = "/status/"
    # osc_message = 'listening'
    # client.send_message(osc_address, osc_message)
    status = "will_waiting"
    end_it = False




# def analyze_sentiment(text):
#     prompt = f"Please analyze the sentiment of the following text and categorize it as positive, negative, or neutral. Answer by one word: \"{text}\""

#     response = openai.Completion.create(
#         engine="text-davinci-002",
#         prompt=prompt,
#         max_tokens=10,
#         n=1,
#         stop=None,
#         temperature=0.5,
#     )

#     sentiment = response.choices[0].text.strip()
#     return sentiment

# def listen_and_recognize_speech_continuously():
#     recognizer = sr.Recognizer()

#     while True:
#         with sr.Microphone() as source:
#             print("Listening...")
#             recognizer.adjust_for_ambient_noise(source, duration=0.01)
#             recognizer.energy_threshold = 4000
#             audio = recognizer.listen(source, phrase_time_limit=5)

#             try:
#                 text = recognizer.recognize_google(audio, language="fr-FR")
#                 print('text: ', text)
#                 response = call_openai_gpt(text)
#                 print(response)
#             except sr.UnknownValueError:
#                 print("Google Speech Recognition could not understand the audio")
#             except sr.RequestError as e:
#                 print(f"Could not request results from Google Speech Recognition service;")
#             time.sleep(1)  # You can adjust the sleep duration as needed
#             osc_address = "/status/"

#             full_reply_content = 'listening'
#             osc_message = full_reply_content
#             client.send_message(osc_address, osc_message)


# def getPromptWithLetter(prompt, letter):
#     return  prompt.format(letter=letter)

# @app.route('/start')
# def start():
#     listen_and_recognize_speech_continuously()
#     if request.method == 'POST':
#         prompt = request.form['prompt']
#         image = generate_image(prompt)
#         image.save('static/generated_image.png')
#         return send_file('static/generated_image.png', mimetype='image/png')


def map_range(value, from_min, from_max, to_min, to_max):
    return (value - from_min) * (to_max - to_min) / (from_max - from_min) + to_min


#listen_and_transcribe_stop = False 
@app.route('/listen_and_transcribe')
def listen_and_transcribe():

    global status
    # global conf_listening_mode

    #global listen_and_transcribe_stop

    model = Model("models/vosk-model-fr-0.22")
    rec = KaldiRecognizer(model, 16000)

    p = pyaudio.PyAudio()
    audio_stream = p.open(format=pyaudio.paInt16, channels=1, rate=16000, input=True, frames_per_buffer=4096)

    def generate():

        global status

        while True : #not listen_and_transcribe_stop:

            audio_data = audio_stream.read(4096)
            volume = audioop.rms(audio_data, 2)
            volume_pct = map_range(volume, 0, 32767, 0, 1)
            osc_address = "/volume/"
            osc_message = volume_pct
            client.send_message(osc_address, osc_message)
            
            if len(audio_data) == 0:
                continue

            if rec.AcceptWaveform(audio_data):
                result = json.loads(rec.Result())

                if (result['text'] == "stop"):
                    endOpenai()
                    
                # if (status == "waiting" or conf_listening_mode == "always_listening") and rec.AcceptWaveform(audio_data):
                elif (status == "waiting") :

                    # if conf_listening_mode == "always_listening" :
                    #     for thread in threading.enumerate():
                    #         thread._stop()
                    #print(result['text'])
                    thread = threading.Thread(target=call_openai_gpt, args=(result['text'],))
                    thread.start()

            if status == "will_waiting":
                now = time.time()
                if now - waiting_timeout >= 1:
                    osc_address = "/status/"
                    osc_message = 'listening'
                    client.send_message(osc_address, osc_message)
                    status = "waiting"
                else:
                    continue
            else:
                continue

    #audio_stream.stop_stream()
    #audio_stream.close()
    #p.terminate()

    return Response(stream_with_context(generate()), mimetype='application/json')



@app.route('/config')
def config():
    return render_template('index.html', 
        conf_conv_history=conf_conv_history, 
        conf_gpt_temp=conf_gpt_temp,
        # conf_listening_mode=conf_listening_mode
    )

def configUpdated():
    global conversation_history
    conversation_history.append({"role": "system", "content": conf_conv_history})

@app.route('/submit_form', methods=['POST'])
def submit_form():

    global conf_conv_history
    global conf_gpt_temp
    # global conf_listening_mode

    conf_conv_history = request.form['conf_conv_history']
    conf_gpt_temp = float(request.form['conf_gpt_temp'])
    # conf_listening_mode = request.form['conf_listening_mode']

    json_data = {
        'conf_conv_history': conf_conv_history, 
        'conf_gpt_temp': conf_gpt_temp,
        # 'conf_listening_mode' : conf_listening_mode
    }

    with open('config.json', 'w') as f:
        json.dump(json_data, f)

    configUpdated()
    return config()

if __name__ == "__main__":
    
    # listen_and_transcribe_stop = False
    # # # create and start a new thread for listen_and_transcribe
    # t = threading.Thread(target=listen_and_transcribe)
    # t.start()

    app.run(debug=True, host="0.0.0.0", port=8080)

    #listen_and_transcribe_stop = True
    #t.join()
