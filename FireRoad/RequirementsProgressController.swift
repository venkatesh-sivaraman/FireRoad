//
//  RequirementsProgressController.swift
//  FireRoad
//
//  Created by Venkatesh Sivaraman on 1/22/18.
//  Copyright © 2018 Base 12 Innovations. All rights reserved.
//

import UIKit

protocol RequirementsProgressDelegate: class {
    func requirementsProgressUpdated(_ controller: RequirementsProgressController)
}

class RequirementsProgressController: UIViewController {

    var requirement: RequirementsListStatement?
    
    @IBOutlet var slider: UISlider!
    @IBOutlet var progressLabel: UILabel!
    
    weak var delegate: RequirementsProgressDelegate?
    
    var currentValue: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        updateSliderAndLabel()
        
        preferredContentSize = CGSize(width: 200.0, height: 44.0)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        guard let req = requirement, req.threshold != nil else {
            return
        }
        let step: Float = req.threshold!.criterion == .units ? 3.0 : 1.0
        currentValue = Int(round(sender.value / step) * step)
        updateSliderAndLabel()
    }
    
    @IBAction func sliderEditFinished(_ sender: UISlider) {
        guard let req = requirement, req.threshold != nil else {
            return
        }
        let step: Float = req.threshold!.criterion == .units ? 3.0 : 1.0
        currentValue = Int(round(sender.value / step) * step)
        delegate?.requirementsProgressUpdated(self)
        currentValue = nil
        updateSliderAndLabel()
    }
    
    func updateSliderAndLabel() {
        guard let req = requirement, req.threshold != nil else {
            return
        }
        let value = currentValue ?? req.progressAssertion?.override
        
        var text = "\(value ?? 0)/\(req.threshold!.cutoff) "
        if req.threshold!.criterion == .subjects {
            text += "subject"
        } else {
            text += "unit"
        }
        if req.threshold!.cutoff != 1 {
            text += "s"
        }
        progressLabel.text = text
        
        slider.minimumValue = 0.0
        slider.maximumValue = Float(req.threshold!.cutoff)
        slider.value = Float(value ?? 0)
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
