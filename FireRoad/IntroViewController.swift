//
//  IntroViewController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/30/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol IntroViewControllerDelegate: class {
    func introViewControllerDismissed(_ intro: IntroViewController)
    func introViewController(_ intro: IntroViewController, selected yearNumber: Int)
}

class IntroViewController: UIViewController, UIScrollViewDelegate {

    @IBOutlet var backgroundView: UIView!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var imageViews: [UIImageView]?
    @IBOutlet var pageControl: UIPageControl!
    @IBOutlet var yearButtons: [UIButton]?
    @IBOutlet var doneButton: UIButton?
    
    var backgroundColors: [UIColor] = [
        UIColor(hue: 0.0, saturation: 0.86, brightness: 0.8, alpha: 1.0),
        UIColor(hue: 0.46, saturation: 0.68, brightness: 0.94, alpha: 1.0),
        UIColor(hue: 0.09, saturation: 0.88, brightness: 0.91, alpha: 1.0),
        UIColor(hue: 0.74, saturation: 0.87, brightness: 0.94, alpha: 1.0)
    ]
    
    weak var delegate: IntroViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        if let views = imageViews {
            for imageView in views {
                imageView.layer.shadowOffset = CGSize.zero
                imageView.layer.shadowRadius = 8.0
                imageView.layer.shadowOpacity = 0.3
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    var currentPage: Int = 0
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let newPage = min(backgroundColors.count, max(0, Int(round(scrollView.contentOffset.x / scrollView.frame.size.width))))
        if newPage != currentPage {
            UIView.animate(withDuration: 0.8, delay: 0.0, options: [.beginFromCurrentState, .curveEaseInOut], animations: {
                self.backgroundView.backgroundColor = self.backgroundColors[newPage % self.backgroundColors.count]
            }, completion: nil)
            currentPage = newPage
        }
        pageControl.currentPage = currentPage
    }
    
    func scroll(to page: Int) {
        currentPage = page
        pageControl.currentPage = currentPage
        UIView.animate(withDuration: 0.8, delay: 0.0, options: [.beginFromCurrentState, .curveEaseInOut], animations: {
            self.backgroundView.backgroundColor = self.backgroundColors[page % self.backgroundColors.count]
        }, completion: nil)
        scrollView.setContentOffset(CGPoint(x: CGFloat(page) * scrollView.frame.size.width, y: 0.0), animated: true)
    }

    @IBAction func introFinished(_ sender: AnyObject) {
        delegate?.introViewControllerDismissed(self)
    }
    
    @IBAction func pageControlTapped(_ sender: UIPageControl) {
        scroll(to: sender.currentPage)
    }
    
    @IBAction func nextButtonTapped(_ sender: AnyObject) {
        scroll(to: currentPage + 1)
    }
    
    @IBAction func yearButtonTapped(_ sender: UIButton) {
        delegate?.introViewController(self, selected: sender.tag)
        UIView.animate(withDuration: 0.2) {
            sender.backgroundColor = UIColor(white: 0.7, alpha: 0.2)
            sender.layer.cornerRadius = 6.0
            
            if let buttons = self.yearButtons {
                for button in buttons {
                    if button != sender {
                        button.backgroundColor = UIColor.clear
                    }
                }
            }
        }
        doneButton?.isEnabled = true
    }
}
