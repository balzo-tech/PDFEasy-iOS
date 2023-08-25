//
//  MathUtils.swift
//  PdfExpert
//
//  Created by Leonardo Passeri on 25/08/23.
//

import Foundation

struct Line {
    let slope: CGFloat
    let intercept: CGFloat
}

class MathUtils {
    
    static func getSlope(ofLinePassingThrough pointA: CGPoint, and pointB: CGPoint) -> CGFloat {
        let x1 = pointA.x
        let x2 = pointB.x
        let y1 = pointA.y
        let y2 = pointB.y
        
        return (y2 - y1) / (x2 - x1)
    }
    
    static func getIntercept(ofLinePassingThrough pointA: CGPoint, and pointB: CGPoint) -> CGFloat {
        let x1 = pointA.x
        let x2 = pointB.x
        let y1 = pointA.y
        let y2 = pointB.y
        
        return (x2*y1 - x1*y2) / (x2 - x1)
    }
    
    static func getLine(ofLinePassingThrough pointA: CGPoint, and pointB: CGPoint) -> Line {
        let slope = self.getSlope(ofLinePassingThrough: pointA, and: pointB)
        let intercept = self.getIntercept(ofLinePassingThrough: pointA, and: pointB)
        
        return Line(slope: slope,
                    intercept: intercept)
    }
}

extension Line {
    
    var direction: CGPoint {
        CGPoint(x: 1, y: self.slope).normalized
    }
    
    func getY(forX x: CGFloat) -> CGFloat {
        return x * self.slope + self.intercept
    }
    
    func closestPoint(toPoint point: CGPoint) -> CGPoint {
        let direction = self.direction
        let translatedPoint = CGPoint(x: point.x, y: point.y - self.intercept)
        let pointProjectionLength = CGPoint.dot(direction, translatedPoint)
        let translatedClosestPoint = direction.scale(by: pointProjectionLength)
        return CGPoint(x: translatedClosestPoint.x, y: translatedClosestPoint.y + self.intercept)
    }
}

extension CGPoint {
    
    var length: CGFloat {
        CGFloat(sqrtf(powf(Float(self.x), 2.0) + powf(Float(self.y), 2.0)))
    }
    
    var normalized: CGPoint {
        let length = self.length
        if length > 0.0 {
            return self.scale(by: 1.0 / length)
        } else {
            return .zero
        }
    }
    
    func scale(by scaleFactor: CGFloat) -> CGPoint {
        CGPoint(x: self.x * scaleFactor, y: self.y * scaleFactor)
    }
    
    static func dot(_ pointA: CGPoint, _ pointB: CGPoint) -> CGFloat {
        pointA.x * pointB.x + pointA.y * pointB.y
    }
}
