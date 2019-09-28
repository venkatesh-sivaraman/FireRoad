//
//  AuthenticationViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/13/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol AuthenticationViewControllerDelegate: class {
    func authenticationViewControllerCanceled(_ auth: AuthenticationViewController)
    func authenticationViewController(_ auth: AuthenticationViewController, finishedWith jsonString: String?)
    
}

class AuthenticationViewController: UIViewController, UIWebViewDelegate {

    @IBOutlet var webView: UIWebView!
    weak var delegate: AuthenticationViewControllerDelegate?
    
    var request: URLRequest?
    var username: String = ""
    var password: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        navigationItem.title = "FireRoad"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(AuthenticationViewController.cancelButtonPressed(_:)))
        
        webView.delegate = self
        if let req = request {
            webView.loadRequest(req)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func cancelButtonPressed(_ sender: AnyObject) {
        delegate?.authenticationViewControllerCanceled(self)
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        if webView.stringByEvaluatingJavaScript(from: "document.getElementById('access_info') != null") ?? "false" == "true" {
            let jsonString = webView.stringByEvaluatingJavaScript(from: "document.getElementById('access_info').innerHTML")
            delegate?.authenticationViewController(self, finishedWith: jsonString)
        } else if let urlString = webView.request?.url?.absoluteString, urlString.lowercased().contains("decline") {
            delegate?.authenticationViewControllerCanceled(self)
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
