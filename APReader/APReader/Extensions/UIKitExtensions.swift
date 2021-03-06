//
//  UIKitExtensions.swift
//  APReader
//
//  Created by Tangos on 2020/7/25.
//  Copyright © 2020 Tangorios. All rights reserved.
//

import UIKit

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: self.size.width / 2.0,y: self.size.height / 2.0)
    }
}

extension CGPoint {
    func vector(to p1:CGPoint) -> CGVector {
        return CGVector(dx: p1.x - self.x, dy: p1.y - self.y)
    }
}

extension UIBezierPath {
    func moveCenter(to:CGPoint) -> Self {
        let bound = self.cgPath.boundingBox
        let center = bounds.center
        
        let zeroedTo = CGPoint(x: to.x - bound.origin.x, y: to.y - bound.origin.y)
        let vector = center.vector(to: zeroedTo)
        
        _ = offset(to: CGSize(width: vector.dx, height: vector.dy))
        return self
    }
    
    func offset(to offset:CGSize) -> Self {
        let t = CGAffineTransform(translationX: offset.width, y: offset.height)
        _ = applyCentered(transform: t)
        return self
    }
    
    func fit(into:CGRect) -> Self {
        let bounds = self.cgPath.boundingBox
        
        let sw = into.size.width / bounds.width
        let sh = into.size.height / bounds.height
        let factor = min(sw, max(sh, 0.0))
        
        return scale(x: factor, y: factor)
    }
    
    func scale(x:CGFloat, y:CGFloat) -> Self {
        let scale = CGAffineTransform(scaleX: x, y: y)
        _ = applyCentered(transform: scale)
        return self
    }
    
    
    func applyCentered(transform: @autoclosure () -> CGAffineTransform ) -> Self {
        let bound = self.cgPath.boundingBox
        let center = CGPoint(x: bound.midX, y: bound.midY)
        var xform = CGAffineTransform.identity
        
        xform = xform.concatenating(CGAffineTransform(translationX: -center.x, y: -center.y))
        xform = xform.concatenating(transform())
        xform = xform.concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        apply(xform)
        
        return self
    }
    
    convenience init(byConnectingThePoints points: [CGPoint]) {
        self.init()
        self.move(to: points[0])
        points.forEach({ self.addLine(to: $0) })
    }
}

extension UIViewController {
    func sceneDelegateWindow() -> UIWindow? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let sceneDelegate = windowScene.delegate as? SceneDelegate
            else {
                return nil
        }
        return sceneDelegate.window
    }
}

extension UIView {
    
    public var left: CGFloat {
        get {
            return self.frame.origin.x
        }
        set(newLeft) {
            var frame = self.frame
            frame.origin.x = newLeft
            self.frame = frame
        }
    }
    
    public var top: CGFloat {
        get {
            return self.frame.origin.y
        }
        
        set(newTop) {
            var frame = self.frame
            frame.origin.y = newTop
            self.frame = frame
        }
    }
    
    public var width: CGFloat {
        get {
            return self.frame.size.width
        }
        
        set(newWidth) {
            var frame = self.frame
            frame.size.width = newWidth
            self.frame = frame
        }
    }
    
    public var height: CGFloat {
        get {
            return self.frame.size.height
        }
        
        set(newHeight) {
            var frame = self.frame
            frame.size.height = newHeight
            self.frame = frame
        }
    }
    
    public var right: CGFloat {
        get {
            return self.left + self.width
        }
    }
    
    public var bottom: CGFloat {
        get {
            return self.top + self.height
        }
    }
    
    public var centerX: CGFloat {
        get {
            return self.center.x
        }
        
        set(newCenterX) {
            var center = self.center
            center.x = newCenterX
            self.center = center
        }
    }
    
    public var centerY: CGFloat {
        get {
            return self.center.y
        }
        
        set(newCenterY) {
            var center = self.center
            center.y = newCenterY
            self.center = center
        }
    }
}

extension String {
    subscript(_ i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
    
    func subString(_ begin: Int, _ count: Int) -> String {
        let start = self.index(self.startIndex, offsetBy: max(0, begin))
        let end = self.index(self.startIndex, offsetBy: min(self.count, begin + count))
        return String(self[start..<end])
    }
    
    func subString(_ index: Int) -> String {
        let theIndex = self.index(self.endIndex, offsetBy: index - self.count)
        return String(self[theIndex..<endIndex])
    }
}

extension Date {
    func date2String(dateFormat: String = "yyyy-MM-dd HH:mm") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.init(identifier: "US")
        formatter.dateFormat = dateFormat
        let date = formatter.string(from: self)
        return date
    }
}

extension UIColor {
    static func hex(_ val: UInt) -> UIColor {
        var r: UInt = 0, g: UInt = 0, b: UInt = 0;
        var a: UInt = 0xFF
        var rgb = val
        
        if (val & 0xFFFF0000) == 0 {
            a = 0xF
            
            if val & 0xF000 > 0 {
                a = val & 0xF
                rgb = val >> 4
            }
            
            r = (rgb & 0xF00) >> 8
            r = (r << 4) | r
            
            g = (rgb & 0xF0) >> 4
            g = (g << 4) | g
            
            b = rgb & 0xF
            b = (b << 4) | b
            
            a = (a << 4) | a
            
        } else {
            if val & 0xFF000000 > 0 {
                a = val & 0xFF
                rgb = val >> 8
            }
            
            r = (rgb & 0xFF0000) >> 16
            g = (rgb & 0xFF00) >> 8
            b = rgb & 0xFF
        }
                
        return UIColor(red: CGFloat(r) / 255.0,
                       green: CGFloat(g) / 255.0,
                       blue: CGFloat(b) / 255.0,
                       alpha: CGFloat(a) / 255.0)
    }
    
    static func rgb(red: CGFloat, green: CGFloat, blue: CGFloat) -> UIColor {
        return UIColor(red: red/255, green: green/255, blue: blue/255, alpha: 1)
    }
}

extension UITextField {
    func shake() {
        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = CGPoint(x: self.center.x - 4, y: self.center.y)
        animation.toValue = CGPoint(x: self.center.x + 4, y: self.center.y)
        animation.duration = 0.05
        animation.repeatCount = 5
        animation.autoreverses = true
        self.layer.add(animation, forKey: "position")
    }
}
