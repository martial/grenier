from TTS.api import TTS
import sounddevice as sd

# Running a multi-speaker and multi-lingual model

# List available 🐸TTS models and choose the first one
model_name = TTS.list_models()[6]
# Init TTS
print("init")
print(TTS.list_models())
tts = TTS(model_name)

print("yo")
# Run TTS
# ❗ Since this model is multi-speaker and multi-lingual, we must set the target speaker and the language
# Text to speech with a numpy output

# start measuring time
import time
start = time.time()
# run TTS

print()

#wav = tts.tts("This is a test! I am very happy to see you")
tts.tts_to_file(text="hello how are you ??", file_path="output.wav")

sd.stop()
sd.play(wav, samplerate=16000)
sd.wait()







