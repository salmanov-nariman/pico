import SwiftUI

struct FocusTimerView: View {
    @ObservedObject var timer: FocusTimer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Таймер", systemImage: "timer").font(.subheadline.weight(.semibold))
                Spacer()
                if timer.status == .running || timer.status == .paused {
                    Text(timer.timeLabel).font(.title2.monospacedDigit())
                }
            }
            if timer.canConfigure {
                Stepper("Работа: \(timer.focusMinutes) мин", value: Binding(
                    get: { timer.focusMinutes },
                    set: { timer.configure(focus: $0, rest: timer.restMinutes) }
                ), in: 1...120)
                Stepper("Отдых: \(timer.restMinutes) мин", value: Binding(
                    get: { timer.restMinutes },
                    set: { timer.configure(focus: timer.focusMinutes, rest: $0) }
                ), in: 1...30)
            }
            Text(message).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                switch timer.status {
                case .ready:
                    Button("Начать работу") { timer.startNext() }
                case .running:
                    Button("Пауза таймера") { timer.pause() }
                case .paused:
                    Button("Продолжить таймер") { timer.resume() }
                case .finished:
                    Button(timer.phase == .focus ? "Начать отдых" : "Начать работу") { timer.startNext() }
                }
                Spacer()
                if timer.status != .ready {
                    Button("Сбросить") { timer.reset() }
                }
            }
        }
        .font(.subheadline)
        .padding(12)
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private var message: String {
        switch timer.status {
        case .ready: return "Выбери длительность и начни сеанс."
        case .running: return timer.phase == .focus ? "Время сосредоточиться." : "Время отдохнуть от экрана."
        case .paused: return "Таймер на паузе. Анимация управляется отдельно."
        case .finished: return timer.phase == .focus
            ? "Работа завершена — пора на перерыв."
            : "Перерыв завершён. Готов к следующему сеансу?"
        }
    }
}

struct PicoMenuBarLabel: View {
    @ObservedObject var timer: FocusTimer

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "pawprint.fill")
            switch timer.status {
            case .ready: EmptyView()
            case .running: Text(timer.timeLabel).monospacedDigit()
            case .paused:
                Image(systemName: "pause.fill")
                Text(timer.timeLabel).monospacedDigit()
            case .finished:
                Text(timer.phase == .focus ? "Пора отдохнуть" : "Отдых завершён")
            }
        }
        .accessibilityLabel("Pico")
    }
}
