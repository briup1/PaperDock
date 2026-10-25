import SwiftUI
import AppKit

@MainActor final class HSVControl: NSView {
    let draft: PaletteDraft
    let hueOnly: Bool
    init(draft: PaletteDraft, hueOnly: Bool) {
        self.draft = draft; self.hueOnly = hueOnly; super.init(frame: .zero)
        setAccessibilityElement(true); setAccessibilityLabel(hueOnly ? "色相：方向键调整" : "选色盘：左右调浓淡，上下调明暗")
        setAccessibilityRole(.slider)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    override var isFlipped: Bool { true }
    override func becomeFirstResponder() -> Bool { needsDisplay = true; return true }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return true }
    override func draw(_ dirtyRect: NSRect) {
        if hueOnly {
            let colors = (0...6).map { NSColor(hue: CGFloat($0) / 6, saturation: 1, brightness: 1, alpha: 1) }
            NSGradient(colors: colors)!.draw(in: bounds, angle: 0)
        } else {
            NSGradient(starting: .white, ending: NSColor(hue: draft.hue, saturation: 1, brightness: 1, alpha: 1))!.draw(in: bounds, angle: 0)
            let gradient = NSGradient(starting: NSColor.black.withAlphaComponent(0), ending: .black)!
            // Flipped view: top is maximum brightness.
            gradient.draw(from: NSPoint(x: 0, y: 0), to: NSPoint(x: 0, y: bounds.height), options: [])
        }
        let x = (hueOnly ? draft.hue : draft.saturation) * bounds.width
        let y = hueOnly ? bounds.midY : (1 - draft.brightness) * bounds.height
        let ring = NSBezierPath(ovalIn: NSRect(x: x - 6, y: y - 6, width: 12, height: 12))
        NSColor.black.setStroke(); ring.lineWidth = 4; ring.stroke(); NSColor.white.setStroke(); ring.lineWidth = 2; ring.stroke()
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke(); let border = NSBezierPath(rect: bounds.insetBy(dx: 2, dy: 2)); border.lineWidth = 3; border.stroke()
        }
    }
    func choose(_ point: NSPoint) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        if hueOnly { draft.pick(h: point.x / bounds.width) }
        else { draft.pick(s: point.x / bounds.width, b: 1 - point.y / bounds.height) }
        needsDisplay = true
    }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self); choose(convert(event.locationInWindow, from: nil)) }
    override func mouseDragged(with event: NSEvent) { choose(convert(event.locationInWindow, from: nil)) }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: if hueOnly { draft.pick(h: draft.hue - 1 / 360) } else { draft.pick(s: draft.saturation - 0.01) }
        case 124: if hueOnly { draft.pick(h: draft.hue + 1 / 360) } else { draft.pick(s: draft.saturation + 0.01) }
        case 125: if hueOnly { draft.pick(h: draft.hue - 1 / 360) } else { draft.pick(b: draft.brightness - 0.01) }
        case 126: if hueOnly { draft.pick(h: draft.hue + 1 / 360) } else { draft.pick(b: draft.brightness + 0.01) }
        case 48: if event.modifierFlags.contains(.shift) { window?.selectPreviousKeyView(self) } else { window?.selectNextKeyView(self) }
        default: super.keyDown(with: event)
        }
        needsDisplay = true
    }
}
struct HSVView: NSViewRepresentable {
    @ObservedObject var draft: PaletteDraft
    var hueOnly = false
    func makeNSView(context: Context) -> HSVControl { HSVControl(draft: draft, hueOnly: hueOnly) }
    func updateNSView(_ view: HSVControl, context: Context) { view.needsDisplay = true }
}
struct PaletteView: View {
    @ObservedObject var draft: PaletteDraft
    let close: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择纸色").font(.title2.bold())
                    Text("在色盘点选或拖动；无需填写色号").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: close) { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).accessibilityLabel("关闭配色，不保存草稿")
            }
            HStack(spacing: 10) {
                ForEach(Array(zip(ColorSettings.builtins, ["纸白", "暖米", "羊皮纸", "浅灰", "淡绿", "深灰"])), id: \.0) { hex, label in
                    Button { draft.hex = hex; draft.syncHSV() } label: {
                        VStack { RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: ColorValue.ns(hex))).frame(height: 28).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.4))); Text(label).font(.caption2) }
                    }.buttonStyle(.plain).accessibilityLabel(label)
                }
            }
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HSVView(draft: draft).frame(width: 320, height: 210).clipShape(RoundedRectangle(cornerRadius: 5))
                    Text("色相").font(.caption)
                    HSVView(draft: draft, hueOnly: true).frame(width: 320, height: 24).clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("Tab 切换 · ← → 浓淡 · ↑ ↓ 明暗").font(.caption2).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("实时预览").font(.caption)
                        Text("明天联系客户").font(.headline)
                        Text("记录闪念\n☑ 核对报价\n☐ 继续跟进").font(.body)
                    }.padding(15).frame(width: 160, height: 150, alignment: .topLeading)
                        .foregroundStyle(ColorValue.ink(draft.preview)).background(Color(nsColor: ColorValue.ns(draft.preview))).clipShape(RoundedRectangle(cornerRadius: 8))
                    TextField("色号（可选）", text: Binding(get: { draft.hex }, set: { draft.hex = $0; draft.syncHSV() })).textFieldStyle(.roundedBorder).accessibilityLabel("十六进制色号，可选")
                    if !draft.valid { Text("请输入6位十六进制色号，或在色盘重选").font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true).frame(maxWidth: 174, alignment: .leading) }
                    Button("暂存此颜色") { draft.stage() }.disabled(!draft.valid)
                }
            }
            if !draft.saved.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        Text("自定义").font(.caption)
                        ForEach(draft.saved, id: \.self) { hex in
                            Button { draft.hex = hex; draft.syncHSV() } label: { RoundedRectangle(cornerRadius: 4).fill(Color(nsColor: ColorValue.ns(hex))).frame(width: 28, height: 25).overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray)) }.buttonStyle(.plain).accessibilityLabel(hex)
                        }
                    }
                }.frame(height: 30)
            }
            Divider()
            Picker("应用范围", selection: $draft.scope) {
                if draft.noteID != nil { Text(PaletteScope.current.rawValue).tag(PaletteScope.current) }
                Text(PaletteScope.fixed.rawValue).tag(PaletteScope.fixed)
                Text(PaletteScope.random.rawValue).tag(PaletteScope.random)
            }
            if draft.scope == .random {
                Toggle("将当前预览颜色去重加入随机池", isOn: $draft.addToPool)
                Text("应用后切回随机；不勾选则只使用已有随机池。已有便签不重新染色。").font(.caption).foregroundStyle(.secondary)
            } else if draft.scope == .fixed {
                Text("仅以后的新建便签使用此颜色；已有便签保持原色。").font(.caption).foregroundStyle(.secondary)
            } else { Text("仅修改当前便签，不改变新建配色或随机池。").font(.caption).foregroundStyle(.secondary) }
            if let error = draft.store.error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Text("取消会丢弃本轮预览与暂存色").font(.caption).foregroundStyle(.secondary)
                Spacer(); Button("取消", action: close).keyboardShortcut(.cancelAction)
                Button("应用配色") { if draft.apply() { close() } }.keyboardShortcut(.defaultAction).disabled(!draft.valid)
            }
        }.padding(24).frame(width: 560).foregroundStyle(Color.primary).background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(.light)
    }
}
