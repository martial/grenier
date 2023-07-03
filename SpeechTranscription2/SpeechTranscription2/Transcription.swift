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
    var autoStopTimer : Timer?
            
    var running = false;
    var isAudioOpen = false;
    
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
    
    var isRightChannelOn : Bool = false;
    var isLeftChannelOn : Bool = false;


    init(name: String, audio_input_ids: [UInt32], app_index: String, mic_button: NSPopUpButton, text1: NSTextField)
    {
        self.name = name;
        self.app_index = app_index;
        self.log_prefix = "Speech "+app_index+": ";

        self.audio_input_ids = audio_input_ids;
        
        self.mic_button = mic_button;

        self.text1 = text1;
        

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
    
    func setPorts(mic_id:Int ) {
        
        guard let path = Bundle.main.path(forResource: "server-config", ofType: "json") else {
            print("Failed to find JSON file")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            if let dictionary = json as? [String: Any] {
                var port_id = "ports";
                if (mic_id == 1) { port_id = "ports2" }

                if let ports = dictionary[port_id] as? [String: Int]
                {
                    if let spc = ports["transcript_to_server"] {
                        server_port_client = spc;
                    }
                }
            }
        }
        catch
        {
            print("Failed to load JSON file: \(error.localizedDescription)")
        }
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
                if let ports = dictionary[port_id] as? [String: Int] {
                    if let sps = ports["server_to_transcript"] {
                        server_port_server = sps;
                       
                    }
                }
                
                if let log = dictionary["log"] as? [String: Int] {
                    if let lp = log["port"] {
                        log_port = lp;
                    }
                }

            }
        }
        catch {
            print("Failed to load JSON file: \(error.localizedDescription)")
        }
        
        setPorts(mic_id: 0)
        oscServer = OSCServer(port:UInt16(server_port_server));
        
        self.oscServer.setHandler { message, timeTag in
            
            print( message.addressPattern.description)
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
        if (language == "fr") {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr_FR"))
        }
        else {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
        
        setAudioInput(audio_input_index:self.mic_index)
        
        print("restartAll")
                
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
    
    func writeBufferToFile(buffer: AVAudioPCMBuffer, fileURL: URL) {
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forWriting: fileURL, settings: buffer.format.settings)
        } catch {
            print("Error creating audio file: \(error)")
            return
        }

        do {
            try audioFile.write(from: buffer)
        } catch {
            print("Error writing to audio file: \(error)")
        }
    }
    
    func startRecording()
    {
        try? self.oscClient.send(
            .message(self.log_prefix+"Start recording", values: []), to: "localhost", port: UInt16(self.log_port))
        
                
        if (status == "processing"){
            started_on_processing = true;}
        else{
            started_on_processing = false;
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        
        print("install tap")
        inputNode.reset()
        inputNode.removeTap(onBus: 0)
        
        let isInitated = self.recognitionTask != nil
      
        
        print("check if ok to go")
        print(isInitated)
        print(self.isAudioOpen)

        // create instance if audio is open
        if(self.isAudioOpen && !isInitated) {
            
            
            
            

            // Setup recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
            }
            recognitionRequest.shouldReportPartialResults = true
            
            DispatchQueue.main.async {
                self.text1?.stringValue = "Listening"
            }
            
            
            // Setup recognition task
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { [self] result, error in
                
                //if ( !self.running ) { return; }
                
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
                    
                   
                    print(self.transcription)
                    
                    try? self.oscClient.send(
                        .message(self.log_prefix+"Send speech message, "+self.transcription+", started on processing: "+String(self.started_on_processing), values: []), to: "localhost", port: UInt16(self.log_port))
                    
                    let send_address = "/speech/";
                    try? self.oscClient.send(
                        .message(send_address, values: [self.transcription, self.started_on_processing]),
                        to: "localhost",
                        port: UInt16(self.server_port_client)
                    )
                   
                    self.restartSilenceTimer()
                    
                    
                } else if let error = error {
                    //if (self.running) {
                    print("Recognition task error: \(error)")
                    print("There was an error: \(error.localizedDescription)")
                    
                    DispatchQueue.main.async {
                        self.text1?.stringValue = "On hold (e)"
                    }
                    
                    
                    self.startRecording()
                    
                    if speechRecognizer?.isAvailable == false {
                        print("Speech recognizer not available")
                    }
                    
                    let authStatus = SFSpeechRecognizer.authorizationStatus()
                    switch authStatus {
                    case .notDetermined:
                        print("not determined")
                        // Authorization has not been determined.
                    case .denied:
                        print("denied")
                        
                        // The user has denied authorization.
                    case .restricted:
                        print("restricted")
                        // The device is not permitted to access Speech Recognition.
                    case .authorized:
                        print("ok")
                        
                        // The user has authorized access to speech recognition.
                    default:
                        break
                    }
                    
                    try? self.oscClient.send(
                        .message(self.log_prefix+"Recognition task error, \(error)", values: []), to: "localhost", port: UInt16(self.log_port))
                    //}
                }
            });
        }
        
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1) else {
             print("Error creating audio format")
             return
         }

        // Setup audio engine
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [self] buffer, _ in
            
            let channelCount = Int(buffer.format.channelCount)
            var isLeftOn = true
            var isRightOn = true
                        
            if(channelCount > 1) {
                let frames = buffer.frameLength
                
                let leftChannelData = buffer.floatChannelData![0]
                let rightChannelData = buffer.floatChannelData![1]
                
                var leftVolume: Float = 0.0
                var rightVolume: Float = 0.0
                
                // Calculate the volume for the left channel
                for frame in 0..<Int(frames) {
                    let leftData = leftChannelData[frame]
                    leftVolume += leftData * leftData
                    
                    let rightData = rightChannelData[frame]
                    rightVolume += rightData * rightData
                }
                
                leftVolume /= Float(frames)
                leftVolume = sqrt(leftVolume)
                
                rightVolume /= Float(frames)
                rightVolume = sqrt(rightVolume)
                
                leftVolume *= 2.0
                rightVolume *= 2.0
                
                
                isLeftOn = leftVolume > 0.00005
                isRightOn = rightVolume > 0.00005
                
                print(isLeftOn)
                
                DispatchQueue.main.async {
                    let send_address = "/mic-volume/";
                    try? self.oscClient.send(
                        .message(send_address, values: [leftVolume, rightVolume]),
                            to: "localhost",
                        port: 1234
                        )
                   
                }
                
                
                if(!self.isLeftChannelOn && isLeftOn ) {
                    self.isLeftChannelOn = true;
                    DispatchQueue.main.async {
                        let send_address = "/mic-status/";
                        try? self.oscClient.send(
                            .message(send_address, values: [0, self.isLeftChannelOn]),
                                to: "localhost",
                            port: 1234
                            )
                    }
                    
                    self.isAudioOpen = true
                    self.startRecording();
                    autoStopTimer?.invalidate()
                    autoStopTimer = nil
                    autoStopTimer = Timer.scheduledTimer(withTimeInterval: 50, repeats: false) { timer in
                        self.stopRecording()
                        self.startRecording();
                    }
                    
                } else
                
                if(self.isLeftChannelOn && !isLeftOn) {
                    self.isLeftChannelOn = false;
                    DispatchQueue.main.async {
                        let send_address = "/mic-status/";
                        try? self.oscClient.send(
                            .message(send_address, values: [0, self.isLeftChannelOn]),
                                to: "localhost",
                            port: 1234
                            )
                    }
                } else
                
                
                if(!self.isRightChannelOn && isRightOn ) {
                    self.isRightChannelOn = true;
                    DispatchQueue.main.async {
                        
                        self.transcription = "";

                        var send_address = "/end-speech/";
                        try? self.oscClient.send(
                            .message(send_address, values: [self.started_on_processing]),
                                to: "localhost", // remote IP address or hostname
                            port: UInt16(self.server_port_client) // standard OSC port but can be changed
                        )

                        
                        send_address = "/mic-status/";
                        try? self.oscClient.send(
                            .message(send_address, values: [1, self.isRightChannelOn]),
                                to: "localhost",
                            port: 1234
                            )
                        self.isAudioOpen = false
                        self.setPorts(mic_id: self.isRightChannelOn ? 1 : 0 )
                        
                        
                        self.autoStopTimer?.invalidate()
                        self.autoStopTimer = nil
                        print("end speech it and stop")
                        self.stopRecording()
                        print("start")

                       
                    }
                } else
                if(self.isRightChannelOn && !isRightOn) {
                    DispatchQueue.main.async {
                        self.isRightChannelOn = false;
                        let send_address = "/mic-status/";
                        try? self.oscClient.send(
                            .message(send_address, values: [1, self.isRightChannelOn]),
                                to: "localhost",
                            port: 1234
                            )
                        self.setPorts(mic_id: self.isRightChannelOn ? 1 : 0 )
                         
                    }
                    
                }
                
            }

            // get volume
            
            let frames = buffer.frameLength
            //print("channel count: \(channelCount), frames: \(frames)")

            if let data = buffer.floatChannelData {
                var audioDataArray: [Float] = []
                
                //print("channel count: \(channelCount)")
                if channelCount == 2 {
                   let framesInt = Int(frames)
                   let start = self.isRightChannelOn ? framesInt : 0
                   let end = self.isRightChannelOn ? framesInt * 2 : framesInt
                   for i in start..<end {
                       let sample = data.pointee[i]
                       audioDataArray.append(sample)
                   }
                } else if channelCount == 1 {
                    for i in 0..<Int(frames) {
                        let sample = data.pointee[i]
                        audioDataArray.append(sample)
                    }
                }
                

                let monoRecordingFormat = AVAudioFormat(standardFormatWithSampleRate: recordingFormat.sampleRate, channels: 1)

                guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: monoRecordingFormat!, frameCapacity: AVAudioFrameCount(audioDataArray.count)) else {
                    return
                }
                
                audioBuffer.frameLength = AVAudioFrameCount(audioDataArray.count)
                audioBuffer.floatChannelData?.pointee.initialize(from: &audioDataArray, count: audioDataArray.count)
               // print("Audio buffer prepared")
                //let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                //let timestamp = Date().timeIntervalSince1970
                //let fileName = "audioData_\(timestamp).caf"
                //let fileURL = documentsPath.appendingPathComponent(fileName)
                //self.writeBufferToFile(buffer: audioBuffer, fileURL: fileURL)
                //print(fileURL)
                
               // if( self.isAudioOpen ) {
                    self.recognitionRequest?.append(audioBuffer)
                //}
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
                //self.stopRecording()
                
                /*
                self.transcription = "";

                //print("send end")
            
                try? self.oscClient.send(
                    .message(self.log_prefix+"Send end speech message, started on processing: "+String(self.started_on_processing), values: []), to: "localhost", port: UInt16(self.log_port))
                
            
                var send_address = "/end-speech/";
                try? self.oscClient.send(
                    .message(send_address, values: [self.started_on_processing]),
                        to: "localhost", // remote IP address or hostname
                    port: UInt16(self.server_port_client) // standard OSC port but can be changed
                )
             
             */

             
            //}
        }
    }
        
    func stopRecording()
    {
        try? self.oscClient.send(
            .message(self.log_prefix+"Stop recording", values: []), to: "localhost", port: UInt16(self.log_port))
        
        text1?.stringValue = "On hold"

        //running = false;
        
        print("about to stop")
        DispatchQueue.main.async { [unowned self] in
            
           
            guard let task = self.recognitionTask else {
                print("quit")
                return

            }
            
            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            
            recognitionRequest?.endAudio()
            audioEngine.stop()
            
           
            task.cancel()
            task.finish()

            var close = true
            guard let task = recognitionTask else {
                close = false
                return
            }
            
            if(close) {
                print("closing")
                task.cancel()
                //task.finish()
            }
            
            print("about to stop2")

            recognitionRequest = nil
            recognitionTask = nil

            // Arrêter le minuteur de silence
            self.silenceTimer?.invalidate()
            self.startRecording();

        }

     
     
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

            let engine = AVAudioEngine()
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

        
        let send_address = "/mic-index/";
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
