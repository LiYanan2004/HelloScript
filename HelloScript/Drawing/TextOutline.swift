//
//  TextOutline.swift
//  AppleHello
//
//  Created by Yanan Li on 2026/10/11.
//

import CoreText
import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
#else
import AppKit
typealias PlatformFont = NSFont
#endif

/// Reveals the original glyph boundaries in writing order, retaining their local thickness.
struct TextOutline: Shape {
    var progress: CGFloat
    
    private let geometry: Geometry
    
    init(_ text: LocalizedStringResource, font: PlatformFont, progress: CGFloat = 1) {
        self.progress = progress
        geometry = Geometry(text, font: font)
    }
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        geometry.outline(upTo: progress).applying(geometry.transform(in: rect))
    }
}

fileprivate extension TextOutline {
    struct Geometry {
        private let completeOutline: Path
        private let layoutBounds: CGRect
        private let strokes: [Stroke]
        private let length: CGFloat

        init(_ text: LocalizedStringResource, font: PlatformFont) {
            let attributedString = NSAttributedString(
                string: String(localized: text),
                attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]
            )
            let line = CTLineCreateWithAttributedString(attributedString)
            let textOutline = CGMutablePath()
            let completeOutline = CGMutablePath()
            var strokes: [Stroke] = []

            for run in CTLineGetGlyphRuns(line) as! [CTRun] {
                let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
                let glyphCount = CTRunGetGlyphCount(run)
                var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
                var positions = [CGPoint](repeating: .zero, count: glyphCount)
                CTRunGetGlyphs(run, CFRange(), &glyphs)
                CTRunGetPositions(run, CFRange(), &positions)

                for glyphIndex in glyphs.indices {
                    guard let outline = CTFontCreatePathForGlyph(runFont, glyphs[glyphIndex], nil) else {
                        continue
                    }
                    let translation = CGAffineTransform(
                        translationX: positions[glyphIndex].x,
                        y: positions[glyphIndex].y
                    )
                    textOutline.addPath(outline, transform: translation)
                    guard let glyphStrokes = SkeletalOutline.strokes(from: outline, transform: translation) else {
                        continue
                    }
                    completeOutline.addPath(outline, transform: translation)
                    strokes.append(contentsOf: glyphStrokes)
                }
            }

            self.completeOutline = Path(completeOutline)
            self.strokes = strokes
            length = strokes.reduce(0) { $0 + $1.length }
            layoutBounds = textOutline.boundingBoxOfPath
        }

        func transform(in rect: CGRect) -> CGAffineTransform {
            guard !layoutBounds.isNull else { return .identity }
            return CGAffineTransform(
                a: 1, b: 0, c: 0, d: -1,
                tx: rect.midX - layoutBounds.midX,
                ty: rect.midY + layoutBounds.midY
            )
        }

        func outline(upTo progress: CGFloat) -> Path {
            guard progress > 0 else { return Path() }
            // Preserve Core Text's exact contours at completion, including caps and dots.
            guard progress < 1 else { return completeOutline }
            var remainingLength = length * progress
            var result = Path()
            for stroke in strokes {
                if remainingLength >= stroke.length {
                    result.addPath(stroke.outline)
                    remainingLength -= stroke.length
                } else {
                    let partial = stroke.outline(upTo: remainingLength)
                    return result.isEmpty ? partial : result.union(partial)
                }
            }
            return result
        }
    }
}

