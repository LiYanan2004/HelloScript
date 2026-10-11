//
//  ContentView.swift
//  AppleHello
//
//  Created by Yanan Li on 2026/10/11.
//

import SwiftUI

struct ContentView: View {
    @SceneStorage("text") private var text = "hello"
    @State private var selectedFontWeight: Font.Weight = .regular
    @State private var drawingProgress: CGFloat = 1

    var body: some View {
        Form {
            Section {
                TextField("Text to Write", text: $text)
                Picker("Font Weight", selection: $selectedFontWeight) {
                    Text("Ultralight").tag(Font.Weight.ultraLight)
                    Text("Thin").tag(Font.Weight.thin)
                    Text("Light").tag(Font.Weight.light)
                    Text("Regular").tag(Font.Weight.regular)
                    Text("Medium").tag(Font.Weight.medium)
                    Text("Semibold").tag(Font.Weight.semibold)
                    Text("Bold").tag(Font.Weight.bold)
                    Text("Heavy").tag(Font.Weight.heavy)
                    Text("Black").tag(Font.Weight.black)
                }
            } header: {
                Text("Text")
            }

            Section {
                Slider(value: $drawingProgress.animation())
                Button("Replay") {
                    let duration = Double(text.count(where: { !$0.isWhitespace })) * 0.6

                    drawingProgress = 0
                    withAnimation(.bouncy(duration: duration)) {
                        drawingProgress = 1
                    }
                }
            } header: {
                Text("Writing Animation")
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .top, spacing: 20) {
            DrawingText(text, progress: drawingProgress)
                .font(.custom(.macintoshSkeletalVariable, size: 72).weight(selectedFontWeight))
                .containerRelativeFrame(.vertical, count: 2, spacing: 20)
        }
    }
}

#Preview {
    ContentView()
}
