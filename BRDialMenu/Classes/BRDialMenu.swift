//
//  BRDialMenu.swift
//  BRDialMenu
//
//  Created by Bobby Rehm on 11/17/16.
//  Copyright © 2016 Bobby Rehm. All rights reserved.
//

import UIKit

public protocol BRDialMenuDataSource {
    func numberOfItems(inMenu menu: BRDialMenu) -> Int
    func viewForItem(inMenu menu: BRDialMenu, atIndex index: Int) -> UIView
}

@IBDesignable
public class BRDialMenu: UIView, UIGestureRecognizerDelegate {

    //public
    public var dataSource: BRDialMenuDataSource?
    @IBInspectable public var itemDiameter: CGFloat = 30.0
    @IBInspectable public var outlineColor: UIColor = .white
    @IBInspectable public var outlineConnected: Bool = true
    @IBInspectable public var outlineWidth: CGFloat = 3.0
    public var snapsToNearestSector = true
    public var spinsWithInertia = true
    public var decelerationRate = 2.0 //the larger the deceleration rate, the sooner the wheel comes to a stop
    public var sectorWidth = 30.0 //degrees
    public var respondsToUserTouch = true {
        didSet {
            if respondsToUserTouch {
                self.gestureRecognizers = [panGestureRecognizer]
            } else {
                self.gestureRecognizers = []
            }
        }
    }
    public var orientation = Orientation.up

    //private
    private var translationContainer = UIView()
    private var rotationContainer = UIView()
    private var circleBackgroundLayer: CAShapeLayer!
    private var startTransform = CGAffineTransform()
    private var deltaAngle = 0.0
    private var numberOfItems: Int {
        get {
            return dataSource?.numberOfItems(inMenu: self) ?? 0
        }
    }
    private var menuItems: [UIView] = []
    private var inNoSpinZone = false
    private var panGestureRecognizer = UIPanGestureRecognizer()
    
    private var circleRadius: Double {
        let viewLength = min(self.frame.size.width, self.frame.size.height)
        return (Double(viewLength) - Double(itemDiameter)) / 2.0
    }
    
    private var baseMenuItemTransforms: [CGAffineTransform] = []
    private var menuItemTransforms: [CGAffineTransform] = []
    
    convenience init() {
        self.init(frame: CGRect.zero)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private var previousRadius: Double!
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        if previousRadius == nil {
            previousRadius = circleRadius
        }
        /*
        if self.subviews.contains(translationContainer) {
            let newCenter = self.bounds.center
            let oldCenter = translationContainer.frame.center
            if newCenter != oldCenter {
                let dx = newCenter.x - oldCenter.x
                let dy = newCenter.y - oldCenter.y
                translationContainer.transform = translationContainer.transform.translatedBy(x: dx, y: dy)
            }
            
            if previousRadius != circleRadius {
                let scale = CGFloat(circleRadius / previousRadius)
                //translationContainer.transform = translationContainer.transform.scaledBy(x: scale, y: scale)
            }
        }
        */
        if previousRadius != circleRadius {
            previousRadius = circleRadius
        }
    }
    
