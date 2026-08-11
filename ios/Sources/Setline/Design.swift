import SwiftUI

enum SetlinePalette {
    static let chalk = Color(red: 247 / 255, green: 246 / 255, blue: 240 / 255)
    static let paper = Color.white
    static let ink = Color(red: 24 / 255, green: 38 / 255, blue: 46 / 255)
    static let steel = Color(red: 221 / 255, green: 225 / 255, blue: 220 / 255)
    static let lime = Color(red: 185 / 255, green: 232 / 255, blue: 63 / 255)
    static let coral = Color(red: 255 / 255, green: 97 / 255, blue: 77 / 255)
    static let blue = Color(red: 185 / 255, green: 216 / 255, blue: 232 / 255)
}

struct SetlineBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(SetlinePalette.ink)
            .background(SetlinePalette.chalk.ignoresSafeArea())
            .tint(SetlinePalette.ink)
    }
}

struct SectionLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .foregroundStyle(SetlinePalette.ink.opacity(0.62))
    }
}

struct InkRule: View {
    var body: some View {
        Rectangle()
            .fill(SetlinePalette.ink.opacity(0.16))
            .frame(height: 1)
    }
}

struct ActionSlabStyle: ButtonStyle {
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            .foregroundStyle(SetlinePalette.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(destructive ? SetlinePalette.coral : SetlinePalette.lime)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(SetlinePalette.ink.opacity(0.82))
                    .frame(height: configuration.isPressed ? 1 : 4)
            }
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func setlineBackground() -> some View { modifier(SetlineBackground()) }
}
