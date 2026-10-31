import AppKit
import SwiftUI

struct CompanionMenu: View {
    @ObservedObject var controller: CompanionController

    var body: some View {
        ScrollView {
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

            FocusTimerView(timer: controller.focusTimer)

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Реакции на сборки и тесты", isOn: Binding(
                    get: { controller.developerEventsEnabled },
                    set: { controller.setDeveloperEventsEnabled($0) }
                )).toggleStyle(.switch)
                if controller.developerEventsEnabled {
                    Text(controller.lastDeveloperEvent ?? "Жду событий от команды Pico.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.font(.subheadline)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Автоматический режим", isOn: Binding(
                    get: { controller.automaticMode },
                    set: { controller.setAutomaticMode($0) }
                )).toggleStyle(.switch)
                if controller.automaticMode {
                    Stepper("Отдых через \(controller.restAfterMinutes) мин", value: Binding(
                        get: { controller.restAfterMinutes },
                        set: { controller.configureAutomaticMode(rest: $0, sleep: controller.sleepAfterMinutes) }
                    ), in: 1...15)
                    Stepper("Сон через \(controller.sleepAfterMinutes) мин", value: Binding(
                        get: { controller.sleepAfterMinutes },
                        set: { controller.configureAutomaticMode(rest: controller.restAfterMinutes, sleep: $0) }
                    ), in: (controller.restAfterMinutes + 1)...60)
                    Text("После бездействия — кофе и сон. Клавиатура или мышь возвращают к работе. Время считается с последнего действия.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Таймер имеет приоритет до сброса. Ручной выбор настроения выключает автоматический режим.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)

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

            if controller.selectedState == .working {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Печатать вместе со мной", isOn: Binding(
                        get: { controller.keyboardSyncEnabled },
                        set: { controller.setKeyboardSync($0) }
                    ))
                    .toggleStyle(.switch)
                    .font(.subheadline)
                    Text(controller.keyboardSyncEnabled
                         ? "Двигает руками при нажатии клавиш."
                         : "Печатает самостоятельно, с небольшими паузами.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if controller.keyboardSyncEnabled {
                        Toggle("Показывать набранные слова", isOn: Binding(
                            get: { controller.wordsEnabled },
                            set: { controller.setWordsEnabled($0) }
                        ))
                        .toggleStyle(.switch)
                        .font(.subheadline)
                        Text("Слова видны всем, кто смотрит на экран. История не сохраняется и никуда не отправляется.")
                            .font(.caption2).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if controller.wordsEnabled {
                            Text(controller.wordStatus)
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if controller.wordPermissionNeeded {
                                Button("Разрешить показ слов") { controller.requestWordPermission() }
                            }
                            if controller.wordPermissionNeeded || controller.wordConnectionFailed {
                                HStack {
                                    Button("Настройки доступа") { controller.openWordPermissionSettings() }
                                    Button("Показать эту копию Pico") { controller.revealRunningApp() }
                                }.font(.caption)
                            }
                        }
                    }
                }
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
        // MenuBarExtra needs a concrete viewport size: a ScrollView only
        // constrained by maxHeight has no reliable intrinsic window height.
        .frame(width: 320, height: 560)
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
