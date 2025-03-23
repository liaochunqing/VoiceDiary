//
//  Untitled.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2025/3/18.
//
import SwiftUI

// 统一管理全局状态的核心类
class GlobalData: ObservableObject {
    @Published var listRotationAngle: Double = 0.0
    @Published var targetPageIndex: Int = -1
    
}
