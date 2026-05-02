import SwiftUI

// Pesito design system — tokens lifted from /opt/gaz.eg.je/public/styles.css
// (web app cream/editorial). Single source of truth; touch HERE, never inline
// hex/rgb in views. OKLCH from web converted to RGB approximations.
enum PesitoColor {
    // Surfaces
    static let bg        = Color(red: 0.965, green: 0.945, blue: 0.910) // warm cream paper
    static let bgRaised  = Color(red: 1.000, green: 0.992, blue: 0.972) // cards / sheets
    static let line      = Color(red: 0.870, green: 0.840, blue: 0.790) // hairline borders

    // Ink (text)
    static let ink       = Color(red: 0.180, green: 0.150, blue: 0.115) // primary text
    static let inkSoft   = Color(red: 0.460, green: 0.420, blue: 0.360) // secondary text
    static let inkMuted  = Color(red: 0.620, green: 0.580, blue: 0.520) // tertiary

    // Brand (terracotta)
    static let brand     = Color(red: 0.835, green: 0.380, blue: 0.220) // primary CTA
    static let brandDark = Color(red: 0.710, green: 0.300, blue: 0.180) // pressed
    static let brandSoft = Color(red: 0.957, green: 0.870, blue: 0.820) // wash

    // Status
    static let success   = Color(red: 0.310, green: 0.530, blue: 0.350)
    static let warning   = Color(red: 0.860, green: 0.660, blue: 0.180)
    static let danger    = Color(red: 0.760, green: 0.250, blue: 0.250)
}

// Spacing scale — 4pt, semantic names. Add a step ONLY when there's a real
// rhythm gap; do not introduce arbitrary new sizes.
enum PesitoSpace {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// Typography. Use these instead of `.font(.title)` etc.
// We register Antonio + Manrope in Resources (loaded via UIAppFonts).
// Falls back to SF Pro automatically if family missing.
extension Font {
    private static let displayName = "Antonio-Bold"
    private static let bodyName    = "Manrope-Regular"
    private static let bodyBoldName = "Manrope-Bold"

    static func pesitoDisplay(_ size: CGFloat) -> Font {
        .custom(displayName, size: size, relativeTo: .largeTitle)
    }
    static func pesitoBody(_ size: CGFloat = 16, weight: Weight = .regular) -> Font {
        .custom(weight == .bold ? bodyBoldName : bodyName, size: size, relativeTo: .body)
    }

    // Semantic shortcuts — everywhere in views, prefer these over raw sizes.
    static let pesitoTitleXL = Font.pesitoDisplay(56)
    static let pesitoTitleL  = Font.pesitoDisplay(40)
    static let pesitoTitleM  = Font.pesitoDisplay(28)
    static let pesitoTitleS  = Font.pesitoDisplay(20)

    static let pesitoBodyL   = Font.pesitoBody(18)
    static let pesitoBodyM   = Font.pesitoBody(16)
    static let pesitoBodyS   = Font.pesitoBody(14)
    static let pesitoCaption = Font.pesitoBody(12)
    static let pesitoLabel   = Font.pesitoBody(11, weight: .bold)  // for tracking-uppercase labels
}

// Reusable button styles — never inline a Capsule(.background) pattern.
struct PesitoPrimaryButton: ButtonStyle {
    var tint: Color = PesitoColor.brand
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pesitoBody(16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, PesitoSpace.md)
            .background(configuration.isPressed ? tint.opacity(0.85) : tint)
            .clipShape(Capsule())
    }
}

struct PesitoSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pesitoBody(15, weight: .bold))
            .foregroundColor(PesitoColor.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, PesitoSpace.md - 2)
            .overlay(Capsule().stroke(PesitoColor.ink, lineWidth: 1.5))
            .background(configuration.isPressed ? PesitoColor.brandSoft : Color.clear)
            .clipShape(Capsule())
    }
}

struct PesitoGhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pesitoBody(14, weight: .bold))
            .foregroundColor(PesitoColor.inkSoft)
            .padding(.horizontal, PesitoSpace.sm)
            .padding(.vertical, PesitoSpace.xs)
            .background(configuration.isPressed ? PesitoColor.brandSoft : Color.clear)
            .clipShape(Capsule())
    }
}

// View modifier — wraps content in the standard cream surface (used by Card).
struct PesitoCard: ViewModifier {
    var bordered: Bool = true
    func body(content: Content) -> some View {
        content
            .padding(PesitoSpace.lg)
            .background(PesitoColor.bgRaised)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(bordered ? PesitoColor.ink : PesitoColor.line, lineWidth: bordered ? 1.5 : 1)
            )
    }
}

extension View {
    func pesitoCard(bordered: Bool = true) -> some View { modifier(PesitoCard(bordered: bordered)) }

    // Standard form-field styling — terra background, ink border on focus.
    func pesitoField() -> some View {
        self
            .font(.pesitoBody(16))
            .padding(.horizontal, PesitoSpace.md)
            .padding(.vertical, PesitoSpace.sm + 2)
            .background(PesitoColor.bgRaised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PesitoColor.line, lineWidth: 1)
            )
    }

    // Uppercase, tracked label used as "section caption" in editorial style.
    func pesitoEyebrow() -> some View {
        self
            .font(.pesitoLabel)
            .tracking(2)
            .textCase(.uppercase)
            .foregroundColor(PesitoColor.inkSoft)
    }
}
