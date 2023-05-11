//
//  ViewController.swift
//  SpeechTranscription
//
//  Created by Anthony Couret on 24/04/2023.
//
import Cocoa
import AVFoundation

class ViewController: NSViewController {

    @IBOutlet weak var firstMicButton: NSPopUpButton!
    @IBOutlet weak var secondMicButton: NSPopUpButton!
    
    var audioInputIds: [UInt32] = [];

    var transcription : Transcription?
    var transcription2 : Transcription?


    override func viewDidLoad() {
        
        super.viewDidLoad()
                
        listAudioInputs();
        
        transcription = Transcription(name:"channel 1", audio_input: audioInputIds[0]);
        transcription2 = Transcription(name:"channel 2", audio_input: audioInputIds[0]);

        if let transcription = transcription {
            transcription.load()
        }
        if let transcription2 = transcription2 {
            transcription2.load()
        }
    }

    @IBAction func firstMicButtonDidChange(_ sender: NSPopUpButton) {
        // Handle pop-up button selection changes
        if let selectedItem = firstMicButton.selectedItem {
            print("Selected item: \(selectedItem.title)");
            print(sender.indexOfSelectedItem);
            
            if (sender.indexOfSelectedItem == sender.numberOfItems-1)
            {
                if let transcription = transcription {
                    transcription.disable();
                }
            }
            else
            {
                if let transcription = transcription {
                    transcription.setAudioInput(audio_input:audioInputIds[sender.indexOfSelectedItem]);
                }
            }
        }
    }
    
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
                    transcription2.setAudioInput(audio_input:audioInputIds[sender.indexOfSelectedItem]);
                }
            }
        }
    }
    
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
                secondMicButton.addItem(withTitle: String(deviceName) + " — ID: " + String(streamID) );
                
                audioInputIds.append(UInt32(streamID));
            }
        }
        
        firstMicButton.addItem(withTitle: String("Disable"));
        secondMicButton.addItem(withTitle: String("Disable"));
        
        firstMicButton.selectItem(at: 0);
        secondMicButton.selectItem(at: 0);
    }
}
