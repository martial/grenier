//
//  ViewController.swift
//  SpeechTranscription
//
//  Created by Anthony Couret on 24/04/2023.
//
import Cocoa
import AVFoundation
import Foundation

class ViewController: NSViewController {

    let arguments = CommandLine.arguments

    
    @IBOutlet weak var firstMicButton: NSPopUpButton!
    //@IBOutlet weak var secondMicButton: NSPopUpButton!
    
    /*
    struct Config: Codable { var microphone: UInt32 }
    var config = Config(microphone: 1000)
    */
    
    var audio_input_ids: [UInt32] = [];

    var transcription : Transcription?
    //var transcription2 : Transcription?
    
    var app_index = 1;
    var app_index_str = "1";

    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        for (index, argument) in arguments.enumerated() {
            if let index = Int(argument)
            {
                app_index = index;
                app_index_str = argument;
            }
        }
        
        /*
        // Retrieve the index of the "--name" parameter
        if let indexArg = arguments.firstIndex(of: "--args") {
            // Retrieve the value following the "--name" parameter
            if let index = Int(arguments[indexArg + 1]) { mic_index = index; }
            print("Index: \(index)")
        }
        */
        
        listAudioInputs();

        transcription = Transcription(name:"channel 1", audio_input_ids: audio_input_ids, app_index: app_index_str, mic_button: firstMicButton);
        //transcription2 = Transcription(name:"channel 2", audio_input: audioInputIds);


        if let transcription = transcription {
            transcription.load()
        }
        /*
        if let transcription2 = transcription2 {
            transcription2.load()
        }
         */
    }

    @IBAction func firstMicButtonDidChange(_ sender: NSPopUpButton) {
        // Handle pop-up button selection changes
        if let selectedItem = firstMicButton.selectedItem {
            print("Selected item: \(selectedItem.title)");
            print(sender.indexOfSelectedItem);
            
            /*
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            guard let executableURL = Bundle.main.executableURL else {
                fatalError("Impossible d'obtenir le chemin de l'exécutable.")
            }
            
            let applicationURL = executableURL.deletingLastPathComponent()
            let fileURL = applicationURL.appendingPathComponent("config-speech.json")
            print(fileURL.path)
            */
            
            let fileManager = FileManager.default

            
            if (sender.indexOfSelectedItem == sender.numberOfItems-1)
            {
                if let transcription = transcription {
                    transcription.setAudioInput(audio_input_index:-1);
                    //config.microphone = 1000;
                }
            }
            else
            {
                if let transcription = transcription {
                    transcription.setAudioInput(audio_input_index:sender.indexOfSelectedItem);
                    //config.microphone = UInt32(sender.indexOfSelectedItem);
                }
            }
            
        
            /*
            if let jsonData = try? encoder.encode(config) {
                // Écrire le contenu JSON dans un fichier
                let url = URL(fileURLWithPath: fileURL.path)
                do {
                    try jsonData.write(to: url)

                } catch {
                    // Handle error
                    print("error writing");
                }
            }
            */
        }
    }
    
    /*
    @IBAction func secondMicButtonDidChange(_ sender: NSPopUpButton) {
        // Handle pop-up button selection changes
        if let selectedItem = secondMicButton.selectedItem {
            print("Selected item: \(selectedItem.title)");
            print(sender.indexOfSelectedItem);
            
            if (sender.indexOfSelectedItem == sender.numberOfItems-1)
            {
                if let transcription2 = transcription2 {
                    transcription2.disable();
                }
            }
            else
            {
                if let transcription2 = transcription2 {
                    transcription2.setAudioInput(audio_input_index:sender.indexOfSelectedItem);
                }
            }
        }
    }
     */
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func listAudioInputs()
    {
        // Get the IDs of all available audio devices
        var deviceIDs: [AudioDeviceID] = []
        var propertySize: UInt32 = 0
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMaster
        )
        var result = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        if result != 0 {
            print("Error getting property data size: \(result)")
        } else {
            let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
            deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
            result = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                &propertySize,
                &deviceIDs
            )
            if result != 0 {
                print("Error getting device IDs: \(result)")
            }
        }

        // Iterate through each audio device and print its input streams
        for deviceID in deviceIDs {
            // Get the device name
            var deviceName: CFString = "" as CFString
            propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMaster
            )
            propertySize = UInt32(MemoryLayout<CFString>.size)
            result = AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                &deviceName
            )
            if result != 0 {
                print("Error getting device name: \(result)")
                continue
            }

            // Check if the device has input streams
            var streamIDs: [AudioStreamID] = []
            propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: 0
            )
            propertySize = 0
            result = AudioObjectGetPropertyDataSize(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize
            )
            if result != 0 {
                print("Error getting stream IDs for device '\(deviceName)': \(result)")
                continue
            } else {
                let streamCount = Int(propertySize) / MemoryLayout<AudioStreamID>.size
                streamIDs = [AudioStreamID](repeating: 0, count: streamCount)
                result = AudioObjectGetPropertyData(
                    deviceID,
                    &propertyAddress,
                    0,
                    nil,
                    &propertySize,
                    &streamIDs
                )
                if result != 0 {
                    print("Error getting stream IDs for device '\(deviceName)': \(result)")
                    continue
                }
            }

            // Print the device name and input stream IDs
            print("Device '\(deviceName)' input streams:")
            for streamID in streamIDs {
                print("- Stream ID: \(streamID)")
                // Add items to the pop-up button
                firstMicButton.addItem(withTitle: String(deviceName) + " — ID: " + String(streamID));
                //secondMicButton.addItem(withTitle: String(deviceName) + " — ID: " + String(streamID) );
                
                audio_input_ids.append(UInt32(streamID));
            }
        }
        
        firstMicButton.addItem(withTitle: String("Disable"));
        //secondMicButton.addItem(withTitle: String("Disable"));
        
        firstMicButton.selectItem(at: 0);
        //secondMicButton.selectItem(at: 0);
    }
}
