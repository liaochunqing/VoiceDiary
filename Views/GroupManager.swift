//
//  GroupManager.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/9/28.
//

import Foundation
import SwiftUI

class GroupManager: ObservableObject {
    @Published var groups: [DiaryGroup] = [] {
        didSet {
            saveGroups()  // 每次数据变化时自动保存
        }
    }
    
    // 初始化时加载分组数据
    init() {
        loadGroups()
        if groups.isEmpty {
            let defaultGroups: [DiaryGroup] = [
                DiaryGroup(title: "全部", color: .red, icon: "house"),
                DiaryGroup(title: "生活", color: .green, icon: "house"),
                DiaryGroup(title: "工作", color: .blue, icon: "briefcase"),
                DiaryGroup(title: "情感", color: .pink, icon: "heart")
            ]
            groups = defaultGroups  // 如果没有数据，加载默认分组
        }
    }
    
    // 增加新分组
    func addGroup(title: String, color: Color, icon: String) {
        let newGroup = DiaryGroup(title: title, color: color, icon: icon)
        groups.append(newGroup)
    }
    
    // 删除分组
    func deleteGroup(at index: Int) {
        groups.remove(at: index)
    }
    
    // 保存分组数据到 UserDefaults（或其他存储方式）
    func saveGroups() {
        if let encoded = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(encoded, forKey: "DiaryGroups")
        }
    }
    
    // 从本地加载分组数据
    func loadGroups() {
        if let data = UserDefaults.standard.data(forKey: "DiaryGroups"),
           let decodedGroups = try? JSONDecoder().decode([DiaryGroup].self, from: data) {
            groups = decodedGroups
        }
    }
}

#Preview {
    ContentView()
}
