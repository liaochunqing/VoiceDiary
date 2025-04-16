//
//  CoverView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2025/3/25.
//

import SwiftUI

struct CoverView: View {
    var body: some View {
            Image("cover1") // 替换为你的图片名称
                .resizable()
                .scaledToFill()
                .frame(maxWidth: UIScreen.main.bounds.width, maxHeight: UIScreen.main.bounds.height)
                .ignoresSafeArea()
        }
}
