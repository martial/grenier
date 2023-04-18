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

    #save full_reply_content to a txt file
    with open('conversation.txt', 'w') as f:
        f.write(full_reply_content)


   # sentiment = analyze_sentiment(full_reply_content)
    #subprocess.run(['say', sentiment])
    #subprocess.run(['say', full_reply_content])

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

def generate_image(prompt):
    
    try:
        # Make a request to the DALL-E API
        response = openai.Image.create(
            prompt=prompt,
            n=1,
            size="1024x1024",
            response_format="url"
        )

        # Get the image URL from the API response
        image_url = response['data'][0]['url']

        # Download the image from the URL
        image_response = requests.get(image_url)
        image = Image.open(BytesIO(image_response.content))

        # Save the image to a file
        randomurl = uuid.uuid1()
        image.save(f"{randomurl}.png")

        print(f"Image saved as {prompt}.png")
        return image

    except Exception as e:
        print(f"Error: {e}")
        return None

def generate_image_variation(url):
    # Read the image file from disk and resize it
    image = Image.open(url)
    width, height = 256, 256
    image = image.resize((width, height))

    # Convert the image to a BytesIO object
    byte_stream = BytesIO()
    image.save(byte_stream, format='PNG')
    byte_array = byte_stream.getvalue()

    response = openai.Image.create_variation(
    #prompt="hello",
    image=byte_array,
    n=1,
    size="1024x1024"
    )

    # Get the image URL from the API response
    image_url = response['data'][0]['url']

    # Download the image from the URL
    image_response = requests.get(image_url)
    image = Image.open(BytesIO(image_response.content))

      # Save the image to a file
    edits_folder = "variations"
    if not os.path.exists(edits_folder):
        os.makedirs(edits_folder)

    original_filename = os.path.basename(url)
    simplified_filename = f"{uuid.uuid1()}_{original_filename}"
    output_path = os.path.join(edits_folder, simplified_filename)
    image.save(output_path)
    return output_path


def create_empty_mask(width, height):
    empty_mask = Image.new("RGBA", (width, height), (255, 255, 255, 0))
    mask_bytes = BytesIO()
    empty_mask.save(mask_bytes, "PNG")
    mask_bytes.seek(0)
    return mask_bytes

def convert_to_png_bytes(input_filename):
    # Open the input image
    image = Image.open(input_filename)
    image = image.resize((512,512), Image.ANTIALIAS)

    # Save the image as a PNG in an in-memory bytes buffer
    png_bytes = BytesIO()
    image.save(png_bytes, "PNG")
    png_bytes.seek(0)

    return png_bytes

def resize_square(image, size):
    width, height = image.size
    aspect_ratio = float(width) / float(height)

    if width < height:
        new_width = size
        new_height = int(size / aspect_ratio)
    else:
        new_height = size
        new_width = int(size * aspect_ratio)

    resized_image = image.resize((new_width, new_height), Image.ANTIALIAS)
    square_image = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    square_image.paste(resized_image, ((size - new_width) // 2, (size - new_height) // 2))

    return square_image


def create_image_edit(url):


    letter_image = Image.open(url)
    width, height = letter_image.size

    square_size = 512
    square_image = resize_square(letter_image, square_size)

    input_image = np.array(square_image)

    keypoints = detect_text_blobs(input_image)
    mask = create_mask(input_image, keypoints)
    masked_image = apply_mask(input_image, mask)

    # Save the masked image to an in-memory bytes buffer
    mask_bytes = BytesIO()
    masked_image.save(mask_bytes, "PNG")
    mask_bytes.seek(0)
   

    response = openai.Image.create_edit(
    image=convert_to_png_bytes(url),
    mask=mask_bytes,
    prompt="hand writing",
    n=1,
    size="1024x1024"
    )

    # Get the image URL from the API response
    image_url = response['data'][0]['url']

    # Download the image from the URL
    image_response = requests.get(image_url)
    image = Image.open(BytesIO(image_response.content))

     # Save the image to a file
    edits_folder = "edits"
    if not os.path.exists(edits_folder):
        os.makedirs(edits_folder)

    original_filename = os.path.basename(url)
    simplified_filename = f"{uuid.uuid1()}_{original_filename}"
    output_path = os.path.join(edits_folder, simplified_filename)
    image.save(output_path)


def create_image_edit_2(url, mask_url):


    letter_image = Image.open(url)
    width, height = letter_image.size

    square_size = 512
    square_image = resize_square(letter_image, square_size)

    input_image = np.array(square_image)

    mask_image = Image.open(mask_url)
    square_mask = resize_square(mask_image, square_size)

     # Convert the square_image and mask_image to byte streams
    image_bytes = BytesIO()
    square_image.save(image_bytes, "PNG")
    image_bytes.seek(0)

    mask_bytes = BytesIO()
    square_mask.save(mask_bytes, "PNG")
    mask_bytes.seek(0)


    response = openai.Image.create_edit(
    image=image_bytes, #help send image here
    mask=mask_bytes, #help send mask image here
    prompt="red cherry",
    n=1,
    size="1024x1024"
    )

    # Get the image URL from the API response
    image_url = response['data'][0]['url']

    # Download the image from the URL
    image_response = requests.get(image_url)
    image = Image.open(BytesIO(image_response.content))

     # Save the image to a file
    edits_folder = "edits"
    if not os.path.exists(edits_folder):
        os.makedirs(edits_folder)

    max_filename_length = 20
    original_filename = os.path.basename(url)
    
   # Truncate the original filename from the beginning if it's too long
    if len(original_filename) > max_filename_length:
        file_extension = os.path.splitext(original_filename)[1]
        truncated_name = original_filename[-(max_filename_length - len(file_extension)):]
        original_filename = truncated_name

    simplified_filename = f"{uuid.uuid1()}_{original_filename}"
    output_path = os.path.join(edits_folder, simplified_filename)
    image.save(output_path)

    return output_path

def process_masks_in_folder(folder_path, original_image_url):
    mask_files = [f for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f))]

    prev_path = original_image_url
    for mask_file in mask_files:
        mask_path = os.path.join(folder_path, mask_file)
        prev_path = create_image_edit_2(prev_path, mask_path)

