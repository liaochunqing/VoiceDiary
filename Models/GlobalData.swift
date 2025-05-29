//
//  Untitled.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2025/3/18.
//
// 统一管理全局状态的核心类
import Foundation
import SwiftUI

class GlobalData: ObservableObject {
    @Published var diaryPages: [IdentifiedHostingController<AnyView>] = []
    @Published var backToList: Bool = false
    @Published var moveToPage: Bool = false
    @Published var moveToPageNoAnimate: Bool = false

    @Published var pageUpdate: Bool = false
    @Published var hideAddButton: Bool = false

    private let maxDiaryPages = 50
    var currentIndex: Int = -1
    
    //初始化
    func initializePages(with entries: [DiaryEntry]) {
        let coverHostingController = IdentifiedHostingController(id: UUID(), rootView: AnyView(CoverView()))
        let settingHostingController = IdentifiedHostingController(id: UUID(), rootView: AnyView(SettingsView()))
        let mainListHostingController = IdentifiedHostingController(id: UUID(), rootView: AnyView(MainListView()))
        
        self.diaryPages.append(coverHostingController)
        self.diaryPages.append(settingHostingController)
        self.diaryPages.append(mainListHostingController)
        
        let pages = entries.prefix(maxDiaryPages).map { entry in
                let diaryPage = DiaryPage(id: entry.id)
                return IdentifiedHostingController(id: entry.id, rootView: AnyView(diaryPage))
            }
        self.diaryPages.append(contentsOf: pages)
    }
    
    //根据index， 从entries加载maxDiaryPages个元素
    func getDiaryPagesCentered(at index: Int, from entries: [DiaryEntry]) -> [IdentifiedHostingController<AnyView>] {
        
        guard !entries.isEmpty, index >= 0, index < entries.count else {
            return []
        }

        let half = (maxDiaryPages) / 2
        let start = max(0, index - half)
        let end = min(entries.count-1, index<half ? maxDiaryPages : (index + half))

        let selectedEntries = entries[start...end]
        let pages = selectedEntries.map { entry in
            let diaryPage = DiaryPage(id: entry.id)
            return IdentifiedHostingController(id: entry.id, rootView: AnyView(diaryPage))
        }

        return pages
    }
    
    // 添加一个新的日记页面，并维护页面列表的大小
    func getIndexOfPageBy(entry: DiaryEntry, entries: [DiaryEntry])-> Int {
        //检查是否已经存在diaryPages当中
        if let existingIndex = diaryPages.firstIndex(where: { $0.id == entry.id }) {
            return existingIndex
        } else {//从数据库entries中调入
            
            return updatePageBy(entry: entry, entries: entries)
        }
    }
    
    ////先删除除了封面 设置 列表外的所有页面。从数据库中调入新的连续maxDiaryPages个页面
    func updatePageBy(entry: DiaryEntry, entries: [DiaryEntry])-> Int{
        //先删除除了封面 设置 列表外的所有页面
        if self.diaryPages.count > 3 {
            self.diaryPages = Array(self.diaryPages.prefix(3))
        }
        
        //从数据库中调入新的连续maxDiaryPages个页面
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            let pages = getDiaryPagesCentered(at: index, from: entries)
            self.diaryPages += pages

            if let existingIndex = self.diaryPages.firstIndex(where: { $0.id == entry.id }) {
                return existingIndex
            }
        }
        
        return 2
    }
}
