#!/bin/sh

current_path=$(dirname "$0")
cd $current_path

cp -Rf ./applis/transcript-apple/SpeechTranscription2.app ./applis/transcript-apple/SpeechTranscription2-2.app

cp ./server/server-config.json ./applis/transcript-apple/SpeechTranscription2.app/Contents/Resources/server-config.json
cp ./server/server-config.json ./applis/transcript-apple/SpeechTranscription2-2.app/Contents/Resources/server-config.json

cp ./server/server-config.json ./applis/viewer-pde/server-config.json

open ./applis/transcript-apple/SpeechTranscription2.app --args 1
open ./applis/transcript-apple/SpeechTranscription2-2.app --args 2

open ./applis/viewer-pde/nicolas.app

cd ./server 
source venv/bin/activate
python app.py

pid1=$(pgrep -d";" -f "SpeechTranscription2");
pid2=$(pgrep -f "nicolas")
trap 'kill $pid1; $pid2; exit' INT


while true; do sleep 1; done