def detect_text_blobs(image):
    # Convert the image to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Apply binary thresholding
    _, thresh = cv2.threshold(gray, 128, 255, cv2.THRESH_BINARY_INV)

    # Find contours in the thresholded image
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    # Filter contours by area
    min_area = 10
    filtered_contours = [contour for contour in contours if cv2.contourArea(contour) > min_area]

    return filtered_contours


def detect_blobs(image):
    # Set up the SimpleBlobDetector with default parameters.

    params = cv2.SimpleBlobDetector_Params()
 
        # Change thresholds
    params.minThreshold = 10
    params.maxThreshold = 200

    # Filter by Area.
    params.filterByArea = True
    params.minArea = 10

    # Filter by Circularity
    params.filterByCircularity = False
    params.minCircularity = 0.1

    # Filter by Convexity
    params.filterByConvexity = False
    params.minConvexity = 0.87

    # Filter by Inertia
    params.filterByInertia = False
    params.minInertiaRatio = 0.01

    # Create the detector with the parameters
    detector = cv2.SimpleBlobDetector_create(params)

    # Detect blobs
    keypoints = detector.detect(image)

    return keypoints

def create_mask(image, contours):
    # Create a blank mask with the same size as the input image
    mask = np.zeros((image.shape[0], image.shape[1], 4), dtype=np.uint8)

    # Draw filled contours (blobs) on the mask
    for contour in contours:
        cv2.drawContours(mask, [contour], -1, (255, 255, 255, 255), thickness=cv2.FILLED)

    return mask


def apply_mask(image, mask):
    # Convert OpenCV BGR image to PIL RGBA image
    image_pil = cv2.cvtColor(image, cv2.COLOR_BGR2RGBA)
    image_pil = Image.fromarray(image_pil)

    # Convert OpenCV mask to PIL mask
    mask_pil = Image.fromarray(mask)

        # Invert the mask
    inverted_mask_pil = ImageOps.invert(mask_pil.convert("L")).convert("RGBA")

    # Combine input image with mask
    masked_image = Image.composite(image_pil, Image.new("RGBA", image_pil.size), mask_pil)
     # Save the masked image
    masked_image.save("masked_image.png")

    return masked_image

def create_variations_in_folder(folder_path, num_variations=10):

    for filename in os.listdir(folder_path):
        # Check if the file is an image
        if filename.lower().endswith((".png", ".jpg", ".jpeg")):
            url = os.path.join(folder_path, filename)
            for i in range(num_variations):
                generate_image_variation(url)
          



@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        prompt = request.form['prompt']
        image = generate_image(prompt)
        image.save('static/generated_image.png')
        return send_file('static/generated_image.png', mimetype='image/png')

    return render_template('index.html')



