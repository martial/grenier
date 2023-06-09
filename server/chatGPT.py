from pythonosc import udp_client
from openai.error import InvalidRequestError
import re
import subprocess

class chatGPT:

    conversation_history = []
    transcription = ""
    end_it = False
    status = "waiting"
    class_id = 0
    pause = False

    def __init__(self, ip_address, transcript_port_client, id):

        self.class_id = id
        self.ip_address = ip_address
        self.transcript_port_client = transcript_port_client
        self.transcription_client = udp_client.SimpleUDPClient(ip_address, transcript_port_client)

    def resetHistory(self):
        self.conversation_history = []

    def appendHistory(self,data):
        self.conversation_history.append(data)

    def getHistory(self):
        return self.conversation_history

    def sendConfigMessage(self, data):
        osc_address = "/config/"
        self.transcription_client.send_message(osc_address,data)

    def sendStopMessage(self):
        osc_address = "/stopped/"
        self.transcription_client.send_message(osc_address, [1])

    def sendStatusMessage(self, osc_message):
        osc_address = "/status/"
        self.transcription_client.send_message(osc_address,osc_message)

    def setTranscription(self, transcription):
        self.transcription = transcription

    def getTranscription(self):
        return self.transcription
    
    def clearTranscription(self):
        self.transcription = ""

    def setStatus(self, status):
        self.status = status

    def getStatus(self):
        return self.status

    def setEndIt(self, end_it):
        self.end_it = end_it

    def getEndIt(self):
        return self.end_it
    
    def speak(self, text, language='fr'):
        subprocess.run(["say", "-v", f"{language}", text])

    def callOpenAI(self, prompt, openai, gpt_role, gpt_context, gpt_action, model, gpt_temp, language, playing_mode, talk, send_to_pde, pde_client):

        if playing_mode == "pause" :
            return
        if prompt == '' :
            return
    
        if self.getStatus() == "processing":
            return
        if self.getStatus() == "will_waiting":
            return
        
        self.setStatus("processing")
    
        print("REQUETTE "+str(self.class_id)+" "+prompt)

        if (send_to_pde):
            osc_address = '/chat/'
            osc_message = (" ").encode('utf-8')
            pde_client.send_message(osc_address, osc_message)    
            osc_address = "/status/"
            osc_message = 'requesting'
            pde_client.send_message(osc_address, osc_message)
        
        osc_message = 'processing'
        self.sendStatusMessage(osc_message)

        self.appendHistory({"role": "user", "content": prompt})

        try:
            response = openai.ChatCompletion.create(
                model=model,#gpt-4
                messages=self.getHistory(),
                max_tokens=2048,
                n=1,
                stop=None,
                temperature=gpt_temp,
                stream=True
            )

        except InvalidRequestError as e:
            print(e)
            
            if (send_to_pde):
                osc_message = ("InvalidRequestError — Tokens exceeeded").encode('utf-8')
                osc_address = "/chat/"
                pde_client.send_message(osc_address, osc_message)
            
            self.setStatus("will_waiting")
            self.setEndIt(False)
            self.resetHistory()
            self.appendHistory({"role": "system", "content": gpt_role})
            self.appendHistory({"role": "system", "content": gpt_context})
            self.appendHistory({"role": "system", "content": gpt_action})
            self.callOpenAI(self, prompt, openai, gpt_role, gpt_context, gpt_action, model, gpt_temp, language, playing_mode, talk, send_to_pde, pde_client)
        
            return
        
        except openai.errors.RateLimitError as e:
            print(e)

            osc_message = ("RateLimitError — Server is overloaded").encode('utf-8')
            osc_address = "/chat/"

            if (send_to_pde):
                pde_client.send_message(osc_address, osc_message)
                self.setStatus("will_waiting")
                self.setEndIt(False)

            return

        if (send_to_pde):
            osc_address = "/status/"
            osc_message = 'processing'
            pde_client.send_message(osc_address, osc_message)

        # Process ChatGPT response, word to word
        collected_chunks = []
        collected_messages = []
        last_spoken_phrase = ""

        for chunk in response:

            if ( playing_mode == "pause" ):
                return

            collected_chunks.append(chunk)
            chunk_message = chunk['choices'][0]['delta']
            collected_messages.append(chunk_message)
            full_reply_content = ''.join([m.get('content', '') for m in collected_messages])

            # We stop the processing loop if we get a "stop" message
            if self.getEndIt(): 
                break

            if(talk == 1):
                phrases = re.split(r'[\.\?!]\s*', full_reply_content.strip())
                if len(phrases) > 1 and phrases[-2] != last_spoken_phrase:
                    last_spoken_phrase = phrases[-2]
                    voice = 'Allison' 
                    if language == 'fr':
                        voice = 'Thomas'
                    self.speak(last_spoken_phrase, voice)  # Thomas is a French voice on macOS


            if full_reply_content and send_to_pde:
                # Send the chatGPT response to Pde
                osc_message = full_reply_content.encode('utf-8')
                osc_address = "/chat/"
                pde_client.send_message(osc_address, osc_message)

                #print(full_reply_content)
        
        # Append chatGPT response to history
        full_reply_content = ''.join([m.get('content', '') for m in collected_messages])
        self.appendHistory({"role": "assistant", "content": full_reply_content})

        self.setStatus("will_waiting")
        self.setEndIt(False)