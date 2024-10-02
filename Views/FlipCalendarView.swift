//
//  SwiftUIView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/14.
//

import SwiftUI

struct FlipCalendarView: View {
    @State private var currentDate = Date()
    
    var body: some View {
        VStack {
            HStack {
                FlipView(number: Calendar.current.component(.year, from: currentDate))
//                Text(",")
                FlipView(number: Calendar.current.component(.month, from: currentDate))
//                Text(",")
                FlipView(number: Calendar.current.component(.day, from: currentDate))
            }
//            .padding(.horizontal,W_SCALE(1))
            .font(.system(size: W_SCALE(20), weight: .bold, design: .monospaced))
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 100, repeats: true) { _ in
                    self.currentDate = Date()
                }
            }
        }
//        .background(Color.red)
    }
}

struct FlipView: View {
    var number: Int
    
    var body: some View {
        Text(String(format: "%02d", number))
            .frame(width: W_SCALE(65), height: H_SCALE(36))
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray, lineWidth: 1)
            )
    }
}

#Preview {
    ContentView()
}
