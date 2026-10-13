import AppKit
import SwiftUI

@MainActor
final class ReminderPresenter {
    private struct Presentation {
        let id: UUID
        let panel: NSPanel
        let movesVertically: Bool
    }

    private enum Animation {
        static let openingDuration = 0.32
        static let closingDuration = 0.25
        static let verticalOffset: CGFloat = 6
    }

    private var presentation: Presentation?
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    func show(hasDisplayNotch: Bool, fullScreen: Bool) {
        dismissImmediately()

        let contentSize = NSSize(width: 250, height: 50)
        let screen = NSScreen.main
        let compactFrame = NSRect(origin: .zero, size: contentSize)
        let panelFrame = fullScreen ? (screen?.frame ?? compactFrame) : compactFrame
        let presentationID = UUID()
        let panel = NSPanel(
            contentRect: panelFrame,
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
        panel.ignoresMouseEvents = fullScreen

        let reminderPill = WaterReminderPill { [weak self] in
            self?.dismiss(presentationID: presentationID)
        }

        if fullScreen {
            let menuBarHeight = screen.map { $0.frame.maxY - $0.visibleFrame.maxY } ?? 0
            panel.contentView = NSHostingView(
                rootView: FullScreenReminderOverlay(
                    pill: reminderPill,
                    topInset: menuBarHeight + (hasDisplayNotch ? 18 : 0)
                )
            )
        } else {
            panel.contentView = NSHostingView(rootView: reminderPill)
        }

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

        if !fullScreen {
            panel.setFrameOrigin(
                NSPoint(
                    x: targetOrigin.x,
                    y: targetOrigin.y + Animation.verticalOffset
                )
            )
        }
        panel.alphaValue = 0

        presentation = Presentation(
            id: presentationID,
            panel: panel,
            movesVertically: !fullScreen
        )
        startEscapeMonitoring(presentationID: presentationID)
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Animation.openingDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1

            if !fullScreen {
                panel.animator().setFrameOrigin(targetOrigin)
            }
        }
    }

    private func dismiss(presentationID: UUID) {
        guard let presentation, presentation.id == presentationID else {
            return
        }

        self.presentation = nil
        stopEscapeMonitoring()

        let panel = presentation.panel
        let exitOrigin = NSPoint(
            x: panel.frame.origin.x,
            y: panel.frame.origin.y + Animation.verticalOffset
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Animation.closingDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0

            if presentation.movesVertically {
                panel.animator().setFrameOrigin(exitOrigin)
            }
        } completionHandler: {
            panel.orderOut(nil)
            panel.contentView = nil
        }
    }

    private func dismissImmediately() {
        guard let presentation else {
            return
        }

        self.presentation = nil
        stopEscapeMonitoring()
        presentation.panel.contentView = nil
        presentation.panel.orderOut(nil)
    }

    private func startEscapeMonitoring(presentationID: UUID) {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss(presentationID: presentationID)
            }

            return event
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard event.keyCode == 53 else {
                return
            }

            Task { @MainActor [weak self] in
                self?.dismiss(presentationID: presentationID)
            }
        }
    }

    private func stopEscapeMonitoring() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }

        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }
    }
}

private struct FullScreenReminderOverlay<Pill: View>: View {
    let pill: Pill
    let topInset: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.50)

            pill
                .frame(width: 250, height: 50)
                .padding(.top, topInset)
        }
        .background(.clear)
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
