import SwiftUI

struct ManagerView: View {
    @ObservedObject var model: AppModel
    @State private var settingsOpen = false
    @State private var now = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    static func dayLabel(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "今天" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) { return "昨天" }
        return date.formatted(.dateTime.year().month().day())
    }
    var groups: [(Date, [Note])] {
        let records = Dictionary(grouping: model.results) { Calendar.current.startOfDay(for: $0.modified) }
        return records.keys.sorted(by: >).map { ($0, records[$0]!) }
    }
    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("PaperDock").font(.system(size: 25, weight: .semibold, design: .serif))
                    Text("随手记下，集中找回").font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 9)
                Button { model.newNote() } label: { Label("新建便签", systemImage: "square.and.pencil").frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.borderedProminent)
                VStack(spacing: 8) {
                    ForEach(NoteFilter.allCases, id: \.self) { filter in
                        Button { model.changeFilter(filter) } label: {
                            HStack {
                                Image(systemName: icon(filter)).frame(width: 18)
                                Text(filter.rawValue); Spacer()
                                Text("\(model.store.results(filter, "").count)").font(.caption).foregroundStyle(.secondary)
                            }.padding(9).contentShape(Rectangle())
                        }.buttonStyle(.plain).background(model.filter == filter ? Color.accentColor.opacity(0.12) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                Spacer()
                Divider()
                Button { settingsOpen = true } label: { Label("设置与默认纸色", systemImage: "slider.horizontal.3") }.buttonStyle(.plain)
                Text("仅本机保存 · 无云同步").font(.caption2).foregroundStyle(.secondary)
            }.padding(18).frame(minWidth: 185, idealWidth: 205, maxWidth: 240).background(Color(nsColor: .windowBackgroundColor))
            VStack(spacing: 0) {
                HStack {
                    Text(model.filter.rawValue).font(.headline)
                    Spacer()
                    Button { model.newNote() } label: { Image(systemName: "plus") }.accessibilityLabel("列表新建便签")
                }.padding(16)
                TextField("搜索标题、正文与待办", text: $model.query).textFieldStyle(.roundedBorder).accessibilityLabel("搜索便签").padding(.horizontal, 14).padding(.bottom, 12)
                Divider()
                if model.results.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: model.query.isEmpty ? "note.text" : "magnifyingglass").font(.system(size: 30)).foregroundStyle(.tertiary)
                        Text(emptyMessage).font(.headline)
                        if !model.query.isEmpty { Button("清空搜索") { model.query = "" } }
                        else if model.filter == .all { Text("从边缘拖出，或在这里记下第一句。").font(.caption).foregroundStyle(.secondary); Button("新建第一张便签") { model.newNote() } }
                    }.multilineTextAlignment(.center).padding(22).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(groups, id: \.0) { day, notes in
                                Text(Self.dayLabel(day, now: now)).font(.caption.weight(.medium)).foregroundStyle(.secondary).padding(.top, 15).padding(.horizontal, 12)
                                ForEach(notes) { n in
                                    Button { model.select(n.id) } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            RoundedRectangle(cornerRadius: 3).fill(Color(nsColor: ColorValue.ns(n.color))).frame(width: 8, height: 44).overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.gray.opacity(0.2)))
                                            VStack(alignment: .leading, spacing: 7) {
                                                Text(n.title).font(.headline).lineLimit(1)
                                                Text(n.summary.isEmpty ? "还没有内容" : n.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                                Text(n.deleted ? "回收站" : (n.visible ? "桌面可见" : "已收纳")).font(.caption2).foregroundStyle(.secondary)
                                            }; Spacer(minLength: 0)
                                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                    }.buttonStyle(.plain).background(model.selected == n.id ? Color.accentColor.opacity(0.12) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 7))
                                        .contextMenu {
                                            if model.filter == .all {
                                                Button("删除", role: .destructive) { model.requestDelete(n.id) }
                                                    .disabled(model.store.isLocked(n.id))
                                            }
                                        }
                                }
                            }
                        }.padding(8)
                    }
                }
                if model.editingOutsideResults {
                    Text("当前编辑内容已不匹配搜索，保留编辑器至切换记录").font(.caption).padding(12).frame(maxWidth: .infinity).background(Color.yellow.opacity(0.16))
                }
            }.frame(minWidth: 250, idealWidth: 280, maxWidth: 380).background(Color(nsColor: .textBackgroundColor))
            Group {
                if let id = model.selected { NoteEditor(model: model, id: id).id(id) }
                else {
                    VStack(spacing: 14) {
                        Image(systemName: "square.and.pencil").font(.system(size: 36)).foregroundStyle(.tertiary)
                        Text("留一点空间，给下一个想法").font(.title3)
                        Text("选择一张便签继续，或新建一张。").font(.caption).foregroundStyle(.secondary)
                        Button("新建便签") { model.newNote() }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(nsColor: ColorValue.ns("#FFFEFA")))
                }
            }.frame(minWidth: 375, idealWidth: 500, maxWidth: .infinity)
        }.frame(minWidth: 860, minHeight: 540).background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(.light)
            .sheet(isPresented: $settingsOpen) { SettingsView(model: model) }
            .alert("移到回收站？", isPresented: Binding(get: { model.pendingDelete != nil }, set: { _ in })) {
                Button("取消", role: .cancel) { model.confirmDelete(false) }
                Button("移到回收站", role: .destructive) { model.confirmDelete(true) }
                    .disabled(model.pendingDelete.map { model.store.isLocked($0) } ?? true)
            } message: {
                Text("将“\(model.deletionTarget?.title ?? "")”移到回收站？便签会从桌面收起，可以恢复；不会永久删除。")
            }
            .onReceive(timer) { now = $0 }
    }
    var emptyMessage: String {
        if !model.query.isEmpty { return "没有匹配的便签" }
        switch model.filter { case .all: return "还没有便签"; case .visible: return "没有桌面可见便签"; case .stored: return "没有已收纳便签"; case .trash: return "回收站为空" }
    }
    func icon(_ filter: NoteFilter) -> String {
        switch filter { case .all: return "square.stack"; case .visible: return "macwindow"; case .stored: return "tray"; case .trash: return "trash" }
    }
}
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) var dismiss
    var closeWindow: (() -> Void)? = nil
    @State private var draft: PaletteDraft?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("设置与默认纸色").font(.title2.bold()); Spacer(); Button("完成") { if let closeWindow { closeWindow() } else { dismiss() } }.keyboardShortcut(.cancelAction) }
            Text("新建模式：\(model.store.settings.fixed ? "固定 \(model.store.settings.fixedColor)" : "随机配色")").font(.headline)
            Text("随机池（\(model.store.settings.pool.count)色）").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack {
                    ForEach(model.store.settings.pool, id: \.self) { hex in RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: ColorValue.ns(hex))).frame(width: 28, height: 28).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.5))).help(hex) }
                }
            }.frame(height: 36)
            HStack {
                Button("选色并固定使用") { let d = PaletteDraft(store: model.store, noteID: nil); d.scope = .fixed; draft = d }
                Button("随机配色设置") { let d = PaletteDraft(store: model.store, noteID: nil); d.scope = .random; d.addToPool = false; draft = d }
            }
            Divider()
            Text("所有新建入口使用同一规则；变更默认色不会重新染色已有便签。").font(.caption)
            Text("关闭浮动便签等于收纳；回收站只提供恢复，不会永久删除或自动清理。").font(.caption).foregroundStyle(.secondary)
            Text("保存在：\(model.store.directory.path)").font(.caption2).textSelection(.enabled)
        }.padding(24).frame(width: 540).background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(.light)
            .sheet(item: $draft) { d in PaletteView(draft: d) { draft = nil } }
    }
}
