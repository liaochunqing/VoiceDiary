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
    @StateObject private var locationManager = LocationManager()
    @FocusState private var isFocused: Bool

    @State private var date: Date = Date()
    @State private var diaryContent: String = ""
    @State private var address: String = ""
    @State private var selectedMood: String = "🙂"
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
                            entry.location = address
                            entry.selectedMood = selectedMood
                        } else {
                            let newEntry = DiaryEntry(
                                id: UUID(),
                                content: diaryContent,
                                date: date,
                                location: address,
                                selectedMood: selectedMood
                            )
                            modelContext.insert(newEntry)
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
                if let entry = existingEntry {
                    diaryContent = entry.content ?? ""
                    date = entry.date
                    address = entry.location ?? ""
                    selectedMood = entry.selectedMood
                } else {
//                    locationManager.requestLocation()
                    address = locationManager.address
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
            Text("\(selectedMood)(可选)")
                .font(.body)
            Spacer()
        }
        .padding(.top)
        .padding(.horizontal)
        .onTapGesture { showMoodPicker = true }
        .confirmationDialog("选择你的心情", isPresented: $showMoodPicker, titleVisibility: .visible) {
            ForEach(["😄 开心", "😊 满足", "🤔 思考", "😐 平静", "😢 难过", "😭 崩溃", "😡 生气", "😤 烦躁", "😴 疲惫", "🤒 不舒服", "🥳 兴奋", "🤯 累炸了"], id: \.self) { mood in
                Button(mood) { selectedMood = String(mood.prefix(1)) }
            }
            Button("取消", role: .cancel) {}
        }
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
            Text(address)
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
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    @Published var address: String = "正在获取位置..."
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        reverseGeocode(location: location)
        locationManager.stopUpdatingLocation() // 一次就够，节省电量
    }

    private func reverseGeocode(location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                var addressString = ""
                if let locality = placemark.locality {
                    addressString += locality
                }
                if let subLocality = placemark.subLocality {
                    addressString += " · \(subLocality)"
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
