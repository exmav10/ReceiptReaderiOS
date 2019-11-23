//
//  ViewController.swift
//  GoogleMLKit
//
//  Created by Aydin Unal [Uygulama Gelistirme - Mobil Bankacilik Uygulamalari Bolumu] on 21.07.2019.
//  Copyright © 2019 Aydin Unal [Uygulama Gelistirme - Mobil Bankacilik Uygulamalari Bolumu]. All rights reserved.
//

import UIKit
import FirebaseMLVision
import AVFoundation
import Alamofire
import SwiftyJSON

final class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var button: UIButton!
    @IBOutlet private weak var googleTextView: UITextView!
    @IBOutlet private weak var knnTextView: UITextView!
    private let imagePickerController = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imagePickerController.delegate = self
        // Do any additional setup after loading the view.
    }
    
    private func findFee(_ resultText: [String]) -> String {
        for i  in 0..<resultText.count {
            if resultText[i] == "fatura" && ( resultText[i+1] == "tutar" || resultText[i+1] == "tutarı" || resultText[i+1] == "tutari") {
                return "\(resultText[i+2]),\(resultText[i+3]) TL"
            }
        }
        return ""
    }
    
    private func findSubscriptionNumber(_ resultText: [String]) -> String {
        for i in 0..<resultText.count {
            if ( resultText[i] == "müsteri" || resultText[i] == "musteri" || resultText[i] == "musterı" || resultText[i] == "müsterı" || resultText[i] == "müşteri" || resultText[i] == "muşterı" || resultText[i] == "müşterı" || resultText[i] == "muşteri") && (resultText[i+1] == "no"){
                for j in i..<resultText.count {
                    if resultText[j].count > 8 {
                        return resultText[j]
                    }
                }
            }
        }
        return ""
    }
    
    private func findContractNumber(_ visionText: VisionText) -> String {
        let stringMatrix = getTextLinebyLine(visionText)
        for stringArrayidx in 0..<stringMatrix.count - 2 {
            let stringArray = stringMatrix[stringArrayidx]
            for elementidx in 0..<stringArray.count {
                if stringArray[elementidx] == "hesap" && stringArray[elementidx+1] == "no" {
                    return stringMatrix[stringArrayidx+2][0] // Hesap no
                }
            }
        }
        return ""
    }
    
    private func getTextLinebyLine(_ visionText: VisionText) -> [[String]]{
        var stringMatrix = [[String]]()
        for block in visionText.blocks {
            for lineidx in 0..<block.lines.count {
                let line = block.lines[lineidx]
                var stringArray = [String]()
                for element in line.elements {
                    stringArray.append(element.text.lowercased())
                }
                stringMatrix.append(stringArray)
            }
        }
        return stringMatrix
    }
    
    @IBAction private func chooseImage() {
        let actionSheet = UIAlertController(title: "Photo Source", message: "Choose a source", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] (action: UIAlertAction) in
            if UIImagePickerController.isSourceTypeAvailable(.camera), let strongSelf = self {
                strongSelf.imagePickerController.sourceType = .camera
                strongSelf.imagePickerController.allowsEditing = false
                strongSelf.present(strongSelf.imagePickerController, animated: true, completion: nil)
            }
        }))
        actionSheet.addAction(UIAlertAction(title: "Library", style: .default, handler: { [ weak self] (action: UIAlertAction) in
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary), let strongSelf = self {
                strongSelf.imagePickerController.sourceType = .photoLibrary
                strongSelf.present(strongSelf.imagePickerController, animated: true, completion: nil)
            }
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
        self.present(actionSheet, animated: true, completion: nil)
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[.originalImage] as? UIImage else {
            fatalError("Expected a dictionary containing an image, but was provided the following: \(info)")
        }
        imageView.image = image
        self.uploadImage(image)
        self.googleMLKitOperation(image)
    }
    
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    private func uploadImage(_ imageToUpload: UIImage){
        Alamofire.upload(multipartFormData: { (multipartFormData) in
            if let data = imageToUpload.jpegData(compressionQuality: 1.0) {
                multipartFormData.append(data, withName: "file",fileName: "file.jpg", mimeType: "image/jpeg")
            } else {
                print("Error: Failed to create data.")
            }
        }, to: "http://localhost:4000/image/reader")
        { (result) in
            switch result {
            case .success(let upload, _, _):
                upload.responseJSON { [weak self] response in
                    guard let strongSelf = self else { return }
                    if let value = response.result.value as? NSDictionary, let stringValue = value["message"] as? String {
                        print(value)
                        strongSelf.knnTextView.text = "\(stringValue)"
                    }
                }
            case .failure(let encodingError):
                print(encodingError)
            }
        }
    }
    
    private func googleMLKitOperation(_ imageToUpload: UIImage){
        let vision = Vision.vision()
        let textRecognizer = vision.onDeviceTextRecognizer()
        let image = VisionImage(image: imageToUpload)
        textRecognizer.process(image) { [weak self] result, error in
            guard error == nil, let result = result, let strongSelf = self else {
                return
            }
            var resultText = result.text
            for block in result.blocks {
                for line in block.lines {
                    for element in line.elements {
                        let elementText = element.text
                        resultText = resultText + " " + elementText
                    }
                }
            }
            resultText = resultText.localizedLowercase
            strongSelf.googleTextView.text = "Tutar: " + strongSelf.findFee(resultText.wordList) + "\n" + "Hesap No: " + strongSelf.findSubscriptionNumber(resultText.wordList) + "\n" + "Müşteri No: " + strongSelf.findContractNumber(result)
        }
    }
}

extension String
{
    var wordList: [String]
    {
        return components(separatedBy: NSCharacterSet.alphanumerics.inverted).filter({$0 != ""})
    }
}
