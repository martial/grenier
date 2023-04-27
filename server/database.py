import sqlite3

def createDB() :
    db = sqlite3.connect('database.db')
    # db.execute('CREATE TABLE config (id INTEGER PRIMARY KEY, gpt_role TEXT NOT NULL, gpt_temp REAL NOT NULL)')
    dbc = db.cursor()
    # dbc.execute('INSERT INTO config(id, gpt_role, gpt_temp) VALUES (?,?,?)', (0, "À partir de maintenant tu parles comme un robot", 0.5))
    # dbc.execute('ALTER TABLE config ADD updated INTEGER')
    # dbc.execute('ALTER TABLE config ADD transcription_silence REAL')
    # dbc.execute('ALTER TABLE config ADD transcription_restart REAL')
    # dbc.execute('ALTER TABLE config ADD language TEXT')
    # dbc.execute('UPDATE config SET updated=?, transcription_silence=?, transcription_restart=?, language=?', (0, 2.0, 0.2, "fr"))
    # dbc.execute('ALTER TABLE config ADD gpt_context TEXT')
    # dbc.execute('ALTER TABLE config ADD gpt_action TEXT')
    # dbc.execute('UPDATE config SET gpt_context=?, gpt_action=?', ("", ""))
    db.commit()
    db.close()

def getDBConfig(reset_update=None):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT gpt_role, gpt_context, gpt_action, gpt_temp, updated FROM config')
    result = dbc.fetchone()
    if (reset_update):
        dbc.execute('UPDATE config SET updated=?',(0,))
        db.commit()
    db.close()
    return {
        "gpt_role" : result[0],
        "gpt_context" : result[1],
        "gpt_action" : result[2],
        "gpt_temp" : result[3],
        "updated" : result[4],
    }

def getDBUpdate():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT gpt_role, gpt_context, gpt_action, gpt_temp FROM config WHERE updated = 1')
    result = dbc.fetchone()
    if (result) :
        dbc.execute('UPDATE config SET updated=?',(0,))
        db.commit()
        db.close()
        return {
            "gpt_role" : result[0],
            "gpt_context" : result[1],
            "gpt_action" : result[2],
            "gpt_temp" : result[3]
        }
    else :
        db.close()
        return None

def updateDB(gpt_role, gpt_context, gpt_action, gpt_temp):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET gpt_role=?, gpt_context=?, gpt_action=?, gpt_temp=?, updated=?', (gpt_role, gpt_context, gpt_action, gpt_temp, 1))
    db.commit()
    db.close()

def getDBTransConfig():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT transcription_silence, transcription_restart, language FROM config')
    result = dbc.fetchone()
    db.close()
    return {
        "transcription_silence" : result[0],
        "transcription_restart" : result[1],
        "language" : result[2],
    }

def updateTransDB(transcription_silence, transcription_restart, language):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET transcription_silence=?, transcription_restart=?, language=?', (transcription_silence, transcription_restart, language))
    db.commit()
    db.close()