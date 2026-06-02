//
//  PanelHistoryView.swift
//  XYDevTool
//
//  Created by 渠晓友 on 2024/6/26.
//  Copyright © 2024 XIAOYOU. All rights reserved.
//

import SwiftUI

// MARK: - Row frame tracking

private struct HistoryRowFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Panel

struct PanelHistoryView: View {
    @EnvironmentObject var dataModel: NetworkDataModel
    
    private let coordinateSpaceName = "historyReorder"
    private let defaultRowHeight: CGFloat = 40
    
    @State private var selectedItem: String? = nil
    @State private var displayItems: [XYItem] = []
    @State private var rowFrames: [String: CGRect] = [:]
    
    @State private var draggingName: String? = nil
    /// 手势相对起点的位移（每帧来自 DragGesture，不叠加修改）
    @State private var dragTranslation: CGFloat = 0
    /// 列表重排导致行基准位置变化的累计补偿（下移为正，上移为负）
    @State private var reorderCompensation: CGFloat = 0
    @State private var lastHoverIndex: Int? = nil
    
    private var dragVisualOffset: CGFloat {
        dragTranslation - reorderCompensation
    }
    
    private var historyOrderSignature: [String?] {
        dataModel.historyArray.map(\.name)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("请求历史(\(displayItems.count))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                
                ForEach(displayItems, id: \.name) { item in
                    historyRow(item)
                }
            }
            .padding(.bottom, 8)
        }
        .coordinateSpace(name: coordinateSpaceName)
        .onPreferenceChange(HistoryRowFrameKey.self) { rowFrames = $0 }
        .scrollContentBackground(.hidden)
        .background(NetworkTheme.sectionBackground)
        .onAppear { syncDisplayItems() }
        .onChange(of: historyOrderSignature) { _, _ in
            if draggingName == nil {
                syncDisplayItems()
            }
        }
    }
    
    // MARK: - Row
    
    @ViewBuilder
    private func historyRow(_ item: XYItem) -> some View {
        let hisName = item.name ?? ""
        let isLock = item.isLock ?? false
        let isSelected = selectedItem == hisName
        let isDragging = draggingName == hisName
        
        ZStack {
            (isSelected ? Color.blue.opacity(0.5) : Color.blue.opacity(0.1))
            HStack(spacing: 8) {
                reorderHandle(for: hisName)
                
                Text(hisName)
                    .font(.body)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .onTapGesture {
                        if isLock {
                            showAlert(msg: "您要移除的记录为【" + hisName + "】它是锁定的记录，不能直接删除，需要先解除锁定")
                        } else {
                            dataModel.removeHistory(named: hisName)
                            if selectedItem == hisName {
                                selectedItem = nil
                            }
                            syncDisplayItems()
                        }
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(minHeight: defaultRowHeight)
        .contentShape(Rectangle())
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: HistoryRowFrameKey.self,
                    value: [hisName: proxy.frame(in: .named(coordinateSpaceName))]
                )
            }
        )
        .scaleEffect(isDragging ? 1.02 : 1, anchor: .center)
        .shadow(
            color: Color.black.opacity(isDragging ? 0.22 : 0),
            radius: isDragging ? 10 : 0,
            y: isDragging ? 4 : 0
        )
        .offset(y: isDragging ? dragVisualOffset : 0)
        .zIndex(isDragging ? 100 : 0)
        .animation(isDragging ? nil : .interactiveSpring(response: 0.26, dampingFraction: 0.86), value: isDragging)
        .onTapGesture {
            guard hisName.isEmpty == false, draggingName == nil else { return }
            selectedItem = hisName
            dataModel.setCurrentHistory(with: hisName)
        }
    }
    
    /// 仅拖拽把手：拖动过程中其他行提前让位，松手后持久化。
    private func reorderHandle(for name: String) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.body)
            .foregroundStyle(.secondary)
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
            .help("拖拽以调整顺序")
            .gesture(
                DragGesture(coordinateSpace: .named(coordinateSpaceName))
                    .onChanged { value in
                        if draggingName == nil {
                            draggingName = name
                            lastHoverIndex = displayItems.firstIndex(where: { $0.name == name })
                            reorderCompensation = 0
                        }
                        dragTranslation = value.translation.height
                        let hoverIndex = hoverIndex(for: value.location.y)
                        if hoverIndex != lastHoverIndex {
                            performLiveMove(to: hoverIndex)
                            lastHoverIndex = hoverIndex
                        }
                    }
                    .onEnded { _ in
                        finishReorder()
                    }
            )
    }
    
    // MARK: - Reorder logic
    
    private func syncDisplayItems() {
        displayItems = dataModel.historyArray
    }
    
    private func hoverIndex(for locationY: CGFloat) -> Int {
        guard displayItems.isEmpty == false else { return 0 }
        
        // 用列表顶部 + 平均行高估算目标行，避免动画过程中 frame 变化导致 hover 抖动
        if let topY = rowFrames.values.map(\.minY).min() {
            let unit = averageRowHeight()
            var index = Int(floor((locationY - topY) / unit))
            index = min(max(0, index), displayItems.count - 1)
            return index
        }
        
        for (index, item) in displayItems.enumerated() {
            guard let name = item.name, let frame = rowFrames[name] else { continue }
            if locationY < frame.midY {
                return index
            }
        }
        return displayItems.count - 1
    }
    
    private func averageRowHeight() -> CGFloat {
        guard rowFrames.isEmpty == false else { return defaultRowHeight }
        let heights = rowFrames.values.map(\.height)
        return heights.reduce(0, +) / CGFloat(heights.count)
    }
    
    private func performLiveMove(to hoverIndex: Int) {
        guard let draggingName,
              let fromIndex = displayItems.firstIndex(where: { $0.name == draggingName }),
              hoverIndex != fromIndex,
              hoverIndex >= 0,
              hoverIndex < displayItems.count else {
            return
        }
        
        let rowHeight = averageRowHeight()
        let indexDelta = hoverIndex - fromIndex
        
        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.86, blendDuration: 0.05)) {
            displayItems.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: hoverIndex > fromIndex ? hoverIndex + 1 : hoverIndex
            )
        }
        // 行在列表中的布局位置随 index 变化，累计补偿以保持光标下的视觉位置不变
        reorderCompensation += CGFloat(indexDelta) * rowHeight
    }
    
    private func finishReorder() {
        dataModel.applyHistoryOrder(displayItems)
        draggingName = nil
        dragTranslation = 0
        reorderCompensation = 0
        lastHoverIndex = nil
    }
}

#Preview {
    PanelHistoryView()
}
