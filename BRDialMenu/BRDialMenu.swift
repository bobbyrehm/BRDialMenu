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

typealias BRDialMenuItem = UIButton

@IBDesignable
class BRDialMenu: UIView {

    var menuItems: [BRDialMenuItem] = []
    @IBInspectable var itemDiameter: CGFloat = 30.0
    @IBInspectable var outlineColor: UIColor = .white
    @IBInspectable var outlineConnected: Bool = true
    @IBInspectable var outlineWidth: CGFloat = 3.0
    @IBInspectable var startDegrees: CGFloat = 0 { //0 degrees = 3 PM on clock, moving clockwise
        didSet {
            self.drawStartAngle = Angle(degrees: Double(startDegrees))
        }
    }
    
    var drawStartAngle = Angle(degrees: 0) //0 degrees = 3 PM on clock, moving clockwise

    private var firstDraw = true
    
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
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        isOpaque = false
        backgroundColor = UIColor.clear
        clearsContextBeforeDrawing = true
    }
    
    //using law of cosines: C = acos((c^2 - a^2 - b^2)/(-2ab))
    func angleBetween(point pointA: CGPoint, andPoint pointB: CGPoint) -> Angle {
        let center = self.center
        let a = Double(center.distance(toPoint: pointA))
        let b = Double(center.distance(toPoint: pointB))
        let c = Double(pointA.distance(toPoint: pointB))
        let numerator = c * c - a * a - b * b
        let denominator = -2 * a * b
        return Angle(radians: acos(numerator / denominator))
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
    
    func frameForItem(atIndex index: Int, startAngle: Angle, center: CGPoint) -> CGRect {
        let angleBetweenCircleCenters = Angle(degrees: 360.0 / Double(menuItems.count))
        let itemCenter = CGPoint.pointOnCircumference(origin: center, radius: circleRadius, angle: Angle(degrees: startAngle.degrees + Double(index) * angleBetweenCircleCenters.degrees))
        return CGRect(center: itemCenter, size: CGSize(width: itemDiameter, height: itemDiameter))
    }
    
    override func draw(_ rect: CGRect) {
        let center = rect.center
        
        if outlineConnected {
            let circleBackgroundPath = UIBezierPath(ovalIn: CGRect(center: center, size: CGSize(width: circleRadius * 2, height: circleRadius * 2)))
            let circleBackgroundLayer = CAShapeLayer()
            circleBackgroundLayer.path = circleBackgroundPath.cgPath
            circleBackgroundLayer.lineWidth = outlineWidth
            circleBackgroundLayer.strokeColor = outlineColor.cgColor
            circleBackgroundLayer.fillColor = UIColor.clear.cgColor
            layer.addSublayer(circleBackgroundLayer)
        }
        
        for i in 0..<menuItems.count {
            let item = menuItems[i]
            item.frame = frameForItem(atIndex: i, startAngle: drawStartAngle, center: center)
            item.layer.borderColor = outlineColor.cgColor
            item.layer.borderWidth = outlineWidth
            item.layer.cornerRadius = item.frame.size.width / 2.0
            item.clipsToBounds = true
            addSubview(item)
        }
    }
}


// MARK: Touch Handling
/*
extension BRDialMenu {
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let currentLocation = touch.location(in: self)
        let previousLocation = touch.previousLocation(in: self)
        let currentAngle = atan2(currentLocation.y - center.y, currentLocation.x - center.x)
        let previousAngle = atan2(previousLocation.y - center.y, previousLocation.x - center.x)
        let deltaAngle = angleBetween(point: currentLocation, andPoint: previousLocation).degrees
        if (previousAngle < currentAngle) {
           // deltaAngle = -1 * deltaAngle
        }
        print("CurrentAngle: \(currentAngle)\nPreviousAngle: \(previousAngle)\nDeltaAngle: \(deltaAngle)")
        //self.transform = CGAffineTransform(rotationAngle: CGFloat(angle.radians))
        drawStartAngle = Angle(degrees: drawStartAngle.degrees + Double(deltaAngle))
        setNeedsDisplay()
    }
}
*/

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
 */
