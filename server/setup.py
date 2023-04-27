from setuptools import setup

APP = ['app.py']
DATA_FILES = []
OPTIONS = {
    'packages': ['openai', 'requests', 'flask', 'dotenv', 'flask_scss', 'pythonosc'],
    'resources': ['./templates', './static', './models', './static'],
}
setup(
    app=APP,
    data_files=DATA_FILES,
    options={'py2app': OPTIONS},
    setup_requires=['py2app']
)