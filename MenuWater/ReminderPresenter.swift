import AppKit
import SwiftUI

@MainActor
final class ReminderPresenter {
    private var panel: NSPanel?

    func show(hasDisplayNotch: Bool) {
        dismissImmediately()

        let contentSize = NSSize(width: 250, height: 50)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
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
        panel.contentView = NSHostingView(
            rootView: WaterReminderPill {
                self.dismiss()
            }
        )

        let targetOrigin: NSPoint
        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            targetOrigin = NSPoint(
                x: visibleFrame.midX - contentSize.width / 2,
                y: visibleFrame.maxY - contentSize.height - (hasDisplayNotch ? 18 : 0)
            )
        } else {
            targetOrigin = .zero
        }

        panel.setFrameOrigin(
            NSPoint(x: targetOrigin.x, y: targetOrigin.y + 10)
        )
        panel.alphaValue = 0

        self.panel = panel
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(targetOrigin)
        }
    }

    func dismiss() {
        guard let panel else {
            return
        }

        self.panel = nil
        let exitOrigin = NSPoint(
            x: panel.frame.origin.x,
            y: panel.frame.origin.y + 8
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
            panel.animator().setFrameOrigin(exitOrigin)
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    private func dismissImmediately() {
        panel?.orderOut(nil)
        panel = nil
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
