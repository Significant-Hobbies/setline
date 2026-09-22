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

/// The segmented subview switcher shared by the assessment surfaces
/// (Benchmarks, Mobility, Capability).
struct SubviewNav<Item: CaseIterable & Hashable>: View where Item.AllCases: RandomAccessCollection {
    @Binding var active: Item
    var label: (Item) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Item.allCases), id: \.self) { item in
                Button {
                    active = item
                } label: {
                    Text(label(item))
                        .font(.subheadline.weight(active == item ? .black : .semibold))
                        .foregroundStyle(active == item ? SetlinePalette.ink : SetlinePalette.ink.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(active == item ? SetlinePalette.lime : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(3)
        .background(SetlinePalette.steel.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

/// The big-number stat tile used at the top of assessment surfaces.
struct MetricStatTile: View {
    var value: String
    var suffix: String?
    var label: String
    var background: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 30, weight: .black, design: .rounded).monospacedDigit())
                if let suffix {
                    Text(suffix)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(SetlinePalette.ink.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// An icon plus a cautionary footnote — the "what this is not" line that
/// closes an assessment surface.
struct InfoNote: View {
    var icon: String?
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.6))
            }
            Text(text)
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.72))
        }
        .padding(.top, 8)
    }
}

/// A titled prose card — the Guide tab's repeating unit.
struct GuideCard: View {
    var title: String
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline.weight(.black))
            Text(text)
                .font(.footnote)
                .foregroundStyle(SetlinePalette.ink.opacity(0.75))
        }
        .paperCard()
    }
}

/// The trailing chevron and row chrome shared by tappable list rows.
struct RowChrome: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            content
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(SetlinePalette.ink)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

struct PaperCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(SetlinePalette.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

extension View {
    func setlineBackground() -> some View { modifier(SetlineBackground()) }
    func rowChrome() -> some View { modifier(RowChrome()) }
    func paperCard() -> some View { modifier(PaperCard()) }
}