fileprivate extension TextOutline.Geometry {
    enum SkeletalOutline {
        static func strokes(from outline: CGPath, transform: CGAffineTransform) -> [Stroke]? {
            var strokes: [Stroke] = []
            var currentPoint: CGPoint?
            var segments: [CubicBezierSegment] = []
            var isSupported = true

            outline.applyWithBlock { elementPointer in
                guard isSupported else { return }
                let element = elementPointer.pointee
                switch element.type {
                case .moveToPoint:
                    guard currentPoint == nil else {
                        isSupported = false
                        return
                    }
                    currentPoint = element.points[0].applying(transform)
                case .addCurveToPoint:
                    guard let start = currentPoint else {
                        isSupported = false
                        return
                    }
                    segments.append(CubicBezierSegment(
                        start: start,
                        control1: element.points[0].applying(transform),
                        control2: element.points[1].applying(transform),
                        end: element.points[2].applying(transform)
                    ))
                    currentPoint = element.points[2].applying(transform)
                case .closeSubpath:
                    if let stroke = Stroke(segments) {
                        strokes.append(stroke)
                    } else {
                        isSupported = false
                    }
                    segments.removeAll(keepingCapacity: true)
                    currentPoint = nil
                default:
                    isSupported = false
                }
            }

            guard isSupported, currentPoint == nil else { return nil }
            return strokes
        }
    }

    struct Stroke {
        let outline: Path
        let length: CGFloat

        private let segments: [Segment]
        private let startCap: [CubicBezierSegment]

        init?(_ curves: [CubicBezierSegment]) {
            let count = curves.count
            guard count >= 4, count.isMultiple(of: 2),
                  curves[0].start.distance(to: curves[count - 1].end) < 0.001 else {
                return nil
            }

            var outline = Path()
            outline.move(to: curves[0].start)
            for curve in curves {
                curve.append(to: &outline)
            }
            outline.closeSubpath()
            self.outline = outline

            if count == 4 {
                let length = curves[0].start.distance(to: curves[2].start) * 0.001
                guard length > 0 else { return nil }
                self.length = length
                segments = []
                startCap = []
                return
            }

            // Forward edge, two end-cap curves, return edge, two start-cap curves.
            let sideCount = (count - 4) / 2
            let returning = curves[(sideCount + 2)..<(count - 2)].reversed().map(\.reversed)
            let segments = zip(curves.prefix(sideCount), returning).map {
                Segment(forward: $0, backward: $1)
            }
            let startWidth = segments[0].forward.start.distance(to: segments[0].backward.start)
            guard startWidth > 0,
                  segments.allSatisfy({
                      let width = $0.forward.end.distance(to: $0.backward.end)
                      return width > startWidth * 0.5 && width < startWidth * 2
                  }) else {
                return nil
            }

            self.segments = segments
            startCap = Array(curves.suffix(2))
            length = segments.reduce(0) { $0 + $1.length }
        }

        func outline(upTo distance: CGFloat) -> Path {
            guard distance > 0 else { return Path() }
            // A dot is a pen tap with its original contour, rather than a uniform-width stroke.
            guard !segments.isEmpty, distance < length else { return outline }
            var remainingLength = distance
            var forwardEdges: [CubicBezierSegment] = []
            var backwardEdges: [CubicBezierSegment] = []
            for segment in segments {
                if remainingLength >= segment.length {
                    forwardEdges.append(segment.forward)
                    backwardEdges.append(segment.backward)
                    remainingLength -= segment.length
                } else {
                    let parameter = segment.parameter(at: remainingLength)
                    forwardEdges.append(segment.forward.split(at: parameter).prefix)
                    backwardEdges.append(segment.backward.split(at: parameter).prefix)
                    break
                }
            }

            var result = Path()
            result.move(to: forwardEdges[0].start)
            for edge in forwardEdges {
                edge.append(to: &result)
            }
            result.addLine(to: backwardEdges.last!.end)
            for edge in backwardEdges.reversed() {
                edge.reversed.append(to: &result)
            }
            for curve in startCap {
                curve.append(to: &result)
            }
            result.closeSubpath()
            return result.intersection(outline)
        }

        private struct Segment {
            let forward: CubicBezierSegment
            let backward: CubicBezierSegment
            let length: CGFloat

            private let centerline: CubicBezierSegment

            init(forward: CubicBezierSegment, backward: CubicBezierSegment) {
                self.forward = forward
                self.backward = backward
                centerline = CubicBezierSegment(
                    start: forward.start.midpoint(to: backward.start),
                    control1: forward.control1.midpoint(to: backward.control1),
                    control2: forward.control2.midpoint(to: backward.control2),
                    end: forward.end.midpoint(to: backward.end)
                )
                length = centerline.approximateLength()
            }

            func parameter(at distance: CGFloat) -> CGFloat {
                var lower: CGFloat = 0
                var upper: CGFloat = 1
                for _ in 0..<14 {
                    let midpoint = (lower + upper) / 2
                    if centerline.split(at: midpoint).prefix.approximateLength() < distance {
                        lower = midpoint
                    } else {
                        upper = midpoint
                    }
                }
                return (lower + upper) / 2
            }
        }
    }
}

fileprivate extension TextOutline.Geometry {
    struct CubicBezierSegment {
        let start: CGPoint
        let control1: CGPoint
        let control2: CGPoint
        let end: CGPoint

        var reversed: CubicBezierSegment {
            CubicBezierSegment(start: end, control1: control2, control2: control1, end: start)
        }

        func append(to path: inout Path) {
            path.addCurve(to: end, control1: control1, control2: control2)
        }

        func split(at parameter: CGFloat) -> (prefix: Self, suffix: Self) {
            let first = start.interpolated(to: control1, fraction: parameter)
            let second = control1.interpolated(to: control2, fraction: parameter)
            let third = control2.interpolated(to: end, fraction: parameter)
            let fourth = first.interpolated(to: second, fraction: parameter)
            let fifth = second.interpolated(to: third, fraction: parameter)
            let midpoint = fourth.interpolated(to: fifth, fraction: parameter)
            return (
                Self(start: start, control1: first, control2: fourth, end: midpoint),
                Self(start: midpoint, control1: fifth, control2: third, end: end)
            )
        }

        func approximateLength(depth: Int = 0) -> CGFloat {
            let chord = start.distance(to: end)
            let polygon = start.distance(to: control1)
                + control1.distance(to: control2)
                + control2.distance(to: end)
            guard depth < 12, polygon - chord > 0.005 else { return (chord + polygon) / 2 }
            let halves = split(at: 0.5)
            return halves.prefix.approximateLength(depth: depth + 1)
                + halves.suffix.approximateLength(depth: depth + 1)
        }
    }
}

fileprivate extension CGPoint {
    func midpoint(to other: CGPoint) -> CGPoint {
        interpolated(to: other, fraction: 0.5)
    }

    func interpolated(to other: CGPoint, fraction: CGFloat) -> CGPoint {
        CGPoint(x: x + (other.x - x) * fraction, y: y + (other.y - y) * fraction)
    }

    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
