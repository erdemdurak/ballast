import SwiftUI

enum Token {
    static let ink = Color(hex: 0x16202B)
    static let ink2 = Color(hex: 0x3A4A57)
    static let mute = Color(hex: 0x78878F)
    static let paper = Color(hex: 0xE3E9EA)
    static let panel = Color(hex: 0xF2F6F6)
    static let line = Color(hex: 0xC3CDCF)
    static let calm = Color(hex: 0x47756A)
    static let pickup = Color(hex: 0x2F5C7C)
    static let slip = Color(hex: 0x8A5573)

    static let radius: CGFloat = 2
    static let buttonHeight: CGFloat = 52
    static let minTarget: CGFloat = 48
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

/// IBM Plex is the specified family. It is not on iOS and the files are not in the
/// repo, so these fall back to the system faces at the same three roles: condensed
/// for display, regular for body, monospaced for data. Drop the Plex .ttf files in
/// and change these three functions.
enum Face {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }

    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }

    static func data(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// 11 px, 0.18em tracking, uppercase.
struct Eyebrow: View {
    let text: String
    var color: Color = Token.mute

    var body: some View {
        Text(text.uppercased(with: .current))
            .font(Face.data(11, .medium))
            .tracking(11 * 0.18)
            .foregroundStyle(color)
    }
}

struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Face.display(17, .semibold))
            .foregroundStyle(Token.panel)
            .frame(maxWidth: .infinity, minHeight: Token.buttonHeight)
            .background(Token.ink.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(.rect(cornerRadius: Token.radius))
    }
}

struct OutlineButtonStyle: ButtonStyle {
    var color: Color = Token.ink
    var inert = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Face.display(17, .semibold))
            .foregroundStyle(inert ? Token.mute : color)
            .frame(maxWidth: .infinity, minHeight: Token.buttonHeight)
            .overlay(
                RoundedRectangle(cornerRadius: Token.radius)
                    .stroke(inert ? Token.line : color, lineWidth: 1))
    }
}
