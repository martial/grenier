#!/bin/sh

#copie de la font dans l'export d'application pde
cp ./nicolas/Cogito-Regular-22.vlw ./nicolas/macos-x86_64/Cogito-Regular-22.vlw 
cp ./server/server-config.json ./SpeechTranscription/DerivedData/SpeechTranscription/Build/Products/Debug/SpeechTranscription.app/Contents/Resources/server-config.json

cp ./server/server-config.json ./nicolas/macos-x86_64/server-config.json
cp ./server/server-config.json ./nicolas/server-config.json

open ./SpeechTranscription/DerivedData/SpeechTranscription/Build/Products/Debug/SpeechTranscription.app
open ./nicolas/macos-x86_64/nicolas.app

sh grenier-2.sh
cd ./server 
source venv/bin/activate
python app.py

pid1=$(pgrep -f "SpeechTranscription")
pid2=$(pgrep -f "nicolas")

trap 'kill $pid1 $pid2; exit' INT


while true; do sleep 1; done
