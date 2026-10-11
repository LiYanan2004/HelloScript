//
//  DrawingText.swift
//  AppleHello
//
//  Created by Yanan Li on 2026/10/11.
//

import SwiftUI

/// Resolves the environment font and reveals its original glyph contours in writing order.
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct DrawingText: View {
    var text: LocalizedStringResource
    var progress: CGFloat

    @Environment(\.font) private var font
    @Environment(\.fontResolutionContext) private var fontResolutionContext

    init(_ text: LocalizedStringResource, progress: CGFloat = 1.0) {
        self.text = text
        self.progress = progress
    }

    @_disfavoredOverload
    init(_ text: String, progress: CGFloat = 1.0) {
        self.init(LocalizedStringResource(stringLiteral: text), progress: progress)
    }

    var body: some View {
        let platformFont = (font ?? .body)
            .resolve(in: fontResolutionContext).ctFont as PlatformFont
        Canvas { context, size in
            if let symbol = context.resolveSymbol(id: 0) {
                context.draw(symbol, at: CGPoint(x: size.width / 2, y: size.height / 2))
            }
        } symbols: {
            TextOutline(text, font: platformFont, progress: progress)
                .fill()
                .tag(0)
        }
        .accessibilityLabel(Text(text))
    }
}
