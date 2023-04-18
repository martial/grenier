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
from flask import Flask, render_template, request, send_file
import uuid
import cv2
import numpy as np
from PIL import ImageOps
from dotenv import load_dotenv

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

openai.api_key = api_key
state = None
conversation_history = [{"role": "system", "content": "You're a professional translator with amazing html skills"}]

app = Flask(__name__)

def call_openai_gpt(prompt):
    osc_address = "/chat/"
    full_reply_content = ''
    osc_message = full_reply_content
    client.send_message(osc_address, osc_message)

    osc_address = "/status/"
    full_reply_content = 'processing'
    osc_message = full_reply_content
    client.send_message(osc_address, osc_message)

    conversation_history.append({"role": "user", "content": prompt})

    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=conversation_history,
        max_tokens=4090 - 1200,
        n=1,
        stop=None,
        temperature=0.5,
        stream=True
    )

    collected_chunks = []
    collected_messages = []

    for chunk in response:
        collected_chunks.append(chunk)
        chunk_message = chunk['choices'][0]['delta']
        collected_messages.append(chunk_message)

        full_reply_content = ''.join([m.get('content', '') for m in collected_messages])

        if full_reply_content:
            osc_message = full_reply_content.encode('utf-8')
            osc_address = "/chat/"
            client.send_message(osc_address, osc_message)
            print(full_reply_content)
            #print(f"Full conversation received: {osc_message}")

    full_reply_content = ''.join([m.get('content', '') for m in collected_messages])
    conversation_history.append({"role": "assistant", "content": full_reply_content})


def analyze_sentiment(text):
    prompt = f"Please analyze the sentiment of the following text and categorize it as positive, negative, or neutral. Answer by one word: \"{text}\""

    response = openai.Completion.create(
        engine="text-davinci-002",
        prompt=prompt,
        max_tokens=10,
        n=1,
        stop=None,
        temperature=0.5,
    )

    sentiment = response.choices[0].text.strip()
    return sentiment
    
def listen_and_recognize_speech_continuously():
    recognizer = sr.Recognizer()

    while True:
        with sr.Microphone() as source:
            print("Listening...")
            recognizer.adjust_for_ambient_noise(source, duration=0.01)
            recognizer.energy_threshold = 4000
            audio = recognizer.listen(source, phrase_time_limit=5)

            try:
                text = recognizer.recognize_google(audio, language="fr-FR")
                print('text: ', text)
                response = call_openai_gpt(text)
                print(response)
            except sr.UnknownValueError:
                print("Google Speech Recognition could not understand the audio")
            except sr.RequestError as e:
                print(f"Could not request results from Google Speech Recognition service;")
            time.sleep(1)  # You can adjust the sleep duration as needed
            osc_address = "/status/"

            full_reply_content = 'listening'
            osc_message = full_reply_content
            client.send_message(osc_address, osc_message)


def getPromptWithLetter(prompt, letter):
    return  prompt.format(letter=letter)

          

@app.route('/start')
def start():
    
    listen_and_recognize_speech_continuously()
    if request.method == 'POST':
        prompt = request.form['prompt']
        image = generate_image(prompt)
        image.save('static/generated_image.png')
        return send_file('static/generated_image.png', mimetype='image/png')

    return render_template('index.html')

@app.route('/config')
def config():
    
    return render_template('index.html')

@app.route('/')
def index():
    
    return render_template('index.html')

if __name__ == "__main__":

        app.run(debug=True, host="0.0.0.0", port=8080)



    #prompt =" comment ca va ?"
    #call_openai_gpt(prompt)
    #listen_and_recognize_speech_continuously()


