//
//  ViewController.swift
//  WWDC 2017 Advanced Animations with UIKit
//
//  Created by Christopher Goldsby on 6/10/17.
//  Copyright © 2017 Christopher Goldsby. All rights reserved.
//

import UIKit

private let expandedControlTopMargin: CGFloat = -75
private let collapsedControlHeight: CGFloat = -55
private let duration: TimeInterval = 0.575

private enum State {
    case expanded
    case collapsed
}

private prefix func !(_ state: State) -> State {
    return state == State.expanded ? .collapsed : .expanded
}

final class ViewController: UIViewController {
    
    @IBOutlet private weak var control: UIView!
    @IBOutlet private weak var blurEffectView: UIVisualEffectView!
    @IBOutlet private weak var controlTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var controlHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var collapsedCommentsLabel: UILabel!
    
    private var state: State = .collapsed
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @IBAction func handleTap(_ recognizer: UITapGestureRecognizer) {
        animateOrReverseRunningTransition(state: !state, duration: duration)
    }
    
    @IBAction func handlePan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            startInteractiveTransition(state: !state, duration: duration)
        case .changed:
            let translation = recognizer.translation(in: control)
            updateInteractiveTransition(distanceTraveled: translation.y)
        case .cancelled, .failed:
            continueInteractiveTransition(cancel: true)
        case .ended:
            let isCancelled = isGestureCancelled(recognizer)
            continueInteractiveTransition(cancel: isCancelled)
        default:
            break
        }
    }
    
    // MARK: - Private
    
    private func setUpView() {
        blurEffectView.effect = nil
        control.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        controlTopConstraint.constant = collapsedControlHeight
        controlHeightConstraint.constant = expandedControlTopMargin
    }
    
    private func isGestureCancelled(_ recognizer: UIPanGestureRecognizer) -> Bool {
        let isCancelled: Bool
        
        let velocityY = recognizer.velocity(in: view).y
        if velocityY != 0 {
            let isPanningDown = velocityY > 0
            isCancelled = (state == .expanded && isPanningDown) ||
                (state == .collapsed && !isPanningDown)
        }
        else {
            isCancelled = false
        }
        
        return isCancelled
    }
    
    // MARK: - Animations
    
    // Tracks all running animators
    private var runningAnimators = [UIViewPropertyAnimator]()
    
    // Tracks progress when interrupted for all Animators
    private var progressWhenInterrupted = [UIViewPropertyAnimator : CGFloat]()
    
    // Perform all animations with animators if not already running
    private func animateTransitionIfNeeded(state: State, duration: TimeInterval) {
        if runningAnimators.isEmpty {
            self.state = state
            
            let frameAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1)
            addToRunnningAnimators(frameAnimator) {
                self.updateFrame(for: self.state)
            }
            
            let timing = blurTimingCurve(for: state)
            let blurAnimator = UIViewPropertyAnimator(duration: duration, timingParameters: timing)
            blurAnimator.scrubsLinearly = false
            addToRunnningAnimators(blurAnimator) {
                self.updateBlurView(for: self.state)
            }
            
            let cornerAnimator = UIViewPropertyAnimator(duration: duration, curve: .linear)
            addToRunnningAnimators(cornerAnimator) {
                self.updateCornerRadius(for: self.state)
            }
        }
    }
    
    // Starts transition if necessary or reverses it on tap
    private func animateOrReverseRunningTransition(state: State, duration: TimeInterval) {
        if runningAnimators.isEmpty {
            animateTransitionIfNeeded(state: state, duration: duration)
        }
        else {
            reverseRunningAnimations()
        }
    }
    
    // Starts transition if necessary and pauses on pan .begin
    private func startInteractiveTransition(state: State, duration: TimeInterval) {
        animateTransitionIfNeeded(state: state, duration: duration)
        
        progressWhenInterrupted = [:]
        for animator in runningAnimators {
            animator.pauseAnimation()
            progressWhenInterrupted[animator] = animator.fractionComplete
        }
    }
    
    // Scrubs transition on pan .changed
    func updateInteractiveTransition(distanceTraveled: CGFloat) {
        let totalAnimationDistance = collapsedControlHeight + control.bounds.height
        let fractionComplete = distanceTraveled / totalAnimationDistance
        for animator in runningAnimators {
            if let progressWhenInterrupted = progressWhenInterrupted[animator] {
                let relativeFractionComplete = fractionComplete + progressWhenInterrupted
                
                if (state == .expanded && relativeFractionComplete > 0) ||
                    (state == .collapsed && relativeFractionComplete < 0) {
                    animator.fractionComplete = 0
                }
                else if (state == .expanded && relativeFractionComplete < -1) ||
                    (state == .collapsed && relativeFractionComplete > 1) {
                    animator.fractionComplete = 1
                }
                else {
                    animator.fractionComplete = abs(fractionComplete) + progressWhenInterrupted
                }
            }
        }
    }
    
    // Continues or reverse transition on pan .ended
    func continueInteractiveTransition(cancel: Bool) {
        if cancel {
            reverseRunningAnimations()
        }
        
        let timing = UICubicTimingParameters(animationCurve: .easeOut)
        for animator in runningAnimators {
            animator.continueAnimation(withTimingParameters: timing, durationFactor: 0)
        }
    }
    
    // MARK: - Appearance Animations
    
    private func updateFrame(for state: State) {
        switch state {
        case .collapsed:
            controlTopConstraint.constant = collapsedControlHeight
        case .expanded:
            controlTopConstraint.constant = -control.bounds.height
        }
        
        view.layoutIfNeeded()
    }
    
    private func blurTimingCurve(for state: State) -> UITimingCurveProvider {
        let timing: UITimingCurveProvider
        switch state {
        case .collapsed:
            timing = UICubicTimingParameters(
                controlPoint1: CGPoint(x: 0.1, y: 0.75),
                controlPoint2: CGPoint(x: 0.25, y: 0.9))
        case .expanded:
            timing = UICubicTimingParameters(
                controlPoint1: CGPoint(x: 0.75, y: 0.1),
                controlPoint2: CGPoint(x: 0.9, y: 0.25))
        }
        
        return timing
    }
    
    private func updateBlurView(for state: State) {
        switch state {
        case .collapsed:
            blurEffectView.effect = nil
        case .expanded:
            blurEffectView.effect = UIBlurEffect(style: .dark)
        }
    }
    
    private func updateCornerRadius(for state: State) {
        switch state {
        case .collapsed:
            control.layer.cornerRadius = 0
        case .expanded:
            control.layer.cornerRadius = 12
        }
    }
    
    // MARK: - Running Animation Helpers
    
    private func addToRunnningAnimators(_ animator: UIViewPropertyAnimator,
                                        animation: @escaping () -> Void) {
        animator.addAnimations {
            animation()
        }
        animator.addCompletion {
            _ in
            self.runningAnimators = self.runningAnimators.filter { $0 != animator }
            
            // Especially after reversing animations, make sure the UI has correct
            // appearnce for it 'state'. We can achieve this by reapplying the "final animation".
            animation()
        }
        
        animator.startAnimation()
        runningAnimators.append(animator)
    }
    
    private func reverseRunningAnimations() {
        for animator in runningAnimators {
            animator.isReversed = !animator.isReversed
        }
        
        state = !state
    }
}
