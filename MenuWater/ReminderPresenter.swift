import AppKit
import SwiftUI

@MainActor
final class ReminderPresenter {
    private struct Presentation {
        let id: UUID
        let pillPanel: NSPanel
        let dimmingPanel: NSPanel?

        var panels: [NSPanel] {
            [dimmingPanel, pillPanel].compactMap { $0 }
        }
    }

    private enum Animation {
        static let openingDuration = 0.32
        static let closingDuration = 0.25
        static let verticalOffset: CGFloat = 6
    }

    private var presentation: Presentation?

    func show(hasDisplayNotch: Bool, fullScreen: Bool) {
        dismissImmediately()

        let contentSize = NSSize(width: 250, height: 50)
        let screen = NSScreen.main
        let compactFrame = NSRect(origin: .zero, size: contentSize)
        let presentationID = UUID()
        let dismissAction: () -> Void = { [weak self] in
            guard let self else {
                return
            }
            self.dismiss(presentationID: presentationID)
        }
        let reminderPill = WaterReminderPill(onDismiss: dismissAction)
        let pillPanel = makePanel(frame: compactFrame, ignoresMouseEvents: false)
        pillPanel.contentView = SwipeHostingView(
            rootView: reminderPill,
            onSwipeUp: dismissAction
        )

        let targetOrigin: NSPoint
        if let screen {
            let visibleFrame = screen.visibleFrame
            targetOrigin = NSPoint(
                x: visibleFrame.midX - contentSize.width / 2,
                y: visibleFrame.maxY - contentSize.height - (hasDisplayNotch ? 18 : 0)
            )
        } else {
            targetOrigin = .zero
        }

        pillPanel.setFrameOrigin(
            NSPoint(
                x: targetOrigin.x,
                y: targetOrigin.y + Animation.verticalOffset
            )
        )
        pillPanel.alphaValue = 0

        let dimmingPanel: NSPanel?
        if fullScreen, let screen {
            let panel = makePanel(frame: screen.frame, ignoresMouseEvents: true)
            panel.hasShadow = false
            panel.contentView = NSHostingView(rootView: FullScreenDimmingOverlay())
            panel.alphaValue = 0
            dimmingPanel = panel
        } else {
            dimmingPanel = nil
        }

        presentation = Presentation(
            id: presentationID,
            pillPanel: pillPanel,
            dimmingPanel: dimmingPanel
        )
        dimmingPanel?.orderFrontRegardless()
        pillPanel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Animation.openingDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            dimmingPanel?.animator().alphaValue = 1
            pillPanel.animator().alphaValue = 1
            pillPanel.animator().setFrameOrigin(targetOrigin)
        }
    }

    private func dismiss(presentationID: UUID) {
        guard let presentation, presentation.id == presentationID else {
            return
        }

        self.presentation = nil

        let pillPanel = presentation.pillPanel
        let exitOrigin = NSPoint(
            x: pillPanel.frame.origin.x,
            y: pillPanel.frame.origin.y + Animation.verticalOffset
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Animation.closingDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            for panel in presentation.panels {
                panel.animator().alphaValue = 0
            }
            pillPanel.animator().setFrameOrigin(exitOrigin)
        } completionHandler: {
            for panel in presentation.panels {
                panel.orderOut(nil)
                panel.contentView = nil
            }
        }
    }

    private func dismissImmediately() {
        guard let presentation else {
            return
        }

        self.presentation = nil
        for panel in presentation.panels {
            panel.contentView = nil
            panel.orderOut(nil)
        }
    }

    private func makePanel(frame: NSRect, ignoresMouseEvents: Bool) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.ignoresMouseEvents = ignoresMouseEvents
        return panel
    }

}

private struct FullScreenDimmingOverlay: View {
    var body: some View {
        Color.black.opacity(0.50)
    }
}

private final class SwipeHostingView<Content: View>: NSHostingView<Content> {
    private let onSwipeUp: () -> Void
    private var verticalScrollDistance = 0.0

    init(rootView: Content, onSwipeUp: @escaping () -> Void) {
        self.onSwipeUp = onSwipeUp
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init(rootView: Content) {
        fatalError("init(rootView:) is unavailable")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func scrollWheel(with event: NSEvent) {
        if event.phase == .began {
            verticalScrollDistance = 0
        }

        let directionMultiplier = event.isDirectionInvertedFromDevice ? -1.0 : 1.0
        verticalScrollDistance += event.scrollingDeltaY * directionMultiplier

        if verticalScrollDistance > 18 {
            verticalScrollDistance = 0
            onSwipeUp()
            return
        }

        if event.phase == .ended || event.phase == .cancelled {
            verticalScrollDistance = 0
        }
    }
}

private struct WaterReminderPill: View {
    let onDismiss: () -> Void

    @State private var progress = 0.0

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Capsule()
                .fill(.regularMaterial)

            HStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.body)
                    .foregroundStyle(.blue)

                Text("Time to drink water")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 14)
            .padding(.bottom, 2)

            GeometryReader { geometry in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .blue.opacity(0.7),
                                .cyan,
                                .white.opacity(0.9),
                                .blue
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .cyan.opacity(0.75), radius: 3, y: -1)
                    .shadow(color: .blue.opacity(0.45), radius: 6, y: -1)
                    .frame(width: geometry.size.width * progress, height: 2.5)
                    .frame(maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .contentShape(Capsule())
        .onTapGesture(perform: onDismiss)
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onEnded { value in
                    if value.translation.height < -18 {
                        onDismiss()
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Time to drink water. This reminder closes in ten seconds.")
        .task {
            await Task.yield()

            withAnimation(.linear(duration: 10)) {
                progress = 1
            }

            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else {
                return
            }
            onDismiss()
        }
    }
}

#Preview {
    WaterReminderPill {}
        .frame(width: 250, height: 50)
        .padding()
}
