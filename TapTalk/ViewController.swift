//
//  ViewController.swift
//  TapTalk
//
//  Created by Arsenkin Bogdan on 8/7/19.
//  Copyright © 2019 Arsenkin Bogdan. All rights reserved.
//

import UIKit
import Speech
import SwiftyJSON
import AVFoundation

class ViewController: UIViewController, SFSpeechRecognizerDelegate {
	
	let audioEngine = AVAudioEngine()
	let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
	let request = SFSpeechAudioBufferRecognitionRequest()
	var recognitionTask: SFSpeechRecognitionTask?
	var speechSynthesizer = AVSpeechSynthesizer()
	
	var selectedLanguage = "it"
	
	@IBOutlet weak var textLabel: UILabel!
	@IBOutlet var languageButtons: [UIButton]!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		speechRecognizer?.delegate = self
		textLabel.text = "HOLD\nTO\nSTART\nRECORDING"
		
	}
	
	@IBAction func longGestureRecognizer(_ sender: UILongPressGestureRecognizer) {
		var textForTranslation = String()
		//MARK: - Start Speech Recognition on hold
		if sender.state == .began {
			textLabel.text = "Start speaking"
			
			recordAndRecognizeSpeech()
			
			print("Long gesture began")
		}
		
		//MARK: - Stop Speech Recognition on release
		if sender.state == .ended {
			
			textForTranslation = textLabel.text!
			
			print("Long gesture ended")
			
			if textLabel.text == "Start speaking" {
				
			} else {
				//MARK: - Send data to translation API
				let translateTo = self.selectedLanguage.lowercased()
				let requestString = "https://api.mymemory.translated.net/get?q=\(textForTranslation)&langpair=en|\(translateTo)"
				let encodedString = requestString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
				guard let url = URL(string: encodedString) else {
					print("URL is not valid!")
					return
				}
				self.requestTranslationData(with: url)
			}
		}
	}
	
	@IBAction func didSelectLanguage(_ sender: UIButton) {
		allDeselected()
		selectLanguage(button: sender)
		
		print(selectedLanguage)
	}
	
	func allDeselected(){
		for button in languageButtons{
			button.setTitleColor(.white, for: .normal)
		}
	}
	
	func selectLanguage(button:UIButton){
		button.setTitleColor(.yellow, for: .normal)
		selectedLanguage = button.titleLabel?.text! ?? "IT"
	}
	
	func requestTranslationData(with url: URL) {
		URLSession.shared.dataTask(with: url, completionHandler: { maybeData, maybeResponse, maybeError in
			if let error = maybeError {
				print("Error: \(error.localizedDescription)")
				return
			}
			
			guard let data = maybeData else {
				print("No data!!!")
				return
			}
			
			guard let httpResponse = maybeResponse as? HTTPURLResponse else {
				print("No response object??!!!")
				return
			}
			
			guard httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 else {
				print("We have to work with the error case here.")
				// do error handling stuff.
				return
			}
			
			do {
				let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
				let translationJSON : JSON = JSON(json)
				
				DispatchQueue.main.async {
					self.updateTranslationData(json: translationJSON)
				}
				print(json)
			} catch let error {
				print("Error serializing json data: \(error.localizedDescription)")
			}
		}).resume()
	}
	
	func updateTranslationData(json: JSON) {
		var textForSpeech = String()
		if let tempResult = json["responseData"]["translatedText"].string {
			textForSpeech = tempResult
			translateTextToSpeech(with: textForSpeech)
			textLabel.text = tempResult
		}
		else {
			textLabel.text = "Tranlation Unavailable"
		}
	}
	
	func translateTextToSpeech(with string: String) {
		let speechUtterance: AVSpeechUtterance = AVSpeechUtterance(string: string)
		speechUtterance.rate = AVSpeechUtteranceMaximumSpeechRate / 2.0
		speechUtterance.voice = AVSpeechSynthesisVoice(language: "ru-RU")
		self.speechSynthesizer.speak(speechUtterance)
		
		let audioSession = AVAudioSession.sharedInstance()
		do {
			try audioSession.setMode(AVAudioSession.Mode.spokenAudio)
			
			let currentRoute = AVAudioSession.sharedInstance().currentRoute
			for description in currentRoute.outputs {
				if description.portType == AVAudioSession.Port.headphones {
					try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.none)
					print("headphone plugged in")
				} else {
					print("headphone pulled out")
					try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
				}
			}
			
		} catch {
			print("audioSession properties weren't set because of an error.")
		}
		
	}
	
	func recordAndRecognizeSpeech() {
		let node = audioEngine.inputNode
		
		if audioEngine.isRunning {
			audioEngine.stop()
			request.endAudio()
			node.removeTap(onBus: 0)
		} else {
			let recordingFormat = node.outputFormat(forBus: 0)
			node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
				self.request.append(buffer)
			}
			
			audioEngine.prepare()
			do {
				try audioEngine.start()
			} catch {
				return print(error)
			}
			
			guard let myRecognizer = SFSpeechRecognizer() else { return }
			if !myRecognizer.isAvailable {
				return
			}
			
			recognitionTask = speechRecognizer?.recognitionTask(with: request, resultHandler: { result, error in
				if let result = result {
					let bestResult = result.bestTranscription.formattedString
					self.textLabel.text = bestResult
					
				} else if let error = error {
					print(error)
				}
			})
		}
	}
}
