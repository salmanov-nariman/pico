import AppKit
import SwiftUI

struct CompanionMenu: View {
    @ObservedObject var controller: CompanionController

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "pawprint.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 42, height: 42)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pico").font(.headline)
                    Text(controller.isVisible ? "Твой компаньон рядом" : "Сейчас скрыт")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(controller.isVisible ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Настроение").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(CompanionState.allCases) { state in
                        stateButton(state)
                    }
                }
                Text(controller.selectedState.subtitle)
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(height: 30, alignment: .topLeading)
            }

            Divider()

            VStack(spacing: 10) {
                HStack {
                    Text("Скорость").font(.subheadline)
                    Spacer()
                    Text(String(format: "%.2g×", controller.playbackRate))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { controller.playbackRate },
                    set: { controller.setPlaybackRate($0) }
                ), in: 0.5...1.5, step: 0.25)
                .accessibilityLabel("Скорость анимации")
                .disabled(!controller.animationEnabled || controller.reduceMotion)

                HStack {
                    Button {
                        controller.toggleAnimation()
                    } label: {
                        Label(controller.animationEnabled ? "Пауза" : "Продолжить",
                              systemImage: controller.animationEnabled ? "pause.fill" : "play.fill")
                    }
                    .disabled(controller.reduceMotion)
                    Spacer()
                    Button(controller.isVisible ? "Скрыть" : "Показать") {
                        controller.toggleVisibility()
                    }
                }
                if controller.reduceMotion {
                    Text("Движение отключено в настройках macOS.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()
            HStack {
                Button("Вернуть в угол") { controller.resetPosition() }
                Spacer()
                Button("Выйти") { NSApplication.shared.terminate(nil) }
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
        .padding(20)
        .frame(width: 320)
    }

    private func stateButton(_ state: CompanionState) -> some View {
        let selected = controller.selectedState == state
        return Button {
            controller.selectState(state)
        } label: {
            VStack(spacing: 7) {
                Image(systemName: state.symbol).font(.system(size: 20))
                Text(state.title).font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
            .background(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.5) : .clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