    func commonInit() {
        isOpaque = false
        clearsContextBeforeDrawing = true
        translatesAutoresizingMaskIntoConstraints = false
        panGestureRecognizer.addTarget(self, action: #selector(handlePan))
        panGestureRecognizer.delegate = self
        if respondsToUserTouch {
            addGestureRecognizer(panGestureRecognizer)
        }
    }
    
    private func frameForItem(atIndex index: Int, startAngle: Angle, center: CGPoint) -> CGRect {
        let angleBetweenCircleCenters = Angle(degrees: 360.0 / Double(numberOfItems))
        let itemCenter = CGPoint.pointOnCircumference(origin: center, radius: circleRadius, angle: Angle(degrees: startAngle.degrees + Double(index) * angleBetweenCircleCenters.degrees))
        return CGRect(center: itemCenter, size: CGSize(width: itemDiameter, height: itemDiameter))
    }
    
    override public func draw(_ rect: CGRect) {
        let center = rect.center
        menuItems = []
        translationContainer.removeFromSuperview()
        rotationContainer.removeFromSuperview()
    
        if let circleBackgroundLayer = self.circleBackgroundLayer {
            circleBackgroundLayer.removeFromSuperlayer()
        }
        
        let minDimension = min(rect.size.width, rect.size.height)
        let squareFrame = CGRect(center: center, size: CGSize(width: minDimension, height: minDimension))
        translationContainer = UIView(frame: squareFrame)
        translationContainer.contentMode = .scaleAspectFit
        rotationContainer = UIView(frame: translationContainer.bounds)
        rotationContainer.contentMode = .scaleAspectFit
        
        if outlineConnected {
            let circleBackgroundPath = UIBezierPath(ovalIn: CGRect(center: rotationContainer.bounds.center, size: CGSize(width: circleRadius * 2, height: circleRadius * 2)))
            circleBackgroundLayer = CAShapeLayer()
            circleBackgroundLayer.path = circleBackgroundPath.cgPath
            circleBackgroundLayer.lineWidth = outlineWidth
            circleBackgroundLayer.strokeColor = outlineColor.cgColor
            circleBackgroundLayer.fillColor = UIColor.clear.cgColor
            rotationContainer.layer.addSublayer(circleBackgroundLayer)
        }
        
        for i in 0..<numberOfItems {
            let item = dataSource!.viewForItem(inMenu: self, atIndex: i)
            item.frame = frameForItem(atIndex: i, startAngle: Angle(degrees:orientation.rawValue), center: rotationContainer.bounds.center)
            if let baseTransform = baseMenuItemTransforms[safe: i] {
                item.transform = baseTransform
            }
            item.layer.borderColor = outlineColor.cgColor
            item.layer.borderWidth = outlineWidth
            item.layer.cornerRadius = item.frame.size.width / 2.0
            item.clipsToBounds = false
            rotationContainer.addSubview(item)
            menuItems.append(item)
        }
        baseMenuItemTransforms = menuItems.map{$0.transform}
        
        translationContainer.addSubview(rotationContainer)
        addSubview(translationContainer)
        setupConstraints()
    }
    
    private func setupConstraints() {
        //translation container
        translationContainer.translatesAutoresizingMaskIntoConstraints = false
        let centerXConstraint = translationContainer.centerXAnchor.constraint(equalTo: self.centerXAnchor)
        let centerYConstraint = translationContainer.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        let squareConstraint = translationContainer.widthAnchor.constraint(equalTo: translationContainer.heightAnchor)
        let heightConstraint = translationContainer.heightAnchor.constraint(lessThanOrEqualTo: self.heightAnchor)
        let maxHeightConstraint = translationContainer.heightAnchor.constraint(equalTo: self.heightAnchor)
        maxHeightConstraint.priority = 900
        let widthConstraint = translationContainer.widthAnchor.constraint(lessThanOrEqualTo: self.widthAnchor)
        let maxWidthConstraint = translationContainer.widthAnchor.constraint(equalTo: self.widthAnchor)
        maxWidthConstraint.priority = 900
        addConstraints([centerXConstraint, centerYConstraint, squareConstraint, widthConstraint, heightConstraint, maxHeightConstraint, maxWidthConstraint])
        
        //rotation container
        rotationContainer.translatesAutoresizingMaskIntoConstraints = false
        let height = rotationContainer.heightAnchor.constraint(equalTo: translationContainer.heightAnchor)
        let width = rotationContainer.widthAnchor.constraint(equalTo: translationContainer.widthAnchor)
        let centerX = rotationContainer.centerXAnchor.constraint(equalTo: translationContainer.centerXAnchor)
        let centerY = rotationContainer.centerYAnchor.constraint(equalTo: translationContainer.centerYAnchor)
        translationContainer.addConstraints([height, width, centerX, centerY])
    }
    
    private func storeItemTransforms() {
        menuItemTransforms = menuItems.map{$0.transform}
    }
    
    private func updateItemTransforms(angleDifference: CGFloat) {
        for (i, item) in self.menuItems.enumerated() {
            item.transform = menuItemTransforms[i].rotated(by: -angleDifference)
        }
    }
    
    func handlePan(recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .began || inNoSpinZone {
            let point = recognizer.location(in: self)
            if pointWithinPanDistance(point: point) {
                inNoSpinZone = false
            }
            if recognizer.state == .ended {
                if snapsToNearestSector {
                    snapToNearestSector()
                }
                return
            }
            let dx = point.x - rotationContainer.center.x
            let dy = point.y - rotationContainer.center.y
            deltaAngle = atan2(Double(dy), Double(dx))
            startTransform = rotationContainer.transform
            storeItemTransforms()
        } else if recognizer.state == .changed {
            let point = recognizer.location(in: self)
            if (pointWithinPanDistance(point: point)) {
                if !inNoSpinZone {
                    let dx = point.x - rotationContainer.center.x
                    let dy = point.y - rotationContainer.center.y
                    let angle = atan2(Double(dy), Double(dx))
                    let angleDifference = CGFloat(angle - deltaAngle)
                    rotationContainer.transform = startTransform.rotated(by: angleDifference)
                    updateItemTransforms(angleDifference: angleDifference)
                }
            } else {
                inNoSpinZone = true
            }
        } else if recognizer.state == .ended {
            if spinsWithInertia {
                let velocity = recognizer.velocity(in: self)
                let velocityVector = Vector2D(x: Double(velocity.x), y: Double(velocity.y))
                let point = recognizer.location(in: self)
                decelerate(velocity: velocityVector, point: point)
            } else if snapsToNearestSector {
                snapToNearestSector()
            }
        }
    }
    
    private func decelerate(velocity: Vector2D, point: CGPoint) {
        storeItemTransforms()
        let vectorFromCenterToPoint = Vector2D(x: Double(point.x - rotationContainer.center.x), y: Double(point.y - rotationContainer.center.y))
        //math from here: http://math.stackexchange.com/a/116239
        let velocityTangentToCircle = vectorFromCenterToPoint.unitVector().crossProduct(velocity)
        let circumference = 2 * M_PI * circleRadius
        let revolutionsPerSecond = abs(velocityTangentToCircle / circumference)
        let radiansPerSecond = revolutionsPerSecond * (2 * M_PI)
        let duration = revolutionsPerSecond / decelerationRate
        let radians = duration * radiansPerSecond / decelerationRate
        let totalRevolutions = radians / (2 * M_PI)
        let initialTransform = rotationContainer.transform
        UIView.animateKeyframes(withDuration: duration, delay: 0.0, options: [.allowUserInteraction, .calculationModePaced, UIViewKeyframeAnimationOptions(animationOptions: .curveEaseOut)], animations: {
            var accumulatedRotation = 0.0
            for _ in 0..<Int(ceil(totalRevolutions * 3)) {
                let remainingRotation = (totalRevolutions * 2 * M_PI) - accumulatedRotation
                let rotation = min(remainingRotation, 2.0 / 3.0 * M_PI)
                accumulatedRotation += rotation
                var directedRotation = accumulatedRotation
                if velocityTangentToCircle < 0 {
                    directedRotation *= -1
                }
                UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.0, animations: {
                    self.rotationContainer.transform = initialTransform.rotated(by: CGFloat(directedRotation))
                    self.updateItemTransforms(angleDifference: CGFloat(directedRotation))
                })
            }
            if self.snapsToNearestSector {
                self.storeItemTransforms()
                let currentTransformAngle = atan2(Double(self.rotationContainer.transform.b), Double(self.rotationContainer.transform.a))
                let currentAngle = Angle(radians: currentTransformAngle)
                let nearestSectorAngle = self.nearestSector(angle: currentAngle.radians)
                let snapAngle = Angle(radians: nearestSectorAngle - currentAngle.radians)
                UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.0, animations: { 
                    self.rotationContainer.transform = self.rotationContainer.transform.rotated(by: CGFloat(snapAngle.radians))
                    self.updateItemTransforms(angleDifference: CGFloat(snapAngle.radians))
                })
            }
        }, completion: { finished in
            
        })
    }
    
    private func snapToNearestSector(duration: Double = 0.2, delay: Double = 0.0) {
        storeItemTransforms()
        let currentTransformAngle = atan2(Double(rotationContainer.transform.b), Double(rotationContainer.transform.a))
        let currentAngle = Angle(radians: currentTransformAngle)
        let nearestSectorAngle = self.nearestSector(angle: currentAngle.radians)
        let snapAngle = Angle(radians: nearestSectorAngle - currentAngle.radians)
        
        UIView.animate(withDuration: duration, delay: delay, options: [.allowUserInteraction, .curveEaseOut], animations: {
            self.rotationContainer.transform = self.rotationContainer.transform.rotated(by: CGFloat(snapAngle.radians))
            self.updateItemTransforms(angleDifference: CGFloat(snapAngle.radians))
        }) { finished in
            //finished animating
        }
    }
    
    private func nearestSector(angle: Double) -> Double {
        let sectorAngle = Angle(degrees: sectorWidth)
        let div = round(angle / sectorAngle.radians)
        return div * sectorAngle.radians
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let point = touch.location(in: self)
        return pointWithinPanDistance(point: point)
    }
    
    private func pointWithinPanDistance(point: CGPoint) -> Bool {
        let distanceFromCenter = point.distance(toPoint: CGPoint(x: self.frame.size.width / 2.0, y: self.frame.size.height / 2.0))
        return distanceFromCenter > (CGFloat(circleRadius) - itemDiameter * 1.5) && distanceFromCenter < (CGFloat(circleRadius) + itemDiameter * 2)
    }
}