if __name__ == "__main__":
    #listen_and_recognize_speech_continuously()
    # Test the function with a prompt
    #1prompt = "A futuristic cityscape at sunset"
    #image = generate_image(prompt)
    #image.show()
    #app.run(debug=True)
    #generate_image_variation("screen.jpg")
    #create_image_edit("carré/carré chaumont la ville ou l ennui se conjugue a tous les temps.png")
    #create_variations_in_folder("toedit")
    #process_masks_in_folder("helmo", "cover.jpg")

    prompt =" Please translate this in arabic and keep html, and no escaping as it goes through a json file later. This value is inserted between double quotes.  Escape all double quotes with \  and translate all jobs descriptions : Scientists have hundreds of hours of audio recordings taken from Marine Protected Areas around the world to monitor the success of their restoration efforts.<br /><br />Yet, they lack the time to listen to all of the data.<br /><br />This is where you come in…<br /><br />In just three minutes help marine biologists in their bioacoustics Ocean regeneration work - attempting to bring life back to damaged corals.<br /><ol>    <li>Listen to a healthy coral reef and compare it to the sounds of an unhealthy reef</li>    <li>Train your ear to hear different types of ocean sounds</li>    <li>Click when you hear the sound of a fish on the 30 seconds of ocean audio</li>    <li>Travel to different locations around the world to help our latest mission and become a citizen scientist as we create together the ocean’s next vital study on marine protection</li></ol>How does it help protect reefs?<br /><br />The audio datasets you will hear have not yet been moderated by the scientists: as you listen, your valuable clicks on the audio will be tracked as timestamps and sent to the researchers so they can understand if there are signs of life in their recordings.<br /><br /> This will be used to monitor ecosystem health, track illegal fishing, and measure success at restoration sites.<br /><br />Your clicks will then be used to train computers to listen to fish sounds automatically, and so dramatically accelerate the research.<br /><br /><b>More about the project</b><br /><br />“Calling in our Corals” brings the ability to listen and interact with the ocean to every person's hands on the planet to realize the scientific value of listening as our primary sense under the water, and combines this with new revolutionary scientific research from ‘the Sound of Recovery’ which shows the frequencies we can now play to call corals back to reefs, and dramatically accelerate underwater regeneration.<br /><br />From research by Professor Steve Simpson and Mary Shodipo Created with David Erasmus in collaboration with Google Arts & Culture.<br /><br />Read Professor Steve Simpson’s paper <a href='https://www.researchgate.net/publication/356856367_The_sound_of_recovery_Coral_reef_restoration_success_is_detectable_in_the_soundscape'>‘The Sound of Recovery’</a><ul class=\"credits\">    <li>Parcerisas Clea, Dick Botteldooren, Paul Devos, Debusschere Elisabeth, (Flanders Marine Institute (VLIZ); 2021; Broadband Acoustic Network dataset)</li><li>Dr. Erica Staaterman (Bureau of Ocean Energy Management, University of Miami, Smithsonian Institution)</li><li>Magnus Janson (Edinburgh Napier University)</li><li>Hilary Moors-Murphy (DFO Maritimes Passive Acoustic Monitoring Data, Department of Fisheries and Oceans Canada)</li></ul>Many thanks to Danjugan Island, and Siquijor municipalities : Enrique Villanueva, Maria, Siquijor and Larena, Philippines for research permission.<ul class=\"credits\">  <li>Co Creators: Clare Brooks, Steve Simpson, David Erasmus</li>  <li>UK Production Manager: Alexia Booker</li>  <li>App Development Director: Nathan Goddard</li>  <li>Technical Director Egypt: Zeyad Gohary</li>  <li>Lead Scientist: Mary Shodipo</li>  <li>Technical Director: Martial Geoffre-Rouland</li>  <li>Stand Design & Concept: Shaun Evans</li>  <li>Design: Matthew Dayton</li>  <li>Video Design: George Holliday</li>  <li>Development: Jolyon Gray</li>  <li>3D Design: Dan Shufflebotham</li>  <li>App Consultation: Jack Wild</li>  <li>Concept Development: Kareem Osman</li>  <li>Audio Treatment: Isla Hely</li></ul><h4>Support</h4><ul class=\"support-credits\">   <li>Dick George - Advisor</li>  <li>Chloe Swycher - Advisor</li>  <li>Gail Gallie - Advisor</li>  <li>Elissa Freiha - Advisor</li>  <li>Freya Murray - Advisor</li>  <li>Andy Lindsell - Advisor</li>  <li>Alexander Winter - Design</li>  <li>Andy Agnew - Design</li>  <li>Doug Scott - Finance</li>  <li>Ryan Durance - Finance</li>  <li>Carl Gombrich - Finance</li>  <li>Tom Howsam - Tech</li>  <li>Ben De Silva - Tech</li>  <li>Mary - Filming</li>  <li>Jackson Kingsley - Filming</li>  <li>Carman Del Pardo - Underwater Filming</li>  <li>Louis Cole - Underwater Filming</li>  <li>Jomar Allan - videographer</li>  <li>Mostafa Tamer - Tech</li>  <li>Matt Bonham - Audio consultant</li>  <li>Michelle Chang - UI design</li></ul>"
    call_openai_gpt(prompt)
    #
    word = "coucou"
    #prompt = "I want the letter {letter} over a white background, just one letter, no other, centered. Black and white, swiss typography style"
    #for letter in word:
        #prompt = getPromptWithLetter(prompt, letter)
        #image = generate_image(prompt)
        #image.save(f"{letter}.png")
#Replace your_openai_api_key with your actual API key. The function generate_image(prompt) takes a text prompt and generates an image using DALL-E.

