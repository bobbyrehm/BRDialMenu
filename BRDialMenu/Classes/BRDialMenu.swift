//
//  BRDialMenu.swift
//  BRDialMenu
//
//  Created by Bobby Rehm on 11/17/16.
//  Copyright © 2016 Bobby Rehm. All rights reserved.
//

import UIKit

struct Angle {
    var degrees: Double
    var radians: Double {
        get {
            return degrees * (M_PI/180)
        }
        set {
            degrees = newValue / (M_PI / 180)
        }
    }
    
    init(radians: Double) {
        degrees = radians / (M_PI / 180)
    }
    
    init(degrees: Double) {
        self.degrees = degrees
    }
}

struct Vector2D {
    var x = 0.0, y = 0.0
}

extension Vector2D: CustomStringConvertible {
    static func + (left: Vector2D, right: Vector2D) -> Vector2D {
        return Vector2D(x: left.x + right.x, y: left.y + right.y)
    }
    static func - (left: Vector2D, right: Vector2D) -> Vector2D {
        return Vector2D(x: left.x - right.x, y: left.y - right.y)
    }
    //dot product
    static func * (left: Vector2D, right: Vector2D) -> Double {
        return left.x * right.x + left.y * right.y
    }
    var magnitude: Double {
        return sqrt(x * x + y * y)
    }
    mutating func scale(scalar: Double) {
        x *= scalar
        y *= scalar
    }
    //returns z value in 3-d vector, because cross product of two 2D vectors is <0, 0, z>
    //http://math.stackexchange.com/a/116239
    func crossProduct(_ vector: Vector2D) -> Double {
        return x * vector.y - y * vector.x
    }
    
    func unitVector() -> Vector2D {
        return Vector2D(x: x / magnitude, y: y / magnitude)
    }
    var description: String {
        return "Vector2D(x: \(x), y: \(y))"
    }
}

enum Orientation: Double {
    case up = -90.0
    case down = 90.0
    case left = 0.0
    case right = 180.0
}

extension CGPoint {
    static func pointOnCircumference(origin: CGPoint, radius: Double, angle: Angle) -> CGPoint {
        
        let radians = angle.radians
        let x = origin.x + CGFloat(radius) * CGFloat(cos(radians))
        let y = origin.y + CGFloat(radius) * CGFloat(sin(radians))
        
        return CGPoint(x: x, y: y)
    }
    
    func distance(toPoint p:CGPoint) -> CGFloat {
        return sqrt(pow(x - p.x, 2) + pow(y - p.y, 2))
    }
    
    func inQuadrantI() -> Bool {
        return x > 0 && y > 0
    }
    
    func inQuadrantII() -> Bool {
        return x < 0 && y > 0
    }
    
    func inQuadrantIII() -> Bool {
        return x < 0 && y < 0
    }
    
    func inQuadrantIV() -> Bool {
        return x > 0 && y < 0
    }
    
    func cartesianCoordinate(center: CGPoint) -> CGPoint {
        let x1 = x - center.x
        let y1 = -(y - center.y)
        return CGPoint(x: x1, y: y1)
    }
}

extension CGRect {
    var center: CGPoint {
        get {
            return CGPoint(x: self.origin.x + self.size.width / 2.0, y: self.origin.y + self.size.height / 2.0)
        }
        set {
            origin.x = center.x - size.width / 2.0
            origin.y = center.y - size.height / 2.0
        }
    }
    init(center: CGPoint, size: CGSize) {
        self.origin = CGPoint(x: center.x - size.width / 2.0, y: center.y - size.height / 2.0)
        self.size = size
    }
}

extension UIViewKeyframeAnimationOptions {
    init(animationOptions: UIViewAnimationOptions) {
        rawValue = animationOptions.rawValue
    }
}

protocol BRDialMenuDataSource {
    func numberOfItems(inMenu menu: BRDialMenu) -> Int
    func viewForItem(inMenu menu: BRDialMenu, atIndex index: Int) -> UIView
}

@IBDesignable
class BRDialMenu: UIView, UIGestureRecognizerDelegate {

    //public
    var dataSource: BRDialMenuDataSource?
    @IBInspectable var itemDiameter: CGFloat = 30.0
    @IBInspectable var outlineColor: UIColor = .white
    @IBInspectable var outlineConnected: Bool = true
    @IBInspectable var outlineWidth: CGFloat = 3.0
    var snapsToNearestSector = true
    var spinsWithInertia = true
    var decelerationRate = 2.0 //the larger the deceleration rate, the sooner the wheel comes to a stop
    var sectorWidth = 30.0 //degrees
    var respondsToUserTouch = true {
        didSet {
            if respondsToUserTouch {
                self.gestureRecognizers = [panGestureRecognizer]
            } else {
                self.gestureRecognizers = []
            }
        }
    }
    var orientation = Orientation.up
    var snapSpeed = 0.1 //seconds per degree
    
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
    
