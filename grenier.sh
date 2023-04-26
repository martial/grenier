#!/bin/sh

cp ./nicolas/Cogito-Regular-22.vlw ./nicolas/macos-x86_64/Cogito-Regular-22.vlw 

open ./SpeechTranscription/DerivedData/SpeechTranscription/Build/Products/Debug/SpeechTranscription.app
open ./nicolas/macos-x86_64/nicolas.app

cd ./server 
source venv/bin/activate
python app.py

pid1=$(pgrep -f "SpeechTranscription")
pid2=$(pgrep -f "nicolas")

trap 'kill $pid1 $pid2; exit' INT

while true; do sleep 1; done