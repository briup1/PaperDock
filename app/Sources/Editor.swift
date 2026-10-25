import SwiftUI
import AppKit

@MainActor final class BodyCoordinator: NSObject, NSTextViewDelegate {
    let store: Store
    let id: UUID
    init(store: Store, id: UUID) { self.store = store; self.id = id }
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        !store.isLocked(id) && store.note(id)?.deleted == false
    }
    func textDidChange(_ notification: Notification) {
        guard let view = notification.object as? NSTextView else { return }
        if store.isLocked(id) { synchronize(view); return }
        guard !view.hasMarkedText() else { return }
        store.edit(id) { $0.body = view.string }
    }
    func synchronize(_ view: NSTextView) {
        if store.isLocked(id), view.hasMarkedText() { view.unmarkText() }
        guard !view.hasMarkedText(), let n = store.note(id), view.string != n.body else { return }
        let selection = view.selectedRange()
        view.string = n.body
        let length = (view.string as NSString).length
        view.setSelectedRange(NSRange(location: min(selection.location, length), length: min(selection.length, max(0, length - selection.location))))
    }
}
struct NoteBody: NSViewRepresentable {
    @ObservedObject var store: Store
    let id: UUID
    var compact = false
    func makeCoordinator() -> BodyCoordinator { BodyCoordinator(store: store, id: id) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        if compact { scroll.clipsToBounds = true; scroll.contentView.clipsToBounds = true }
        let text = NSTextView(frame: scroll.bounds)
        text.isRichText = false; text.importsGraphics = false; text.allowsUndo = true
        text.isVerticallyResizable = true; text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]; text.textContainer?.widthTracksTextView = true
        text.textContainerInset = NSSize(width: compact ? 8 : 12, height: compact ? 8 : 16)
        text.font = NSFont.systemFont(ofSize: compact ? 12.5 : 17); text.drawsBackground = false
        text.delegate = context.coordinator; text.setAccessibilityLabel("便签正文")
        scroll.documentView = text
        context.coordinator.synchronize(text); return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let text = scroll.documentView as? NSTextView else { return }
        context.coordinator.synchronize(text)
        text.isEditable = store.note(id)?.deleted == false && !store.isLocked(id)
        if text.font?.pointSize != (compact ? 12.5 : 17) { text.font = NSFont.systemFont(ofSize: compact ? 12.5 : 17) }
        let ink = ColorValue.ink(store.note(id)?.color ?? "#FFFEFA") == .white ? NSColor.white : NSColor.black
        text.textColor = ink; text.insertionPointColor = ink
    }
}
private struct CompactBodyClip: ViewModifier {
    var compact: Bool
    func body(content: Content) -> some View {
        if compact { content.clipped() } else { content }
    }
}
private struct NoteToolbarDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            guard let window, window.isMovable else { return }
            let origin = window.frame.origin
            let pointer = NSEvent.mouseLocation
            while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp], until: .distantFuture, inMode: .eventTracking, dequeue: true) {
                guard window.isMovable else { break }
                let current = NSEvent.mouseLocation
                window.setFrameOrigin(NSPoint(x: origin.x + current.x - pointer.x, y: origin.y + current.y - pointer.y))
                if next.type == .leftMouseUp { break }
            }
            // Commit only once at drag end, not once per mouse-move event.
            (window as? NotePanel)?.movementFinished?()
        }
    }
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {}
}
private struct NoteToolLabelStyle: LabelStyle {
    var iconOnly: Bool
    func makeBody(configuration: Configuration) -> some View {
        if iconOnly { Label(configuration).labelStyle(.iconOnly).frame(minWidth: 22, minHeight: 22).contentShape(Rectangle()) }
        else { Label(configuration).labelStyle(.titleAndIcon) }
    }
}
struct NoteEditor: View {
    @ObservedObject var model: AppModel
    let id: UUID
    var compact = false
    @State private var draft: PaletteDraft?
    @State private var showCollapseError = false
    @FocusState private var focusedTodo: UUID?
    @State private var addedTodo: UUID?
    private var collapsed: Bool { compact && model.store.isCollapsed(id) }
    private var sidePadding: CGFloat { compact ? 14 : 24 }
    private var toolPadding: CGFloat { compact ? 9 : 16 }
    var body: some View {
        if let n = model.store.note(id) {
            VStack(spacing: 0) {
                if collapsed {
                    HStack(spacing: 4) {
                        Text(n.title).font(.system(size: 12, weight: .semibold))
                            .lineLimit(1).truncationMode(.tail).frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .overlay { NoteToolbarDragArea() }
                        if model.store.error != nil {
                            Button("保存失败", systemImage: "exclamationmark.triangle") { showCollapseError = true }
                                .foregroundStyle(.red).help("查看未保存原因")
                                .popover(isPresented: $showCollapseError) { Text(model.store.error ?? "请重试原操作").padding().frame(width: 240) }
                        }
                        Button(model.store.isLocked(id) ? "解锁" : "钉住", systemImage: model.store.isLocked(id) ? "pin.slash" : "pin") { model.toggleLock(id) }
                            .help(model.store.isLocked(id) ? "解锁此便签" : "钉住并锁定整张便签")
                        if !model.store.isLocked(id) {
                            layerButton
                            Button("展开", systemImage: "plus") { model.toggleCollapsed(id) }.help("展开此便签")
                            Button("收纳", systemImage: "xmark") { model.stash(id) }.help("收纳此便签")
                        }
                    }
                    .labelStyle(NoteToolLabelStyle(iconOnly: true)).font(.system(size: 12))
                    .buttonStyle(.borderless).controlSize(.small)
                    .padding(.horizontal, toolPadding).frame(height: NotePlacement.collapsedHeight)
                } else {
                HStack {
                    if !compact || model.store.isLocked(id) {
                        Text(n.deleted ? "回收站 · 只读" : (model.store.isLocked(id) ? (compact ? "已钉住" : "已钉住 · 整张锁定") : (n.visible ? "桌面可见" : "已收纳")))
                            .font(compact ? .system(size: 10) : .caption).foregroundStyle(.secondary)
                    }
                    Spacer().frame(height: compact ? 22 : nil).background {
                        if compact { NoteToolbarDragArea() }
                    }
                    if n.deleted {
                        Button("恢复便签") { model.restore(id) }
                    } else {
                        if n.visible || model.store.isLocked(id) {
                            Button(model.store.isLocked(id) ? "解锁" : "钉住", systemImage: model.store.isLocked(id) ? "pin.slash" : "pin") { model.toggleLock(id) }
                                .accessibilityLabel(model.store.isLocked(id) ? "解锁此便签" : "钉住并锁定整张便签")
                                .help(model.store.isLocked(id) ? "解锁此便签" : "钉住并锁定整张便签")
                        }
                        if !model.store.isLocked(id) {
                            if n.visible { layerButton }
                            Button("纸色", systemImage: "paintpalette") { draft = PaletteDraft(store: model.store, noteID: id) }.help("选择便签纸色")
                            if compact {
                                Button("管理", systemImage: "sidebar.left") { model.select(id); model.showManager?() }.help("管理全部便签")
                                Button("折叠", systemImage: "minus") { model.toggleCollapsed(id) }.help("折叠为标题条")
                                Button("收纳", systemImage: "xmark") { model.stash(id) }.help("收纳此便签")
                            } else {
                                Button(n.visible ? "收纳" : "显示到桌面", systemImage: n.visible ? "tray" : "arrow.up.right.square") {
                                    if n.visible { model.stash(id) } else { model.show(id) }
                                }
                                Button("删除", systemImage: "trash") { model.requestDelete(id) }
                            }
                        }
                    }
                }
                .labelStyle(NoteToolLabelStyle(iconOnly: compact && !model.store.isLocked(id)))
                .font(compact ? .system(size: 12) : nil)
                .buttonStyle(.borderless).controlSize(compact ? .small : .regular)
                .frame(minHeight: compact ? 22 : nil)
                .padding(.horizontal, toolPadding).padding(.vertical, compact ? 2.5 : toolPadding)
                Divider()
                if compact {
                    ScrollViewReader { proxy in
                        ScrollView { editorContent(n) }
                            .onChange(of: addedTodo) { _, newID in
                                guard let newID else { return }
                                proxy.scrollTo(newID, anchor: .bottom)
                                focusedTodo = newID
                            }
                    }
                    if !n.deleted && !model.store.isLocked(id) {
                        Divider()
                        addTodoButton.padding(.vertical, 6)
                    }
                } else { editorContent(n) }
                }
            }
            .foregroundStyle(ColorValue.ink(n.color)).foregroundColor(ColorValue.ink(n.color)).background(Color(nsColor: ColorValue.ns(n.color)))
            .environment(\.colorScheme, ColorValue.ink(n.color) == .white ? .dark : .light)
            .sheet(item: $draft) { d in PaletteView(draft: d) { draft = nil } }
            .onChange(of: model.store.isLocked(id)) { _, locked in if locked { draft = nil } }
        } else { Text("请选择便签").foregroundStyle(.secondary) }
    }
    private var layerButton: some View {
        Button(model.store.layer(id) == .floating ? "沉底" : "浮顶", systemImage: model.store.layer(id) == .floating ? "square.3.layers.3d.bottom.filled" : "square.3.layers.3d.top.filled") { model.toggleLayer(id) }
            .help(model.store.layer(id) == .floating ? "沉底到普通窗口下方" : "浮顶到普通窗口上方")
    }
    private func editorContent(_ n: Note) -> some View {
        VStack(spacing: 0) {
                TextField("标题", text: Binding(get: { model.store.note(id)?.manualTitle ?? "" }, set: { value in model.store.edit(id) { $0.manualTitle = value } }), prompt: Text(n.title).foregroundColor(ColorValue.ink(n.color).opacity(0.7)))
                    .font(.system(size: compact ? 15 : 25, weight: .semibold)).textFieldStyle(.plain)
                    .accessibilityLabel("手动标题，清空恢复自动标题").padding(.horizontal, sidePadding).padding(.top, compact ? 12 : 22)
                    .disabled(n.deleted || model.store.isLocked(id))
                Text(n.modified.formatted(date: .abbreviated, time: .shortened) + " · 内容修改")
                    .font(compact ? .system(size: 9) : .caption).opacity(0.6).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, sidePadding).padding(.top, compact ? 4 : 8)
                NoteBody(store: model.store, id: id, compact: compact).id(id).disabled(n.deleted || model.store.isLocked(id))
                    .frame(minHeight: compact ? 80 : nil, maxHeight: compact ? 80 : nil).modifier(CompactBodyClip(compact: compact))
                Divider().padding(.horizontal, compact ? 12 : 18)
                Group {
                    if compact { todos(n) }
                    else { ScrollView { todos(n) }.frame(maxHeight: n.todos.isEmpty ? 0 : min(180, CGFloat(n.todos.count) * 43 + 20)) }
                }
                if !compact && !n.deleted && !model.store.isLocked(id) {
                    addTodoButton.padding(.vertical, 18)
                }
                if let error = model.store.error {
                    HStack { Text(error).font(compact ? .system(size: 9) : .caption); Button("重试保存") { model.store.save() }.accessibilityLabel("重试保存") }.padding(compact ? 6 : 12).background(Color.red.opacity(0.15))
                } else if !compact {
                    Text(model.store.dirty ? "尚未保存" : "已保存到本机").font(compact ? .system(size: 9) : .caption2).opacity(0.6).padding(.bottom, compact ? 6 : 10)
                }
        }
    }

    private var addTodoButton: some View {
        Button {
            guard !model.store.isLocked(id), model.store.note(id)?.deleted == false else { return }
            if compact && model.prepareTodoAddition?(id) == false { return }
            let todo = Todo(text: "")
            model.store.edit(id) { $0.todos.append(todo) }
            if compact { addedTodo = todo.id }
        } label: { Label("添加待办", systemImage: "plus.circle") }
            .buttonStyle(.borderless).font(compact ? .system(size: 11) : nil).controlSize(compact ? .small : .regular)
            .accessibilityLabel("添加待办")
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, compact ? 10 : 18)
    }

    private func todos(_ n: Note) -> some View {
                    VStack(spacing: compact ? 6 : 10) {
                        ForEach(n.todos) { todo in
                            HStack(alignment: .top, spacing: compact ? 6 : 9) {
                                Toggle("完成待办", isOn: Binding(get: { model.store.note(id)?.todos.first { $0.id == todo.id }?.done ?? false }, set: { value in model.store.edit(id) { note in if let i = note.todos.firstIndex(where: { $0.id == todo.id }) { note.todos[i].done = value } } }))
                                    .labelsHidden().toggleStyle(.checkbox).accessibilityLabel("完成：\(todo.text)").colorScheme(ColorValue.ink(n.color) == .white ? .dark : .light)
                                TextField("待办文字", text: Binding(get: { model.store.note(id)?.todos.first { $0.id == todo.id }?.text ?? "" }, set: { value in model.store.edit(id) { note in if let i = note.todos.firstIndex(where: { $0.id == todo.id }) { note.todos[i].text = value } } }))
                                    .textFieldStyle(.plain).strikethrough(todo.done).opacity(todo.done ? 0.6 : 1)
                                    .focused($focusedTodo, equals: todo.id)
                                Button { model.store.edit(id) { $0.todos.removeAll { $0.id == todo.id } } } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).accessibilityLabel("移除此待办")
                            }.font(compact ? .system(size: 12) : nil).controlSize(compact ? .small : .regular).disabled(n.deleted || model.store.isLocked(id)).id(todo.id)
                        }
                    }.padding(.horizontal, compact ? 10 : 18)
                        .padding(.top, compact ? 6 : 18).padding(.bottom, compact ? 0 : 18)
    }

}
