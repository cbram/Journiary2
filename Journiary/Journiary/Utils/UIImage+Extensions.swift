//
//  UIImage+Extensions.swift
//  Journiary
//
//  Created by AI Assistant on 11.06.25.
//

import UIKit

extension UIImage {
    
    /// Rotiert das Bild um den angegebenen Winkel in Radians
    func rotate(radians: CGFloat) -> UIImage {
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, scale)
        if let context = UIGraphicsGetCurrentContext() {
            let origin = CGPoint(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            context.translateBy(x: origin.x, y: origin.y)
            context.rotate(by: radians)
            draw(in: CGRect(x: -origin.x, y: -origin.y, width: size.width, height: size.height))
        }
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage ?? self
    }
    
    /// Skaliert das Bild auf die angegebene Größe
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? self
    }
    
    /// Skaliert das Bild proportional auf die angegebene Größe
    func resizedToFit(size: CGSize) -> UIImage {
        let aspectRatio = self.size.width / self.size.height
        let targetAspectRatio = size.width / size.height
        
        var targetSize = size
        if aspectRatio > targetAspectRatio {
            // Bild ist breiter
            targetSize.height = size.width / aspectRatio
        } else {
            // Bild ist höher
            targetSize.width = size.height * aspectRatio
        }
        
        return resized(to: targetSize)
    }
} 