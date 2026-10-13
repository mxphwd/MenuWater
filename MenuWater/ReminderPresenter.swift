import AppKit
import SwiftUI

@MainActor
final class ReminderPresenter {
    private var panel: NSPanel?

    func show(hasDisplayNotch: Bool, fullScreen: Bool) {
        dismissImmediately()

        let contentSize = NSSize(width: 250, height: 50)
        let screen = NSScreen.main
        let panelFrame = fullScreen ? (screen?.frame ?? NSRect(origin: .zero, size: contentSize)) : NSRect(origin: .zero, size: contentSize)
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

        let reminderPill = WaterReminderPill {
            self.dismiss()
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
                NSPoint(x: targetOrigin.x, y: targetOrigin.y + 10)
            )
        }
        panel.alphaValue = 0

        self.panel = panel
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 1
            if !fullScreen {
                panel.animator().setFrameOrigin(targetOrigin)
            }
        }
    }

    func dismiss() {
        guard let panel else {
            return
        }

        self.panel = nil
        let shouldMove = panel.frame.size == NSSize(width: 250, height: 50)
        let exitOrigin = NSPoint(x: panel.frame.origin.x, y: panel.frame.origin.y + 8)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
            if shouldMove {
                panel.animator().setFrameOrigin(exitOrigin)
            }
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    private func dismissImmediately() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct FullScreenReminderOverlay<Pill: View>: View {
    let pill: Pill
    let topInset: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.blue.opacity(0.9), lineWidth: 2.5)
                .shadow(color: .cyan.opacity(0.9), radius: 5)
                .shadow(color: .blue.opacity(0.65), radius: 10)
                .padding(4)

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
