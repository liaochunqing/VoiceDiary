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
    let infoRowSpacing: CGFloat = W_SCALE(10)

    @Binding var isPresented: Bool
    @State private var diaryContent: String = ""
    @FocusState private var isFocused: Bool
    @Environment(\.modelContext) private var modelContext
    @StateObject private var locationManager = LocationManager()
    @State private var selectedMood: String = "🙂"
    @State private var showMoodPicker = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.secondarySystemBackground)
                    .ignoresSafeArea() // 使背景颜色扩展到安全区域之外
                
                VStack (spacing: H_SCALE(10)){
                    // 心情
                    HStack(spacing: infoRowSpacing) {
                        Image(systemName: "face.smiling")
//                            .foregroundColor(.gray)
                        Text("\(selectedMood)(可选)")
                            .font(.body)
//                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.top)
                    .padding(.horizontal)
                    .onTapGesture {
                        showMoodPicker = true
                    }
                    .confirmationDialog("选择你的心情", isPresented: $showMoodPicker, titleVisibility: .visible) {
                        Button("😄 开心") { selectedMood = "😄" }
                        Button("😊 满足") { selectedMood = "😊" }
                        Button("🤔 思考") { selectedMood = "🤔" }
                        Button("😐 平静") { selectedMood = "😐" }
                        Button("😢 难过") { selectedMood = "😢" }
                        Button("😭 崩溃") { selectedMood = "😭" }
                        Button("😡 生气") { selectedMood = "😡" }
                        Button("😤 烦躁") { selectedMood = "😤" }
                        Button("😴 疲惫") { selectedMood = "😴" }
                        Button("🤒 不舒服") { selectedMood = "🤒" }
                        Button("🥳 兴奋") { selectedMood = "🥳" }
                        Button("🤯 累炸了") { selectedMood = "🤯" }
                        Button("取消", role: .cancel) { }
                    }

                    
                    // 字数
                    HStack(spacing: infoRowSpacing) {
                        Image(systemName: "character")
                            .foregroundColor(.gray)
                        Text("字数 \(diaryContent.count)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // 地点
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
                    
                    // 编辑框
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
                            .scrollContentBackground(.hidden) // 隐藏默认背景
                            .background(Color.clear)
                            .padding()
                            .focused($isFocused)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    isFocused = true
                                }
                            }
                        
//                        TextEditor(text: $diaryContent)
//                            .scrollContentBackground(.hidden) // 隐藏默认背景
//                            .background(Color.yellow)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline) // 可选，inline 更适合自定义字体
            .toolbar {
                //时间
                ToolbarItem(placement: .principal) {
                    Text(formatDate_onlyDate(Date()))
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
                        if !diaryContent.isEmpty {
                            let newEntry = DiaryEntry(id: UUID(),
                                                      content: diaryContent,
                                                      date: Date(),
                                                      location: locationManager.address,
                                                      selectedMood: selectedMood
                                                    )
                            modelContext.insert(newEntry)
                            
                            withAnimation(.spring) {
                                isPresented = false
                            }
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
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
        }
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
