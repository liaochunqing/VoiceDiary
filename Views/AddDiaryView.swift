//
//  AddDiaryView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2025/3/20.
//

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
    @State private var showExitAlert = false

    @State private var date: Date = Date()
    @State private var diaryContent: String = ""
    @State private var emojiString: String = "🙂"
    @State private var selectedFontSize: CGFloat = W_SCALE(18)
    @State private var selectedFontStyle: String = "System"
    @State private var selectedFontColor: Color = .primary
    
    @State private var showMoodPicker = false
    @State private var showLocation = true
    @State private var showFontPicker = false

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
                    locationInfo
                    fontPicker
                    diaryEditor
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(formatDate_onlyDate(date))
                        .font(.custom("HelveticaNeue-Regular", size: W_SCALE(32)))
                        .foregroundStyle(.primary)
                        .tracking(-1)
                        .padding(.top)

                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { showExitAlert = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: W_SCALE(40), height: W_SCALE(40))
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
                            Image(systemName: "xmark")
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.top)
                    .alert("确定不保存就离开吗？", isPresented: $showExitAlert) {
                            Button("离开", role: .destructive) {
                                isPresented = false
                            }
                            Button("留下", role: .cancel) {}
                        }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if diaryContent.isEmpty { return }

                        if let entry = existingEntry {
                            entry.content = diaryContent
                            entry.date = date
                            entry.location = showLocation ? locationManager.address : ""
                            entry.emojiString = emojiString
                            entry.showLocation = showLocation
                            entry.fontColor = selectedFontColor
                            entry.fontSize = selectedFontSize
                            entry.fontStyle = selectedFontStyle
                        } else {
                            let newEntry = DiaryEntry(
                                id: UUID(),
                                content: diaryContent,
                                date: date,
                                location:  showLocation ? locationManager.address : "",
                                emojiString: emojiString,
                                showLocation: showLocation,
                                fontColorHex: selectedFontColor.toHex(),
                                fontStyle: selectedFontStyle,
                                fontSize: selectedFontSize
                            )
                            modelContext.insert(newEntry)
                            let index = globalData.getIndexOfPageBy(entry: newEntry, entries: diaryEntries)
                            globalData.pageUpdate = true

                            //如果当前界面不是在列表界面，则跳转到新增页面
                            if globalData.currentIndex > 2{
                                globalData.currentIndex = index
                                globalData.moveToPageNoAnimate = true
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
                                .fill(diaryContent.isEmpty ? Color.gray.opacity(0.1) : Color.white)
                                .frame(width: W_SCALE(40), height: W_SCALE(40))
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
                            Image(systemName: "checkmark")
                                .foregroundColor(.black.opacity(0.8))
                        }
                    }
                    .padding(.top)
                    .disabled(diaryContent.isEmpty)
                }
            }
            .onAppear {
                if let entry = existingEntry {
                    diaryContent = entry.content ?? ""
                    date = entry.date
                    emojiString = entry.emojiString
                    showLocation = entry.showLocation
                    selectedFontColor = entry.fontColor
                    selectedFontStyle = entry.fontStyle
                    selectedFontSize = entry.fontSize
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isFocused = true
                }
            }
        }
    }

    // MARK: - 子视图组件
    private var moodPicker: some View {
        HStack(spacing: infoRowSpacing) {
            Image(systemName: "face.smiling")
            Text("\(emojiString)")
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: W_SCALE(30), height: W_SCALE(30))
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.black)
            }

        }
        .padding(.top)
        .padding(.horizontal)
        .contentShape(Rectangle()) // 扩展点击区域
        .onTapGesture { showMoodPicker = true }
