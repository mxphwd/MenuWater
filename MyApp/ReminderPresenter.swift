import AppKit
import SwiftUI

@MainActor
final class ReminderPresenter {
    private var panel: NSPanel?

    func show() {
        dismiss()

        let contentSize = NSSize(width: 360, height: 82)
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

        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let origin = NSPoint(
                x: visibleFrame.midX - contentSize.width / 2,
                y: visibleFrame.maxY - contentSize.height - 18
            )
            panel.setFrameOrigin(origin)
        } else {
            panel.center()
        }

        self.panel = panel
        panel.orderFrontRegardless()
    }

    func dismiss() {
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

            HStack(spacing: 12) {
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Time to drink water")
                        .font(.headline)

                    Text("Take a moment for a refreshing sip.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 5)

            GeometryReader { geometry in
                Rectangle()
                    .fill(.blue)
                    .frame(width: geometry.size.width * progress, height: 6)
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
        .frame(width: 360, height: 82)
        .padding()
}
