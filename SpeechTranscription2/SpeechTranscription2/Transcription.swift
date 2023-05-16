import Cocoa
import Speech
import OSCKit
import AVFoundation
import CoreAudio

class Transcription
{
    var speechRecognizer = SFSpeechRecognizer()
    let audioEngine = AVAudioEngine()
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?

    let oscClient = OSCClient()
    var oscServer = OSCServer();

    var transcription = "";

    // Timer pour effacer la variable de transcription après un certain temps de silence
    var silenceTimer: Timer?
            
    var running = false;
    
    var silence_timeout = 2.0;
    var restart_timeout = 0.2;

    var status = "listening";
    var started_on_processing = false;
    
    var language = "fr";
        
    var server_port_client = 0;
    var server_port_server = 0;
    
    var name = "";
    
    var mic_index : Int = 0;
    var audio_input_ids: [UInt32] = [];

    var app_index : String = "1";

    var mic_button : NSPopUpButton?

    init(name: String, audio_input_ids: [UInt32], app_index: String, mic_button: NSPopUpButton)
    {
        self.name = name;
        self.app_index = app_index;
        self.audio_input_ids = audio_input_ids;
        
        self.mic_button = mic_button;
        
        var engine = AVAudioEngine()
        let inputNode: AVAudioInputNode = engine.inputNode
        // get the low level input audio unit from the engine:
        guard let inputUnit: AudioUnit = inputNode.audioUnit else { return }
        // use core audio low level call to set the input device:
        var inputDeviceID: AudioDeviceID = audio_input_ids[mic_index]  // replace with actual, dynamic value
        AudioUnitSetProperty(
            inputUnit, kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global, 0, &inputDeviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
    }
    
    func load()
    {
        guard let path = Bundle.main.path(forResource: "server-config", ofType: "json") else {
            print("Failed to find JSON file")
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            if let dictionary = json as? [String: Any] {
                
                
                var port_id = "ports";
                if (app_index != "1") { port_id += app_index }

                if let ports = dictionary[port_id] as? [String: Int]
                {
                    if let spc = ports["transcript_to_server"] as? Int {
                        server_port_client = spc;
                    }
                    
                    if let sps = ports["server_to_transcript"] as? Int {
                        server_port_server = sps;
                    }
                }
                
                //self.server_port_client = dictionary["ports"]["transcript_to_server"]
                //self.server_port_server = dictionary["ports"]["server_to_transcript"]

                // Do something with the dictionary here
            }
        } catch {
            print("Failed to load JSON file: \(error.localizedDescription)")
        }
        
        oscServer = OSCServer(port:UInt16(server_port_server));
        
        self.oscServer.setHandler { message, timeTag in

            if ( message.addressPattern.description == "/config/" )
            {
                do {
                    
                    let (st, rt, lg, mi) = try message.values.masked(Float.self, Float.self, String.self, Int.self)
                    self.silence_timeout = Double(st)
                    self.restart_timeout = Double(rt)
                    self.language = lg
                    self.mic_index = mi
                                                            
                    self.restartAll()
                                                    
                } catch {
                    print("Error: \(error)")
                }
                
            }
            else if ( message.addressPattern.description == "/stopped/" )
            {
                self.transcription = "";
                self.stopRecording()
                Timer.scheduledTimer(withTimeInterval: self.restart_timeout, repeats: false) { timer in
                    self.startRecording()
                }
            }
            else if ( message.addressPattern.description == "/status/"  )
            {
                do {
                    
                    let (st) = try message.values.masked(String.self)
                    if (self.status == "processing" && st == "listening")
                    {
                        self.stopRecording();
                        Timer.scheduledTimer(withTimeInterval: self.restart_timeout, repeats: false) { timer in
                            self.startRecording()
                        }
                    }

                    self.status = st
                    
                } catch {
                    print("Error: \(error)")
                }
                
            }

        }
        
        var send_address = "/get-config/";
        do { try self.oscServer.start() } catch { print(error) }
        try? self.oscClient.send(
            
            .message(send_address, values: []),
                to: "localhost", // remote IP address or hostname
                port: UInt16(server_port_client) // standard OSC port but can be changed
        )

        restartAll()
    }
    
    func restartAll()
    {
        stopRecording()
        speechRecognizer = nil

        // Do any additional setup after loading the view.
        if (language == "fr")
        {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr_FR"))
        }
        else
        {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
        
        setAudioInput(audio_input_index:self.mic_index)
                
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                if authStatus == .authorized {

                    Timer.scheduledTimer(withTimeInterval: self.restart_timeout, repeats: false) { timer in
                        self.startRecording()
                    }
                }
            }
        }
    }
    
    func startRecording()
    {
        // Setup audio session
//        let audioSession = AVAudioSession.sharedInstance()
//        do {
//            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
//            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
//        } catch {
//            print("Error setting up audio session: \(error.localizedDescription)")
//        }
        
        
        if (status == "processing")
        {
            started_on_processing = true;
        }
        else
        {
            started_on_processing = false;
        }
                
        // Setup recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
        }
        recognitionRequest.shouldReportPartialResults = true

        
        // Setup recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { result, error in

