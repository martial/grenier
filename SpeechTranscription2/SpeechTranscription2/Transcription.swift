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
    var log_port = 0;

    var name = "";
    
    var mic_index : Int = 0;
    var audio_input_ids: [UInt32] = [];

    var app_index : String = "1";
    var log_prefix : String = "Speech 1: ";

    var mic_button : NSPopUpButton?
    
    var text1 : NSTextField?
    var text2 : NSTextField?

    init(name: String, audio_input_ids: [UInt32], app_index: String, mic_button: NSPopUpButton, text1: NSTextField, text2: NSTextField)
    {
        self.name = name;
        self.app_index = app_index;
        self.log_prefix = "Speech "+app_index+": ";

        self.audio_input_ids = audio_input_ids;
        
        self.mic_button = mic_button;

        self.text1 = text1;
        self.text2 = text2;
        
        self.text2?.stringValue = self.status

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
                
                if let log = dictionary["log"] as? [String: Int]
                {
                    if let lp = log["port"] as? Int {
                        log_port = lp;
                    }
                }
                
                //self.server_port_client = dictionary["ports"]["transcript_to_server"]
                //self.server_port_server = dictionary["ports"]["server_to_transcript"]

                // Do something with the dictionary here
            }
        }
        catch
        {
            print("Failed to load JSON file: \(error.localizedDescription)")
        }
        
        oscServer = OSCServer(port:UInt16(server_port_server));
        
        self.oscServer.setHandler { message, timeTag in

            if ( message.addressPattern.description == "/config/" )
            {
                print("---- GET CONFIG")
                
                try? self.oscClient.send(
                    .message(self.log_prefix+"Receive config data", values: []), to: "localhost", port: UInt16(self.log_port))
                
                do {
                    
                    let (st, rt, lg, mi) = try message.values.masked(Float.self, Float.self, String.self, Int.self)
                    self.silence_timeout = Double(st)
                    self.restart_timeout = Double(rt)
                    self.language = lg
                    self.mic_index = mi
                                                            
                    self.restartAll()
                }
                catch
                {
                    print("Error: \(error)")
                    try? self.oscClient.send(
                        .message(self.log_prefix+"Receive config error", values: []), to: "localhost", port: UInt16(self.log_port))
                }
                
            }
            else if ( message.addressPattern.description == "/stopped/" )
            {
                print("---- STOPPED")

                self.transcription = "";
                self.stopRecording()
                Timer.scheduledTimer(withTimeInterval: self.restart_timeout, repeats: false) { timer in
                    self.startRecording()
                }
            }
            else if ( message.addressPattern.description == "/status/"  )
            {
                print("---- STATUS")

                do {
                    
                    let (st) = try message.values.masked(String.self)
                    print(st, self.status)
                    
                    try? self.oscClient.send(
                        .message(self.log_prefix+"Receive status "+st, values: []), to: "localhost", port: UInt16(self.log_port))
                    
                    if (st == "pause")
                    {
                        self.stopRecording();
                    }
                    else if (self.status != "listening" && st == "listening")
                    {
                        self.stopRecording();
                        Timer.scheduledTimer(withTimeInterval: self.restart_timeout, repeats: false) { timer in
                            self.startRecording()
                        }
                    }

                    self.status = st
                    self.text2?.stringValue = self.status

                    
                }
                catch
                {
                    print("Error: \(error)")
                }
            }
        }
        
        var send_address = "/get-config/";
        do { try self.oscServer.start() } catch { print(error) }
        try? self.oscClient.send(
            .message(send_address, values: []),
                to: "localhost",
                port: UInt16(server_port_client)
        )

        restartAll()
    }
    
    func restartAll()
    {
        try? self.oscClient.send(
            .message(self.log_prefix+"Restart all", values: []), to: "localhost", port: UInt16(self.log_port))
        
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
        try? self.oscClient.send(
            .message(self.log_prefix+"Start recording", values: []), to: "localhost", port: UInt16(self.log_port))
        
        text1?.stringValue = "start recording"
                
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
                    print("send stop")
                    
                    try? self.oscClient.send(
                        .message(self.log_prefix+"Send stop message", values: []), to: "localhost", port: UInt16(self.log_port))

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
                
                    print("send speech")
                
                    try? self.oscClient.send(
                        .message(self.log_prefix+"Send speech message, "+self.transcription+", started on processing: "+String(self.started_on_processing), values: []), to: "localhost", port: UInt16(self.log_port))

                    var send_address = "/speech/";
                    try? self.oscClient.send(
                        .message(send_address, values: [self.transcription, self.started_on_processing]),
                            to: "localhost",
                        port: UInt16(self.server_port_client)
                    )
                
                //}
                
                // Réinitialiser le minuteur après l'ajout de chaque audio buffer
                self.restartSilenceTimer()
                
            } else if let error = error {
                //if (self.running) {
                    print("Recognition task error: \(error)")
                
                try? self.oscClient.send(
                    .message(self.log_prefix+"Recognition task error, \(error)", values: []), to: "localhost", port: UInt16(self.log_port))
                //}
            }
        });
        
        
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
             print("Error creating audio format")
             return
         }
         print("Mono format created: \(monoFormat)")

        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        let useRightChannel = app_index != "1" ? true : false;
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            
            
            let channelCount = Int(buffer.format.channelCount)
            let frames = buffer.frameLength
            //print("channel count: \(channelCount), frames: \(frames)")

            if let data = buffer.floatChannelData {
                var audioDataArray: [Float] = []
                
                //print("channel count: \(channelCount)")
                if channelCount == 2 {
                    let start = useRightChannel ? 1 : 0
                    for i in stride(from: start, to: Int(frames) * channelCount, by: 2) {
                        let sample = data.pointee[i]
                        audioDataArray.append(sample)
                    }
                } else if channelCount == 1 {
                    for i in 0..<Int(frames) {
                        let sample = data.pointee[i]
                        audioDataArray.append(sample)
                    }
                }
                
                // Convert the array to AVAudioPCMBuffer and append it to recognitionRequest
                let audioBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(audioDataArray.count))!
                audioBuffer.frameLength = AVAudioFrameCount(audioDataArray.count)
                audioBuffer.floatChannelData?.pointee.initialize(from: &audioDataArray, count: audioDataArray.count)
               // print("Audio buffer prepared")
                
                
                recognitionRequest.append(audioBuffer)
            }
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
                            
                print("send end")
            
                try? self.oscClient.send(
                    .message(self.log_prefix+"Send end speech message, started on processing: "+String(self.started_on_processing), values: []), to: "localhost", port: UInt16(self.log_port))

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
        try? self.oscClient.send(
            .message(self.log_prefix+"Stop recording", values: []), to: "localhost", port: UInt16(self.log_port))
        
        text1?.stringValue = "stop recording"

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
        try? self.oscClient.send(
            .message(self.log_prefix+"Set audio input", values: []), to: "localhost", port: UInt16(self.log_port))
        
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
        print("disable")

        self.transcription = "";
        self.stopRecording()
    }
}
