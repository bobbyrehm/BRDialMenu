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
    private var container = UIView()
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
    
    func commonInit() {
        isOpaque = false
        clearsContextBeforeDrawing = true
        contentMode = .redraw
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
    
        container = UIView(frame: rect)
        
        if outlineConnected {
            let circleBackgroundPath = UIBezierPath(ovalIn: CGRect(center: center, size: CGSize(width: circleRadius * 2, height: circleRadius * 2)))
            let circleBackgroundLayer = CAShapeLayer()
            circleBackgroundLayer.path = circleBackgroundPath.cgPath
            circleBackgroundLayer.lineWidth = outlineWidth
            circleBackgroundLayer.strokeColor = outlineColor.cgColor
            circleBackgroundLayer.fillColor = UIColor.clear.cgColor
            container.layer.addSublayer(circleBackgroundLayer)
        }
        
        for i in 0..<numberOfItems {
            let item = dataSource!.viewForItem(inMenu: self, atIndex: i)
            item.frame = frameForItem(atIndex: i, startAngle: Angle(degrees:orientation.rawValue), center: center)
            item.layer.borderColor = outlineColor.cgColor
            item.layer.borderWidth = outlineWidth
            item.layer.cornerRadius = item.frame.size.width / 2.0
            item.clipsToBounds = true
            container.addSubview(item)
            menuItems.append(item)
        }
        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        addConstraints(container.constrainAndCenter(in: self))
    }
    
    private var menuItemTransforms: [CGAffineTransform] = []
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
            let dx = point.x - container.center.x
            let dy = point.y - container.center.y
            deltaAngle = atan2(Double(dy), Double(dx))
            startTransform = container.transform
            storeItemTransforms()
        } else if recognizer.state == .changed {
            let point = recognizer.location(in: self)
            if (pointWithinPanDistance(point: point)) {
                if !inNoSpinZone {
                    let dx = point.x - container.center.x
                    let dy = point.y - container.center.y
                    let angle = atan2(Double(dy), Double(dx))
                    let angleDifference = CGFloat(angle - deltaAngle)
                    container.transform = startTransform.rotated(by: angleDifference)
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
        let vectorFromCenterToPoint = Vector2D(x: Double(point.x - container.center.x), y: Double(point.y - container.center.y))
        //math from here: http://math.stackexchange.com/a/116239
        let velocityTangentToCircle = vectorFromCenterToPoint.unitVector().crossProduct(velocity)
        let circumference = 2 * M_PI * circleRadius
        let revolutionsPerSecond = abs(velocityTangentToCircle / circumference)
        let radiansPerSecond = revolutionsPerSecond * (2 * M_PI)
        let duration = revolutionsPerSecond / decelerationRate
        let radians = duration * radiansPerSecond / decelerationRate
        let totalRevolutions = radians / (2 * M_PI)
        let initialTransform = container.transform
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
                    self.container.transform = initialTransform.rotated(by: CGFloat(directedRotation))
                    self.updateItemTransforms(angleDifference: CGFloat(directedRotation))
                })
            }
            if self.snapsToNearestSector {
                self.storeItemTransforms()
                let currentTransformAngle = atan2(Double(self.container.transform.b), Double(self.container.transform.a))
                let currentAngle = Angle(radians: currentTransformAngle)
                let nearestSectorAngle = self.nearestSector(angle: currentAngle.radians)
                let snapAngle = Angle(radians: nearestSectorAngle - currentAngle.radians)
                UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.0, animations: { 
                    self.container.transform = self.container.transform.rotated(by: CGFloat(snapAngle.radians))
                    self.updateItemTransforms(angleDifference: CGFloat(snapAngle.radians))
                })
            }
        }, completion: { finished in
            
        })
    }
    
    private func snapToNearestSector(duration: Double = 0.2, delay: Double = 0.0) {
        storeItemTransforms()
        let currentTransformAngle = atan2(Double(container.transform.b), Double(container.transform.a))
        let currentAngle = Angle(radians: currentTransformAngle)
        let nearestSectorAngle = self.nearestSector(angle: currentAngle.radians)
        let snapAngle = Angle(radians: nearestSectorAngle - currentAngle.radians)
        
        UIView.animate(withDuration: duration, delay: delay, options: [.allowUserInteraction, .curveEaseOut], animations: {
            self.container.transform = self.container.transform.rotated(by: CGFloat(snapAngle.radians))
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
