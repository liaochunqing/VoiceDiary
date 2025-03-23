//
//  AddDiaryView.swift
//  VoiceDiary
//
//  Created by chunqing liao on 2025/3/20.
//

// AddDiaryView.swift
import SwiftUI
import SwiftData

struct AddDiaryView: View {
    @Binding var isPresented: Bool
    @State private var diaryContent: String = ""
    @FocusState private var isFocused: Bool
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextEditor(text: $diaryContent)
                    .focused($isFocused)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 3)
                    .frame(minHeight: 200)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isFocused = true
                        }
                    }
                
                Spacer()
            }
            .padding()
            .navigationTitle("新建日记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        // 保存逻辑
                        if diaryContent.isEmpty == false {
                            // 插入新的 DiaryEntry 数据
                            let newEntry = DiaryEntry(id: UUID(),content: diaryContent, date: Date())
                            modelContext.insert(newEntry)
                        }
                        
                        withAnimation(.spring) {
                                isPresented = false
                            }
                            // 添加触觉反馈
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    
                }
            }
        }
    }
}
