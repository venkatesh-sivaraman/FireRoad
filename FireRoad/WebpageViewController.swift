//
//  WebpageViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 12/11/17.
//  Copyright © 2017 Base 12 Innovations. All rights reserved.
//

import UIKit

class WebpageViewController: UIViewController, UIWebViewDelegate {

    @IBOutlet var backButton: UIButton?
    @IBOutlet var forwardButton: UIButton?
    
    @IBOutlet var webView: UIWebView!
    
    var url: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        webView.delegate = self
        webView.backgroundColor = .clear
        backButton?.setImage(backButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
        forwardButton?.setImage(forwardButton?.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
        if let url = url {
            webView.loadRequest(URLRequest(url: url))
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateNavigationButtons() {
        backButton?.isEnabled = webView.canGoBack
        forwardButton?.isEnabled = webView.canGoForward
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        navigationItem.title = webView.stringByEvaluatingJavaScript(from: "document.title")
        updateNavigationButtons()
    }
    
    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        let alert = UIAlertController(title: "Web Page Load Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
        updateNavigationButtons()
    }
    
    @IBAction func goBack(_ sender: AnyObject) {
        webView.goBack()
        updateNavigationButtons()
    }
    
    @IBAction func goForward(_ sender: AnyObject) {
        webView.goForward()
        updateNavigationButtons()
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
