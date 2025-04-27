//
//  AddDiaryView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2025/3/20.
//

// AddDiaryView.swift
import SwiftUI
import SwiftData

import Foundation
import CoreLocation
import Combine

struct AddDiaryView: View {
    // MARK: - 输入参数
    var existingEntry: DiaryEntry?
    @Binding var isPresented: Bool

    // MARK: - 状态
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var globalData: GlobalData
    @EnvironmentObject var locationManager: LocationManager

    @Query(sort:\DiaryEntry.date, order: .reverse) private var diaryEntries: [DiaryEntry]

    @FocusState private var isFocused: Bool

    @State private var date: Date = Date()
    @State private var diaryContent: String = ""
    @State private var emojiString: String = "🙂"
    @State private var showMoodPicker = false

    let infoRowSpacing: CGFloat = W_SCALE(10)

    // MARK: - 逻辑判断
    var isEditing: Bool {
        existingEntry != nil
    }

    // MARK: - 主体视图
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.secondarySystemBackground)
                    .ignoresSafeArea()

                VStack(spacing: H_SCALE(10)) {
                    moodPicker
                    wordCount
                    locationInfo
                    diaryEditor
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(formatDate_onlyDate(date))
                        .font(.custom("HelveticaNeue-Regular", size: W_SCALE(32)))
                        .tracking(-1)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { isPresented = false }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: W_SCALE(40), height: W_SCALE(40))
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
                            Image(systemName: "xmark")
                                .foregroundColor(.black)
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if diaryContent.isEmpty { return }

                        if let entry = existingEntry {
                            entry.content = diaryContent
                            entry.date = date
                            entry.location = locationManager.address
                            entry.emojiString = emojiString
                        } else {
                            let newEntry = DiaryEntry(
                                id: UUID(),
                                content: diaryContent,
                                date: date,
                                location: locationManager.address,
                                emojiString: emojiString
                            )
                            modelContext.insert(newEntry)
                            let index = globalData.getIndexOfPageBy(entry: newEntry, entries: diaryEntries)
                            globalData.pageUpdate = true

                            //如果当前界面不是在列表界面，则跳转到新增页面
                            if globalData.currentIndex > 2{
                                globalData.currentIndex = index
                                globalData.moveToPage = true
                            }
                        }

                        try? modelContext.save()

                        withAnimation(.spring) {
                            isPresented = false
                        }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        
                        
                    } label: {
                        ZStack {
                            Circle()
                                .fill(diaryContent.isEmpty ? Color.gray.opacity(0.3) : Color.white)
                                .frame(width: W_SCALE(40), height: W_SCALE(40))
                                .shadow(color: diaryContent.isEmpty ? Color.clear : Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
                            Image(systemName: "checkmark")
                                .foregroundColor(diaryContent.isEmpty ? .gray : .black)
                        }
                    }
                    .disabled(diaryContent.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                        isFocused = true
                }
                
                if let entry = existingEntry {
                    diaryContent = entry.content ?? ""
                    date = entry.date
                    emojiString = entry.emojiString
                }
            }
        }
    }

    // MARK: - 子视图组件
    private var moodPicker: some View {
        HStack(spacing: infoRowSpacing) {
            Image(systemName: "face.smiling")
            Text("\(emojiString)(可选)")
                .font(.body)
            Spacer()
        }
        .padding(.top)
        .padding(.horizontal)
        .onTapGesture { showMoodPicker = true }
        
        .fullScreenCover(isPresented: $showMoodPicker) {
            MoodPickerView(selectedEmoji: $emojiString, moodCategories: moodCategories)
        }
//        .confirmationDialog("选择你的心情", isPresented: $showMoodPicker, titleVisibility: .visible) {
//            ForEach(["😄 开心", "😊 满足", "🤔 思考", "😐 平静", "😢 难过", "😭 崩溃", "😡 生气", "😤 烦躁", "😴 疲惫", "🤒 不舒服", "🥳 兴奋", "🤯 累炸了"], id: \.self) { mood in
//                Button(mood) { emojiString = String(mood.prefix(1)) }
//            }
//            Button("取消", role: .cancel) {}
//        }
    }

    private var wordCount: some View {
        HStack(spacing: infoRowSpacing) {
            Image(systemName: "character")
                .foregroundColor(.gray)
            Text("字数 \(diaryContent.count)")
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var locationInfo: some View {
        HStack(spacing: infoRowSpacing) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundColor(.gray)
            Text(locationManager.address)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var diaryEditor: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color(.secondarySystemBackground))
                .cornerRadius(25)
                .shadow(color: Color.white.opacity(1.0), radius: 0, x: -2, y: -2)

            if diaryContent.isEmpty {
                Text("写点什么…")
                    .foregroundColor(.gray)
                    .font(.system(.body, design: .rounded))
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            }

            TextEditor(text: $diaryContent)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding()
                .focused($isFocused)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


struct MoodCategory: Identifiable {
    let id = UUID()
    let name: String
    let emojis: [String]
}

let moodCategories: [MoodCategory] = [
    MoodCategory(name: "喜", emojis: ["😊", "😄", "😆", "😋"]),
    MoodCategory(name: "怒", emojis: ["😠", "😡", "😤", "😒"]),
    MoodCategory(name: "忧", emojis: ["😟", "😕", "🙁", "😣"]),
    MoodCategory(name: "思", emojis: ["🤔", "🧐", "😐", "😶"]),
    MoodCategory(name: "悲", emojis: ["😢", "😭", "😞", "😔"]),
    MoodCategory(name: "恐", emojis: ["😨", "😰", "😱", "😖"]),
    MoodCategory(name: "惊", emojis: ["😲", "😳", "😯", "😧"])
]

struct MoodPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedEmoji: String

    let moodCategories: [MoodCategory]

    // 定义每行显示的表情数量
    let columns = [GridItem(.adaptive(minimum: 50))]

    var body: some View {
        NavigationView {
            ScrollView {
                ForEach(moodCategories) { category in
                    HStack {
                        Text(category.name)
                            .font(.title)
                            .frame(width: W_SCALE(50), alignment: .leading)
                            .padding(.leading)

                        LazyVGrid(columns: columns, spacing: W_SCALE(20)) {
                            ForEach(category.emojis, id: \.self) { emoji in
                                Button(action: {
                                    selectedEmoji = emoji
                                    dismiss()
                                }) {
                                    Text(emoji)
                                        .font(.system(size: W_SCALE(35)))
                                        .frame(width: W_SCALE(35), height: W_SCALE(35))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .padding(.top)
                }
            }
            .navigationTitle("选择你的心情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    @Published var address: String = "正在获取位置..."
    private var hasUpdatedLocation = false // ✅ 新增标志位
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !hasUpdatedLocation, let location = locations.first else { return }
        
        hasUpdatedLocation = true // ✅ 防止多次触发
        reverseGeocode(location: location)
        locationManager.stopUpdatingLocation()
    }
    
    private func reverseGeocode(location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                var addressString = ""
                if let locality = placemark.locality {
                    addressString += locality
                }
                if let name = placemark.name {
                    addressString += " · \(name)"
                }
                self.address = addressString
            } else {
                self.address = "无法获取地址"
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GlobalData())
        .modelContainer(
                    // ✅ 创建专用于预览的内存存储容器
                    try! ModelContainer(
                        for: DiaryEntry.self,
                        configurations: ModelConfiguration(
                            isStoredInMemoryOnly: true  // 内存存储不污染正式数据
                        )
                    )
                )

}
