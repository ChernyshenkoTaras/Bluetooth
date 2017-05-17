//
//  SetupViewController.swift
//  MyApp
//
//  Created by Taras Chernyshenko on 5/13/17.
//  Copyright © 2017 Taras Chernyshenko. All rights reserved.
//

import UIKit

extension Notification.Name {
    
    static let setupComplete = Notification.Name("SetupComplete")
}

class SetupViewController: UIViewController, UITextFieldDelegate,
    UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet private weak var imageButton: UIButton?
    @IBOutlet private weak var usernameTextField: UITextField?
    @IBOutlet private weak var errorLabel: UILabel?
    
    @IBAction private func imageButtonPressed(button: UIButton) {
        let alertController = UIAlertController(title: "",
            message: "Select image from:", preferredStyle: .alert)
        
        let camera = UIAlertAction(title: "Camera", style: .default) { _ in
            self.showImagePicker(with: .camera)
        }
        
        let library = UIAlertAction(title: "Library", style: .default) { _ in
            self.showImagePicker(with: .photoLibrary)
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
        }
        
        alertController.addAction(camera)
        alertController.addAction(library)
        alertController.addAction(cancel)
        
        if let popoverPresentationController = alertController.popoverPresentationController {
            popoverPresentationController.sourceView = self.view
            popoverPresentationController.sourceRect = button.bounds
        }
    
        present(alertController, animated: true, completion: nil)
    }
    
    @IBAction private func saveButtonPressed(button: UIButton) {
        guard let username = self.usernameTextField?.text else {
            self.errorLabel?.isHidden = false
            return
        }
        
        Settings.current.username = username
        Settings.current.image = self.image
        if self.isFirstSetup {
            NotificationCenter.default.post(name: .setupComplete, object: nil)
        }
    }
    
    private var image: UIImage = UIImage(named: "user_image")! {
        didSet {
            self.imageButton?.setImage(self.image, for: .normal)
        }
    }
    
    var isFirstSetup = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.usernameTextField?.delegate = self
        self.imageButton?.setImage(Settings.current.image, for: .normal)
        self.usernameTextField?.text = Settings.current.username ?? ""
    }
    
    private func showImagePicker(with mode: UIImagePickerControllerSourceType) {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = mode
            imagePicker.allowsEditing = false
            
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    //MARK: UITextFieldDelegate methods
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn
        range: NSRange, replacementString string: String) -> Bool {
        self.errorLabel?.isHidden = true
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    //MARK: UIImagePickerControllerDelegate methods
    
    func imagePickerController(_ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.image = pickedImage
        }

        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
