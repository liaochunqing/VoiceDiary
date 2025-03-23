//
//  ContentView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2024/8/30.
//

import SwiftUI

struct ContentView: View {
    @State private var isSettingsPresented = false
    @State private var offset: CGFloat = -Screen.width // 初始偏移量为负值，隐藏设置界面
    @State private var startLocation: CGFloat = -1 // 手势起点
    @State private var selectedItem: Int? = nil // 选中的项目索引
    @EnvironmentObject var globalData: GlobalData
    @State private var showEditor = false

    var body: some View {
        ZStack {
            VStack {
                DiaryView()
            }
            
            VStack {
                //头部显示区域
                Spacer(minLength: 50)
                
                ZStack {
                    optionButtonView()
                    
                    Text("目录")
//                        .background(Color.yellow)
                        .font(.title)
                        .frame(maxWidth: .infinity, alignment: .center)  // 强制占满剩余空间并居中
                }

//                ZStack {
//                    VStack
//                    {
//                        FlipCalendarView()
//                        HistoryTodayView()
//                    }
//                    .frame(maxWidth: .infinity)
//                    .background(Color.white) // 设置背景色
                    
//                }
                
                            
                ZStack {

                    mainListView(offset: $offset, startLocation: $startLocation)
                        
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                                
                            // 新添日记按钮
                            Button(action: { showEditor.toggle() }) {
                                NeumorphicButton(iconName: "plus")
                                    .scaleEffect(1.5)
                            }
                            .sheet(isPresented: $showEditor) {
                                AddDiaryView(isPresented: $showEditor)
//                                    .presentationDetents([.medium, .large])
//                                    .presentationDragIndicator(.visible)
                                
                                    .presentationDetents([.fraction(0.995)]) // 核心高度控制[3](@ref)
                                    .presentationDragIndicator(.visible)
                                    .ignoresSafeArea(.container, edges: .bottom) // 底部安全区处理
                            }
                        }
                        .padding(.trailing) // 只需要一次 padding 来控制按钮位置
                        .padding(.bottom)
                    }
                    .padding()
                }

                Spacer()
            }
            .background(Color(.secondarySystemBackground))  // 使用系统默认背景颜色
            .rotation3DEffect(Angle(degrees:globalData.listRotationAngle),
                                      axis: (x: 0.0, y: 1.0, z: 0.0),
                              anchor: .leading,
                                      anchorZ: 0,
                              perspective:0.2
                                )
            .allowsHitTesting(globalData.listRotationAngle == 0)
        }  // 只有当未旋转时允许点击
        .ignoresSafeArea(.all)  //
    }
}

struct optionButtonView: View {
    
//    @State private var showSettingsView = false
    
    var body: some View {
        HStack
        {
            Button{
                
            }  label: {
                Image(systemName: "list.bullet") // 添加系统图片
                    .font(.system(size: 25))
                    .foregroundColor(.black)
                    .shadow(color: .gray, radius: 10,x: 0,y: 10)
            }

            Spacer()
        }
        .padding()
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
