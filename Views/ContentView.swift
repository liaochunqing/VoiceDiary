//
//  ContentView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/8/30.
//

import SwiftUI

struct ContentView: View {
    @State private var isSettingsPresented = false
//    @State private var isDiaryPresented = false

    @State private var offset: CGFloat = -Screen.width // 初始偏移量为负值，隐藏设置界面
    @State private var startLocation: CGFloat = -1 // 手势起点
    
//    @State private var showSettingsView = false
    @State private var selectedItem: Int? = nil // 选中的项目索引

//    @State private var flipped = false
    @State private var rotationAngle: Double = 0.0

    var body: some View {
        ZStack {
            VStack {
                DiaryView()
            }
            
            VStack {
                //头部显示区域
                ZStack {
                    VStack
                    {
                        FlipCalendarView()
                        HistoryTodayView()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white) // 设置背景色
                    
                    optionButtonView()
                }
                
                            
                ZStack {

                    mainListView(offset: $offset, startLocation: $startLocation)
    //                SettingsView(offset: $offset, startLocation: $startLocation)
                        
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                                
                            // 新添日记按钮
                            Button(action: {
//                                isDiaryPresented = true
                                withAnimation(.easeIn(duration: 1)) {
                                    
                                    rotationAngle = -90 // 增加旋转角度
                                }
                            })
                            {
                                NeumorphicButton(iconName: "plus").scaleEffect(1.5)
                            }
//                            .fullScreenCover(isPresented: $isDiaryPresented) {
    //                            DiaryView()
//                            }
                        }
                        .padding().padding(.bottom).padding(.bottom)
                    }
                    .padding()
                }

                Spacer()
            }
            .ignoresSafeArea(edges: [.bottom])  // 忽略底部的安全区域
            .background(Color(.secondarySystemBackground))  // 使用系统默认背景颜色
            .rotation3DEffect(Angle(degrees:rotationAngle),
                                      axis: (x: 0.0, y: 1.0, z: 0.0),
                              anchor: .leading,
                                      anchorZ: 0.0,
                              perspective:0.6
                                )
            .allowsHitTesting(rotationAngle == 0)
        }  // 只有当未旋转时允许点击
    }
}

struct optionButtonView: View {
//    @State private var isSettingsPresented = false
//    @State private var isDiaryPresented = false

//    @State private var offset: CGFloat = -Screen.width // 初始偏移量为负值，隐藏设置界面
//    @State private var startLocation: CGFloat = -1 // 手势起点
    
    @State private var showSettingsView = false
//    @State private var selectedItem: Int? = nil // 选中的项目索引
    
    var body: some View {
        HStack
        {
            Button{
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSettingsView = true
//                    offset = 0  // 将偏移量设为 0，动画展示
//                    startLocation = 1
                                    }
            }  label: {
                Image(systemName: "list.bullet") // 添加系统图片
                    .font(.system(size: 25))
                    .foregroundColor(.black)
                    .shadow(color: .gray, radius: 10,x: 0,y: 10)
            }
//            .fullScreenCover(isPresented: $showSettingsView) { // 弹出详情页
//                SettingsView(offset: $offset, startLocation: $startLocation)
//            }

            Spacer()
        }
        .padding()
        .offset(x: 0, y: -40) // 偏移量可以调整
    }
}

struct HistoryTodayView: View {
    @State private var currentEvent: WikiEvent? = nil
    @State private var events: [WikiEvent] = [] // 缓存所有历史事件
    @State private var timer: Timer? = nil
    @State private var showDetailView = false // 控制是否显示详情页
    @Namespace private var animationNamespace // 用于动画

    var body: some View {
        VStack {
            if let event = currentEvent {
                Text("\(String(event.year))   \(event.text)")
                    .font(.system(size: 16))
                    .lineLimit(2) // 限制为两行
                    .fixedSize(horizontal: false, vertical: true) // 垂直方向自适应大小
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(height: 70) // 固定高度
                    .onTapGesture {
                        showDetailView = true // 点击时显示详情页
                    }
                    .transition(.opacity) // 使用渐隐渐显动画
                    .animation(.easeInOut(duration: 0.5), value: currentEvent) // 添加动画
            } else {
                Text("加载中...")
                    .font(.system(size: 16))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .frame(height: 70) // 同样固定为两行高度
            }
        }
        .fullScreenCover(isPresented: $showDetailView) { // 弹出详情页
            HistoryView(events: events)
        }
        .onAppear {
            if events.isEmpty {
                fetchEventsAndStartAutoUpdate()
            } else {
                startAutoUpdate()
            }
        }
    }
    
    // 获取事件并开始自动更新
    private func fetchEventsAndStartAutoUpdate() {
        fetchWikiEvents { fetchedEvents in
            events = fetchedEvents
            currentEvent = events.first
            startAutoUpdate()  // 启动自动更新
        }
    }
    
    // 启动定时器，每5秒更新一次事件
    private func startAutoUpdate() {
        timer?.invalidate() // 确保不会重复创建定时器
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if !events.isEmpty {
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentEvent = events.randomElement()  // 随机选择一条事件并添加动画
                }
            }
        }
    }
    
    // 当视图销毁时，停止定时器
    private func stopAutoUpdate() {
        timer?.invalidate()
        timer = nil
    }
}

struct NeumorphicButton: View {
    var iconName: String
    
    var body: some View {
        ZStack {
            Circle()
//                .fill(Color(red: 241/255, green: 241/255, blue: 241/255)) // 设置背景颜色
                .fill(Color.blue.opacity(0.6)) // 设置背景颜色

                .frame(width: 50, height: 50) // 设置按钮大小
                .shadow(color: Color.white.opacity(0.7), radius: 10, x: -5, y: -5) // 亮影
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 5, y: 5) // 暗影
            
            Image(systemName: iconName)
//                .background(Color.blue)
                .foregroundColor(.black) // 设置图标颜色
                .font(.system(size: 25)) // 设置图标大小
        }
    }
}

#Preview {
    ContentView()
}
