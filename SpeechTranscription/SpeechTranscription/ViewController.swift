//
//  ViewController.swift
//  SpeechTranscription
//
//  Created by Anthony Couret on 24/04/2023.
//

import Cocoa
import Speech
import OSCKit
import AVFoundation


class ViewController: NSViewController {

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
    
    var language = "fr"
        
    var server_port_client = 0;
    var server_port_server = 0;


    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        
        guard let path = Bundle.main.path(forResource: "server-config", ofType: "json") else {
            print("Failed to find JSON file")
            return
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            if let dictionary = json as? [String: Any] {
                
                if let ports = dictionary["ports"] as? [String: Int]
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

            if ( message.addressPattern == "/config/" )
            {
                do {
                    
                    let (st, rt, lg) = try message.values.masked(Float.self, Float.self, String.self)
                    self.silence_timeout = Double(st)
                    self.restart_timeout = Double(rt)
                    self.language = lg
                    
                    self.restartAll()
                                                    
                } catch {
                    print("Error: \(error)")
                }
                
            }
            else if ( message.addressPattern == "/stopped/" )
            {
                self.transcription = "";
                self.stopRecording()
                Timer.scheduledTimer(withTimeInterval: self.restart_timeout, repeats: false) { timer in
                    self.startRecording()
                }
            }
            else if ( message.addressPattern == "/status/" )
            {
                do {
                    
                    let (st) = try message.values.masked(String.self)
                    self.status = st
                    
                } catch {
                    print("Error: \(error)")
                }
            }

        }
        
        do { try self.oscServer.start() } catch { print(error) }
        try? self.oscClient.send(
            
            .message("/get-config", values: []),
                to: "localhost", // remote IP address or hostname
                port: UInt16(server_port_client) // standard OSC port but can be changed
        )
        

        restartAll()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
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
                                   
                print(self.transcription)
                
                if (self.transcription.contains("Stop") || self.transcription.contains("stop"))
                {
                    try? self.oscClient.send(
                        .message("/stop", values: [1]),
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
                    print("SEND SPEECH ", self.transcription )
                    try? self.oscClient.send(
                        .message("/speech", values: [self.transcription, self.started_on_processing]),// self.started_on_processing]),
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
        })
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        
        /*
        let audioDevices = AVCaptureDevice.devices(for: AVMediaType.audio)
        let inputDevice = audioDevices.first
        
        do {
            let input = try AVAudioInputNode.init(device: inputDevice!)
            self.audioEngine.attach(input)
            self.audioEngine.connect(input, to: audioEngine.mainMixerNode, format: inputFormat)
            self.audioEngine.start()

            inputNode.setDeviceInput(input)
        } catch let error as NSError {
            // Handle the error
        }
        
        print(audioDevices)
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
                            
                try? self.oscClient.send(
                    .message("/end-speech", values: [self.started_on_processing]),
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
}
