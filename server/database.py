import sqlite3
import json

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
    #dbc.execute('ALTER TABLE config ADD talk INTEGER')
    # dbc.execute('ALTER TABLE config ADD model TEXT')
    # dbc.execute('UPDATE config SET talk=?, model=?', (1,"gpt-4"))
    # dbc.execute('ALTER TABLE config ADD playing_mode TEXT')
    # dbc.execute('ALTER TABLE config ADD reset INTEGER')
    # dbc.execute('UPDATE config SET playing_mode=?, reset=?', ("play",0))
    #dbc.execute('ALTER TABLE config ADD playing_mode_2 TEXT')
    #dbc.execute('UPDATE config SET playing_mode_2=?', ("play",))
    #dbc.execute('ALTER TABLE config ADD mic_index_1 INTEGER')
    #dbc.execute('ALTER TABLE config ADD mic_index_2 INTEGER')
    #dbc.execute('UPDATE config SET mic_index_1=?, mic_index_2=?', (0,0))
    # dbc.execute('ALTER TABLE config ADD toggle_listen INTEGER')
    #dbc.execute('UPDATE config SET toggle_listen=0')
    #dbc.execute('ALTER TABLE config ADD reset_2 INTEGER')
    #dbc.execute('ALTER TABLE config ADD stop INTEGER')
    #dbc.execute('ALTER TABLE config ADD stop_2 INTEGER')
    #dbc.execute('UPDATE config SET reset_2=?, stop=?, stop_2=?', (0,0,0))

    #db.execute('CREATE TABLE prompt (id INTEGER PRIMARY KEY, slot INTEGER NOT NULL, title TEXT NOT NULL, gpt_role TEXT NOT NULL, gpt_context TEXT NOT NULL, gpt_action TEXT NOT NULL)')

    db.commit()
    db.close()

def getDBConfig(reset_update=None):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT gpt_role, gpt_context, gpt_action, gpt_temp, updated, talk FROM config')
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
    dbc.execute('SELECT transcription_silence, transcription_restart, language, talk, mic_index_1, mic_index_2, model, toggle_listen FROM config')
    result = dbc.fetchone()
    db.close()
    
    return {
        "transcription_silence" : result[0],
        "transcription_restart" : result[1],
        "language" : result[2],
        "talk" : result[3],
        "mic_index_1" : result[4],
        "mic_index_2" : result[5],
        "model" : result[6],
        "toggle_listen" : result[7]
    } 

def updateTransDB(transcription_silence, transcription_restart, language, talk, toggle_listen, model):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    #print(transcription_silence, transcription_restart, language, talk)
    dbc.execute('UPDATE config SET transcription_silence=?, transcription_restart=?, language=?, talk=?, toggle_listen=?, model=?', (transcription_silence, transcription_restart, language, talk, toggle_listen, model))
    db.commit()
    db.close()

def resetDBModes():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET playing_mode=?, reset=?, reset_2=?, updated=?', ("play", 0, 0, 0))
    db.commit()
    db.close()

def setDBPlayingMode(playing_mode):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET playing_mode=?, playing_mode_2=?', (playing_mode,playing_mode))
    db.commit()
    db.close()

def getDBPlayingMode():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT playing_mode, playing_mode_2 FROM config')
    result = dbc.fetchone()
    db.close()
    return {
        "playing_mode" : result[0],
        "playing_mode_2" : result[1]
    }

def setDBPlayingMode1(playing_mode):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET playing_mode=?', (playing_mode,))
    db.commit()
    db.close()

def getDBPlayingMode1():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT playing_mode FROM config')
    result = dbc.fetchone()
    db.close()
    return result[0]

def setDBPlayingMode2(playing_mode):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET playing_mode_2=?', (playing_mode,))
    db.commit()
    db.close()

def getDBPlayingMode2():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT playing_mode_2 FROM config')
    result = dbc.fetchone()
    db.close()
    return result[0]

def setDBReset(reset):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET reset=?, reset_2=?', (reset,reset))
    db.commit()
    db.close()

def getDBReset():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT reset, reset_2 FROM config')
    result = dbc.fetchone()
    db.close()
    return {
        "reset" : result[0],
        "reset_2" : result[1]
    }

def setDBReset1(reset):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET reset=?', (reset,))
    db.commit()
    db.close()

def setDBReset2(reset):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET reset_2=?', (reset,))
    db.commit()
    db.close()

def getDBReset1():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT reset FROM config')
    result = dbc.fetchone()
    db.close()
    return result[0]

def getDBReset2():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT reset_2 FROM config')
    result = dbc.fetchone()
    db.close()
    return result[0]

def setDBStop(stop):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET stop=?, stop_2=?', (stop,stop))
    db.commit()
    db.close()

def getDBStop():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT stop, stop_2 FROM config')
    result = dbc.fetchone()
    db.close()
    return {
        "stop" : result[0],
        "stop_2" : result[1]
    }

def setDBStop1(stop):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET stop=?', (stop,))
    db.commit()
    db.close()

def setDBStop2(stop):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET stop_2=?', (stop,))
    db.commit()
    db.close()

def getDBStop1():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT stop FROM config')
    result = dbc.fetchone()
    db.close()
    return result[0]

def getDBStop2():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT stop_2 FROM config')
    result = dbc.fetchone()
    db.close()
    return result[0]

def setDBMicIndex1(mic_index):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET mic_index_1=?', (mic_index,))
    db.commit()
    db.close()

def setDBMicIndex2(mic_index):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('UPDATE config SET mic_index_2=?', (mic_index,))
    db.commit()
    db.close()

def insertPromptDB(slot, title, gpt_role, gpt_context, gpt_action):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute("INSERT INTO prompt (slot, title, gpt_role, gpt_context, gpt_action) VALUES (?,?,?,?,?)",(slot, title, gpt_role, gpt_context, gpt_action))
    db.commit()
    id = dbc.lastrowid
    db.close()
    return id

def updatePromptDB(id, slot, title, gpt_role, gpt_context, gpt_action):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute("UPDATE prompt SET slot=?, title=?, gpt_role=?, gpt_context=?, gpt_action=? WHERE id="+id+"",(slot, title, gpt_role, gpt_context, gpt_action))
    db.commit()
    db.close()

def deletePromptDB(id):
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute("DELETE from prompt where id=?", (id,))
    db.commit()
    db.close()

def getPromptDB():
    db = sqlite3.connect('database.db')
    dbc = db.cursor()
    dbc.execute('SELECT * FROM prompt')
    result = dbc.fetchall()
    db.close()
    return json.dumps(result)