    var circleRadius: Double {
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
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        isOpaque = false
        clearsContextBeforeDrawing = true
        panGestureRecognizer.addTarget(self, action: #selector(handlePan))
        panGestureRecognizer.delegate = self
        if respondsToUserTouch {
            addGestureRecognizer(panGestureRecognizer)
        }
    }
    
    func frameForItem(atIndex index: Int, startAngle: Angle, center: CGPoint) -> CGRect {
        let angleBetweenCircleCenters = Angle(degrees: 360.0 / Double(numberOfItems))
        let itemCenter = CGPoint.pointOnCircumference(origin: center, radius: circleRadius, angle: Angle(degrees: startAngle.degrees + Double(index) * angleBetweenCircleCenters.degrees))
        return CGRect(center: itemCenter, size: CGSize(width: itemDiameter, height: itemDiameter))
    }
    
    override func draw(_ rect: CGRect) {
        let center = rect.center
        menuItems = []
        
        if outlineConnected {
            let circleBackgroundPath = UIBezierPath(ovalIn: CGRect(center: center, size: CGSize(width: circleRadius * 2, height: circleRadius * 2)))
            let circleBackgroundLayer = CAShapeLayer()
            circleBackgroundLayer.path = circleBackgroundPath.cgPath
            circleBackgroundLayer.lineWidth = outlineWidth
            circleBackgroundLayer.strokeColor = outlineColor.cgColor
            circleBackgroundLayer.fillColor = UIColor.clear.cgColor
            layer.addSublayer(circleBackgroundLayer)
        }
        
        container = UIView(frame: rect)
        
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
    }
    
    var menuItemTransforms: [CGAffineTransform] = []
    func storeItemTransforms() {
        menuItemTransforms = menuItems.map{$0.transform}
    }
    
    func updateItemTransforms(angleDifference: CGFloat) {
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
    
    func decelerate(velocity: Vector2D, point: CGPoint) {
        storeItemTransforms()
        let vectorFromCenterToPoint = Vector2D(x: Double(point.x - container.center.x), y: Double(point.y - container.center.y))
        //math from here: http://math.stackexchange.com/a/116239
        let velocityTangentToCircle = vectorFromCenterToPoint.unitVector().crossProduct(velocity)
        print(velocityTangentToCircle)
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
                print("directedRotation: \(directedRotation)")
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
     /*   UIView.animate(withDuration: duration, delay: 0, options: [.allowUserInteraction, .curveEaseOut], animations: {
            self.container.transform = self.container.transform.rotated(by: CGFloat(radians))
            self.updateItemTransforms(angleDifference: CGFloat(radians))
        }) { finished in
            
        } */
    }
    
    func snapToNearestSector(duration: Double = 0.2, delay: Double = 0.0) {
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
    
    func nearestSector(angle: Double) -> Double {
        let sectorAngle = Angle(degrees: sectorWidth)
        let div = round(angle / sectorAngle.radians)
        return div * sectorAngle.radians
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let point = touch.location(in: self)
        return pointWithinPanDistance(point: point)
    }
    
    func pointWithinPanDistance(point: CGPoint) -> Bool {
        let distanceFromCenter = point.distance(toPoint: CGPoint(x: self.frame.size.width / 2.0, y: self.frame.size.height / 2.0))
        return distanceFromCenter > (CGFloat(circleRadius) - itemDiameter * 1.5) && distanceFromCenter < (CGFloat(circleRadius) + itemDiameter * 2)
    }
}

//reference: draws arcs between each circle to prevent overlap
/* 
 if outlineConnected {
 //draw connecting line to next circle
 let angleBetweenCircleCenters = Angle(degrees: 360.0 / Double(menuItems.count))
 let angleBetweenCircleEdges = self.angleBetweenCircleEdges()
 let startAngle = CGFloat(drawStartAngle.radians) + CGFloat(i) * CGFloat(angleBetweenCircleCenters.radians) + CGFloat(angleBetweenCircleCenterAndCircleEdge().radians)
 let endAngle = startAngle + CGFloat(angleBetweenCircleEdges.radians)
 let connectingPath = UIBezierPath(
 arcCenter: center,
 radius: CGFloat(circleRadius),
 startAngle: startAngle,
 endAngle: endAngle,
 clockwise: true)
 let arcLayer = CAShapeLayer()
 arcLayer.path = connectingPath.cgPath
 arcLayer.lineWidth = outlineWidth
 arcLayer.strokeColor = outlineColor.cgColor
 arcLayer.fillColor = UIColor.clear.cgColor
 layer.addSublayer(arcLayer)
 }
 
 //using law of cosines: C = acos((c^2 - a^2 - b^2)/(-2ab))
 func angleBetweenCircleCenterAndCircleEdge() -> Angle {
 let a = circleRadius
 let b = circleRadius
 let c = Double(itemDiameter / 2.0)
 let numerator = c * c - a * a - b * b
 let denominator = -2 * a * b
 return Angle(radians: acos(numerator / denominator))
 }
 
 func angleBetweenCircleEdges() -> Angle {
 let degreesFromEdgeToEdgeOfCircle = angleBetweenCircleCenterAndCircleEdge().degrees * 2.0
 let degreesCoveredByCircles = Double(menuItems.count) * degreesFromEdgeToEdgeOfCircle
 let remainingDegrees = 360 - degreesCoveredByCircles
 return Angle(degrees: remainingDegrees / Double(menuItems.count))
 }
 
 */
