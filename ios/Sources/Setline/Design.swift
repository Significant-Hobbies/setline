import SwiftUI
import SaaSMakerUI

enum SetlinePalette {
    /// Neutral sans preset with Setline's authored daylight scorecard colors.
    static let theme: SMPalette = {
        let ink = Color(red: 24 / 255, green: 38 / 255, blue: 46 / 255)
        var palette = SMPalette.base.brand(
            Color(red: 185 / 255, green: 232 / 255, blue: 63 / 255),
            foreground: ink
        )
        palette.background = Color(red: 247 / 255, green: 246 / 255, blue: 240 / 255)
        palette.foreground = ink
        palette.primary = ink
        palette.primaryForeground = palette.background
        palette.border = Color(red: 221 / 255, green: 225 / 255, blue: 220 / 255)
        palette.surface = palette.border
        palette.mutedForeground = ink.opacity(0.62)
        palette.hairline = ink.opacity(0.12)
        palette.destructive = Color(red: 255 / 255, green: 97 / 255, blue: 77 / 255)
        palette.accent = Color(red: 185 / 255, green: 216 / 255, blue: 232 / 255)
        palette.radius = 10
        return palette
    }()

    static let chalk = theme.background
    static let paper = theme.card
    static let ink = theme.foreground
    static let steel = theme.border
    static let lime = theme.brand
    static let coral = theme.destructive
    static let blue = theme.accent
}

/// Bundled UI roles scale with the corresponding Dynamic Type role.
enum SetlineType {
    static let largeTitle = Font.custom(SetlinePalette.theme.displayFont, size: 34, relativeTo: .largeTitle).weight(.heavy)
    static let title = Font.custom(SetlinePalette.theme.displayFont, size: 28, relativeTo: .title).weight(.heavy)
    static let title2 = Font.custom(SetlinePalette.theme.displayFont, size: 22, relativeTo: .title2)
    static let title3 = Font.custom(SetlinePalette.theme.displayFont, size: 20, relativeTo: .title3)
    static let headline = Font.custom(SetlinePalette.theme.displayFont, size: 17, relativeTo: .headline)
    static let subheadline = Font.custom(SetlinePalette.theme.sansFont, size: 15, relativeTo: .subheadline)
    static let body = Font.custom(SetlinePalette.theme.sansFont, size: 17, relativeTo: .body)
    static let footnote = Font.custom(SetlinePalette.theme.sansFont, size: 13, relativeTo: .footnote)
    static let caption = Font.custom(SetlinePalette.theme.sansFont, size: 12, relativeTo: .caption)
    static let caption2 = Font.custom(SetlinePalette.theme.sansFont, size: 11, relativeTo: .caption2)
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
        SMSectionHeader(text, size: 13)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text.uppercased())
            .accessibilityAddTraits(.isHeader)
    }
}

struct InkRule: View {
    var body: some View {
        Rectangle()
            .fill(SetlinePalette.ink.opacity(0.16))
            .frame(height: 1)
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
                    Text(label(item).lowercased())
                        .accessibilityLabel(label(item))
                        .font(SetlineType.subheadline.weight(active == item ? .black : .semibold))
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
                    .font(.custom(SetlinePalette.theme.monoFont, size: 30, relativeTo: .title).weight(.heavy).monospacedDigit())
                if let suffix {
                    Text(suffix)
                        .font(SetlineType.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(label.lowercased())
                .accessibilityLabel(label)
                .font(.custom(SetlinePalette.theme.sansFont, size: 11, relativeTo: .caption2).weight(.bold))
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
                    .font(SetlineType.body)
                    .foregroundStyle(SetlinePalette.ink.opacity(0.6))
            }
            Text(text)
                .font(SetlineType.footnote)
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
            Text(title.lowercased()).font(SetlineType.headline.weight(.black))
                .accessibilityLabel(title)
            Text(text)
                .font(SetlineType.footnote)
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
                .font(SetlineType.caption)
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
        SMCard(padding: 16) { content }
    }
}

extension View {
    func setlineBackground() -> some View { modifier(SetlineBackground()) }
    func rowChrome() -> some View { modifier(RowChrome()) }
    func paperCard() -> some View { modifier(PaperCard()) }
}

/// Full-width brand action. A view (not a direct `SMButtonStyle.makeBody` call) so the
/// themed palette from the environment applies; keeps Setline's full-width action slab.
struct SetlineBrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SetlineBrandButtonBody(configuration: configuration)
    }
}

private struct SetlineBrandButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.smPalette) private var p

    var body: some View {
        configuration.label
            .font(.custom(p.displayFont, size: 16, relativeTo: .body).weight(.semibold))
            .textCase(p.uiLowercase ? .lowercase : nil)
            .foregroundStyle(p.brandForeground)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(p.brand, in: .capsule)
            .contentShape(.capsule)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}