            if ( !self.running ) { return; }
            
            if let result = result
            {
                self.transcription = result.bestTranscription.formattedString
                                                   
                if (self.transcription.contains("Stop") || self.transcription.contains("stop"))
                {
                    
                    var send_address = "/stop/";
                    try? self.oscClient.send(
                        .message(send_address, values: [1]),
                            to: "localhost", // remote IP address or hostname
                        port: UInt16(self.server_port_client) // standard OSC port but can be changed
                    )
                }
                
                //if (self.status == "processing")
                //{
                    /*
                    self.stopRecording()
                    Timer.scheduledTimer(withTimeInterval: self.restart_timeout, repeats: false) { timer in
                        self.startRecording()
                    }
                    */
                //}
                
                //if (!self.started_on_processing)
                //{
                
                    print("SEND SPEECH "+self.name+" ", self.transcription )
                    
                    var send_address = "/speech/";
                    try? self.oscClient.send(
                        .message(send_address, values: [self.transcription, self.started_on_processing]),// self.started_on_processing]),
                            to: "localhost", // remote IP address or hostname
                        port: UInt16(self.server_port_client) // standard OSC port but can be changed
                    )
                
                //}
                
                // Réinitialiser le minuteur après l'ajout de chaque audio buffer
                self.restartSilenceTimer()
                
            } else if let error = error {
                //if (self.running) {
                    print("Recognition task error: \(error)")
                //}
            }
        });
        

        
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        /*
        if let inputDevice = inputDevice {
            do {
                let input = try AVAudioInputNode();//inputDevice: self.inputDevice)
                audioEngine.attach(input)
                audioEngine.connect(input, to: inputNode, format: inputNode.inputFormat(forBus: 0))
            } catch {
                print("Error setting input device: \(error.localizedDescription)")
            }
        }
        */

        /*
        // Start the audio engine
        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
        }
        */
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            
            recognitionRequest.append(buffer)
        }
        
        // Démarrer le minuteur pour effacer la variable de transcription après un certain temps de silence
        self.startSilenceTimer()

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
        }
        
        running = true;
    }

    func restartSilenceTimer()
    {
        // Réinitialiser le minuteur pour effacer la variable de transcription si un nouveau audio buffer est ajouté avant la fin du minuteur
        self.silenceTimer?.invalidate()
        self.startSilenceTimer()
    }

    func startSilenceTimer()
    {
        self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silence_timeout, repeats: false) { timer in
        
            //if ( self.transcription != "" )
            //{
                self.transcription = "";
                self.stopRecording()
                            
                var send_address = "/end-speech/";
                try? self.oscClient.send(
                    .message(send_address, values: [self.started_on_processing]),
                        to: "localhost", // remote IP address or hostname
                    port: UInt16(self.server_port_client) // standard OSC port but can be changed
                )

                
                Timer.scheduledTimer(withTimeInterval: self.restart_timeout, repeats: false) { timer in
                    self.startRecording()
                }
            //}
        }
    }
        
    func stopRecording()
    {
        running = false;

        audioEngine.stop()

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        // Arrêter le minuteur de silence
        self.silenceTimer?.invalidate()
    }
    
    func setAudioInput(audio_input_index: Int)
    {
        self.mic_index = audio_input_index;
        
        if (audio_input_index == -1)
        {
            self.disable();
            if let mic_button = self.mic_button { mic_button.selectItem(at: (self.audio_input_ids.count)) }
        }
        else
        {
            
            self.transcription = "";
            self.stopRecording()
            if let mic_button = self.mic_button { mic_button.selectItem(at: self.mic_index) }

            print("AUDIO ID")
            print(self.audio_input_ids[self.mic_index])

            var engine = AVAudioEngine()
            let inputNode: AVAudioInputNode = engine.inputNode
            // get the low level input audio unit from the engine:
            guard let inputUnit: AudioUnit = inputNode.audioUnit else { return }
            // use core audio low level call to set the input device:
            var inputDeviceID: AudioDeviceID = audio_input_ids[mic_index]  // replace with actual, dynamic value
            AudioUnitSetProperty(
                inputUnit, kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global, 0, &inputDeviceID, UInt32(MemoryLayout<AudioDeviceID>.size))
            
            Timer.scheduledTimer(withTimeInterval: self.restart_timeout, repeats: false) { timer in
                self.startRecording();
                print("start recording")
            }
            
        }

        
        var send_address = "/mic-index/";
        try? self.oscClient.send(
            .message(send_address, values: [self.mic_index]),
                to: "localhost", // remote IP address or hostname
            port: UInt16(self.server_port_client) // standard OSC port but can be changed
        )
    }
    
    func disable()
    {
        self.transcription = "";
        self.stopRecording()
    }
}
