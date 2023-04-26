import sqlite3

def createDB() :
    db = sqlite3.connect('database.db')
    # db.execute('CREATE TABLE config (id INTEGER PRIMARY KEY, conv_history TEXT NOT NULL, gpt_temp REAL NOT NULL)')
    dbc = db.cursor()
    # dbc.execute('INSERT INTO config(id, conv_history, gpt_temp) VALUES (?,?,?)', (0, "À partir de maintenant tu parles comme un robot", 0.5))
    # dbc.execute('ALTER TABLE config ADD updated INTEGER')
    # dbc.execute('ALTER TABLE config ADD transcription_silence REAL')
    # dbc.execute('ALTER TABLE config ADD transcription_restart REAL')
    # dbc.execute('UPDATE config SET updated=?, transcription_silence=?, transcription_restart=?', (0, 2.0, 0.2))
    db.commit()
    db.close()

def getDBConfig(reset_update=None):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT conv_history, gpt_temp, updated FROM config')
    result = dbc.fetchone()
    if (reset_update):
        dbc.execute('UPDATE config SET updated=?',(0,))
        db.commit()
    db.close()
    return {
        "conv_history" : result[0],
        "gpt_temp" : result[1],
        "updated" : result[2]
    }

def getDBUpdate():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT conv_history, gpt_temp FROM config WHERE updated = 1')
    result = dbc.fetchone()
    if (result) :
        dbc.execute('UPDATE config SET updated=?',(0,))
        db.commit()
        db.close()
        return {
            "conv_history" : result[0],
            "gpt_temp" : result[1]
        }
    else :
        db.close()
        return None

def updateDB(conv_history, gpt_temp):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET conv_history=?, gpt_temp=?, updated=?', (conv_history, gpt_temp, 1))
    db.commit()
    db.close()

def getDBTransConfig():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT transcription_silence, transcription_restart FROM config')
    result = dbc.fetchone()
    db.close()
    return {
        "transcription_silence" : result[0],
        "transcription_restart" : result[1]
    }

def updateTransDB(transcription_silence, transcription_restart):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET transcription_silence=?, transcription_restart=?', (transcription_silence, transcription_restart))
    db.commit()
    db.close()