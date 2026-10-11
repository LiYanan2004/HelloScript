//
//  CustomFontRegistery.swift
//  AppleHello
//
//  Created by Yanan Li on 2026/10/11.
//

import SwiftUI

extension Font {
    struct CustomName: RawRepresentable, ExpressibleByStringLiteral {
        var rawValue: String
        
        init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        init(stringLiteral value: StringLiteralType) {
            self.init(rawValue: value)
        }
    }
    
    static func custom(_ name: CustomName, size: CGFloat) -> Font {
        .custom(name.rawValue, size: size)
    }
    
    static func custom(_ name: CustomName, fixedSize: CGFloat) -> Font {
        .custom(name.rawValue, fixedSize: fixedSize)
    }
    
    static func custom(_ name: CustomName, size: CGFloat, relativeTo style: TextStyle) -> Font {
        .custom(name.rawValue, size: size, relativeTo: style)
    }
}

extension Font.CustomName {
    static let macintoshSkeletalFilled: Font.CustomName = "Macintosh Skeletal Filled"
    static let macintoshSkeletalVariable: Font.CustomName = "Macintosh Skeletal Variable"
}
