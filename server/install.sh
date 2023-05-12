#!/bin/bash

# Replace this with the URL of your desired repository
REPOSITORY_URL="https://github.com/yourusername/yourrepository.git"

# Clone the repository
git clone "$REPOSITORY_URL"
REPOSITORY_NAME="$(basename "$REPOSITORY_URL" .git)"
cd "$REPOSITORY_NAME"

# Create a new virtual environment
python -m venv venv

# Activate the virtual environment
source venv/bin/activate

# Install the required packages
pip install -r requirements.txt

# Create a .env file and set environment variables
touch .env
echo "Please add your environment variables to the .env file in the root directory of your project."

# Download the Vosk models
VOSK_MODELS_URL="https://alphacephei.com/vosk/models"
echo "Please download the Vosk models manually from the following URL: $VOSK_MODELS_URL"

echo "Setup complete."
