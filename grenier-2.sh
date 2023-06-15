#!/bin/sh

#copie de la font dans l'export d'application pde
cp ./nicolas/Cogito-Regular-22.vlw ./nicolas/macos-x86_64/Cogito-Regular-22.vlw 
#copie du fichier de config server dans l'application pde
cp ./server/server-config.json ./nicolas/macos-x86_64/server-config.json
cp ./server/server-config.json ./nicolas/server-config.json

# duplication de l'application de transcription
cp -Rf ./SpeechTranscription2/DerivedData/SpeechTranscription2/Build/Products/Debug/SpeechTranscription2.app ./SpeechTranscription2/DerivedData/SpeechTranscription2/Build/Products/Debug/SpeechTranscription2-2.app
#copie du fichier de config server dans les application de transcription
cp ./server/server-config.json ./SpeechTranscription2/DerivedData/SpeechTranscription2/Build/Products/Debug/SpeechTranscription2.app/Contents/Resources/server-config.json
cp ./server/server-config.json ./SpeechTranscription2/DerivedData/SpeechTranscription2/Build/Products/Debug/SpeechTranscription2-2.app/Contents/Resources/server-config.json
# execution de l'application de transcription pour deux micros / deux instances
open ./SpeechTranscription2/DerivedData/SpeechTranscription2/Build/Products/Debug/SpeechTranscription2.app --args 1
#open ./SpeechTranscription2/DerivedData/SpeechTranscription2/Build/Products/Debug/SpeechTranscription2-2.app --args 2

# execution de l'application pde
#open ./nicolas/macos-x86_64/nicolas.app

#cd ./server 
#source venv/bin/activate
#python app.py

# recuperation des pids pour kill les app lorsque que l'on quitte le terminal
#pid1=$(pgrep -d";" -f "SpeechTranscription2");
#pid2=$(pgrep -f "nicolas")
#trap 'kill $pid1; $pid2; exit' INT

#while true; do sleep 1; done
