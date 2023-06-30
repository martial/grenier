## Flask App

This is a Flask app that does [insert purpose of app here].

To install this app, you will need to set up a virtual environment and install the required packages. Here are the steps to follow:

- Clone the repository to your local machine.
- Create a new virtual environment using `python -m venv venv`.
- Activate the virtual environment using `source venv/bin/activate` on Unix/MacOS, or .`\venv\Scripts\activate` on Windows.
- Install the required packages using `pip install -r requirements.txt`
- Create a .env file in the root directory of your project, and set any environment variables required by your app.
  — Download the Vosk models here : https://alphacephei.com/vosk/models and put them in server/models
  The app use vosk-model-fr-0.22
  — Export the Nicolas Pde App in Processing > macos-x86_64
  — Build SpeechTranscription App in SpeechTranscription/DerivedData
  . Be sure to have an updated OS/Xcode
  . File > Add Packages > Paste https://github.com/orchetect/OSCKit
  . then https://github.com/robbiehanson/CocoaAsyncSocket
  . then https://github.com/orchetect/SwiftASCII
  . If you want to create a new project > Interface Storyboard > macOS App
  . Select your Target > Signing & Capabilities > check "Incoming Connections", "Outgoing Connections", "Audio Input"
  . Select your Target > Info > add "Privacy - Speech Recognition Usage Description" and "Privacy - Microphone Usage Description"

SECRET_KEY=your-secret-key-here

## Installation

Install Supervisor on macOS using Homebrew:

\```bash
brew install supervisor
\```

## Running the Applications

Start `supervisord` with the provided configuration file:

\```bash
supervisord -c ./server-supervisor.conf
\```

## Monitoring the Applications

You can monitor the applications using `supervisorctl`. To check the status of the applications, run:

\```bash
supervisorctl -c ./server-supervisor.conf status
\```

## Accessing the Supervisor Web Interface

You can also monitor the applications using Supervisor's web interface. Just open your web browser and navigate to `http://localhost:2222`.

## Stopping supervisord

To stop the supervisord process, you can run the following script:

\```bash
#!/bin/bash
PID=$(ps -ef | grep 'supervisord' | grep -v grep | awk '{print $2}')
if [[-n $PID]]; then
echo "Killing supervisord process with PID $PID"
kill $PID
else
echo "No supervisord process found"
fi
\```

To execute this script, save it to a file, for example `kill_supervisord.sh`, give it execution permissions with `chmod +x kill_supervisord.sh`, and run it with `./kill_supervisord.sh`.

Contact

If you have any questions or comments about this app, please contact Martial Geoffre-Rouland at [insert contact information here].