//        .fullScreenCover(isPresented: $showMoodPicker) {
//            ZStack {
//                // 半透明背景，点击可关闭
//                Color.black.opacity(0.7)
//                    .ignoresSafeArea()
//                    .onTapGesture {
//                        showMoodPicker = false
//                    }
//
//                // 居中的 MoodPickerView
//                MoodPickerView(selectedEmoji: $emojiString, moodCategories: moodCategories)
//                    .frame(width: Screen.width-W_SCALE(32), height: Screen.height*0.8)
//                    .background(.white)
//                    .cornerRadius(8)            }
//            .presentationBackground(.clear) // 设置背景为透明
//        }
        .sheet(isPresented: $showMoodPicker) {
            MoodPickerView(selectedEmoji: $emojiString, moodCategories: moodCategories)
                            .presentationDetents([.fraction(0.9)])
                            .presentationDragIndicator(.visible) // 显示顶部的拖动指示器
        }
    }
    
    
    // MARK: - 子视图组件
    private var locationInfo: some View {
        HStack(spacing: infoRowSpacing) {
            Image(systemName: "mappin.and.ellipse")

            if showLocation{
                Text(locationManager.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

            }
            
            Spacer()
            Toggle("", isOn: $showLocation)
        }
        .padding(.horizontal)
//        .padding(.bottom)
    }
    
    // MARK: - 子视图组件
    private var fontPicker: some View {
        HStack(spacing: infoRowSpacing) {
            Image(systemName: "character.cursor.ibeam")
            Text("字数 \(diaryContent.count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: W_SCALE(30), height: W_SCALE(30))
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal)
        .onTapGesture { showFontPicker = true }
        .sheet(isPresented: $showFontPicker) {
            FontSelectorView(selectedFontSize:$selectedFontSize, selectedFontStyle:$selectedFontStyle,selectedFontColor: $selectedFontColor)
                            .presentationDetents([.fraction(0.8)])
                            .presentationDragIndicator(.visible) // 显示顶部的拖动指示器
        }
    }

    // MARK: - 子视图组件
    private var diaryEditor: some View {
        ZStack(alignment: .topLeading) {
            Color(.secondarySystemBackground)
                .ignoresSafeArea()
            
            Rectangle()
                .fill(Color(.secondarySystemBackground))
                .cornerRadius(25)
                .shadow(color: Color.white.opacity(1.0), radius: 0, x: -1, y: -1)

            if diaryContent.isEmpty {
                Text("写点什么…")
                    .foregroundColor(.gray)
                    .font(.system(.body, design: .rounded))
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            }

            TextEditor(text: $diaryContent)
                .font(.custom(selectedFontStyle, size: selectedFontSize))
                .foregroundStyle(selectedFontColor)
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
                            .font(.title2)
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
            .navigationTitle("现在我的心情")
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


struct FontSelectorView: View {
    @Binding var selectedFontSize: CGFloat
    @Binding var selectedFontStyle: String
    @Binding var selectedFontColor: Color

    @State private var fontSizeOption: FontSizeOption = .medium

    let fontEnNames = [
        "System",
        "ChalkboardSE-Regular",
        "Papyrus",
        "BradleyHandITCTT-Bold",
        "SnellRoundhand",
        "Zapfino",
        "Noteworthy-Light",
        "HelveticaNeue-Thin",
        "AvenirNext-Regular",
        "YOUSHEhaoshenti",
    ]

    let fontChNames = [
        "System",
        "LongCang-Regular",
        "YOUSHEhaoshenti",
        "Slidexiaxing-Regular",
        "BodoniSvtyTwoSCITCTT-Book",
        "PingFangSC-Ultralight",
        "ZQKNLT-Regular"
    ]

    var body: some View {
        let languageCode = Locale.preferredLanguages.first ?? "en"

        let fontNames: [String] = languageCode.contains("zh") ? fontChNames : fontEnNames
        let sampleText = languageCode.contains("zh") ? "我是字体样式" : "I am a font style"

        VStack(spacing: 20) {
            Text("\(languageCode.contains("zh") ? "我是示例文本" : "I am an example text")")
                .font(selectedFontStyle == "System" ? .body : .custom(selectedFontStyle, size: selectedFontSize))
                .foregroundColor(selectedFontColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: Screen.height * 0.06)
                .padding(.horizontal)
                .padding(.top)


            HStack {
                Text("字体大小:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                Spacer()

                Picker("", selection: $fontSizeOption) {
                    ForEach(FontSizeOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                            .font(.body)

                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: fontSizeOption) {
                    selectedFontSize = fontSizeOption.size
                    }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(W_SCALE(15))
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)

            
            HStack {
                Text("字体颜色:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                Spacer()

                ColorPicker("", selection: $selectedFontColor)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(W_SCALE(15))
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
            
            VStack {
                Text("选择字体:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding()

                ScrollView {
                LazyVStack(alignment: .center, spacing: 10) {
                        ForEach(fontNames, id: \.self) { font in
                            Button(action: {
                                selectedFontStyle = font
                            }) {
                                Text(sampleText)
                                    .font(font == "System" ? .system(size: W_SCALE(18)) : .custom(font, size: W_SCALE(17)))
                                    .foregroundColor(selectedFontStyle == font ? .blue : .primary)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedFontStyle == font ? Color.blue.opacity(0.1) : Color.clear)
                                    )
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(W_SCALE(15))
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 1, y: 1)
            
            Spacer()
        }
        .padding(.horizontal)

    }
}

enum FontSizeOption: String, CaseIterable, Identifiable {
    case extraSmall = "特小"
    case small = "小"
    case medium = "中"
    case large = "大"
    case extraLarge = "特大"

    var id: String { self.rawValue }

    var size: CGFloat {
        switch self {
        case .extraSmall: return W_SCALE(14)
        case .small: return W_SCALE(18)
        case .medium: return W_SCALE(22)
        case .large: return W_SCALE(28)
        case .extraLarge: return W_SCALE(34)
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    @Published var address: String = ""
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
                self.address = ""
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
