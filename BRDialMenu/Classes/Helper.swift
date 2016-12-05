//
//  Helper.swift
//  BRDialMenu
//
//  Created by Bobby Rehm on 12/5/16.
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

public enum Orientation: Double {
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

extension UIView {
    func constrainAndCenter(in view: UIView) -> [NSLayoutConstraint] {
        let xPad = (self.frame.size.width - view.frame.size.width) / 2.0
        let yPad = (self.frame.size.height - view.frame.size.height) / 2.0
        let left = self.leftAnchor.constraint(equalTo: view.leftAnchor, constant: -xPad)
        let right = self.rightAnchor.constraint(equalTo: view.rightAnchor, constant: xPad)
        let top = self.topAnchor.constraint(equalTo: view.topAnchor, constant: -yPad)
        let bottom = self.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: yPad)
        return [left, right, top, bottom]
    }
}
