import SwiftUI

struct SettingsView: View {
    var close: () -> Void

    @State private var key = ""
    @State private var saved = false

    private var hasCredential: Bool { Credentials.available }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                Text("Settings")
                    .font(Theme.Fonts.title)
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(Theme.Colors.text)

            Text("Anthropic credential")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.text)

            Text(hasCredential
                 ? String(localized: "Credential saved. Enter a new one to replace it.")
                 : String(localized: "Intent extraction and scoring run on this. Use an Anthropic API key (sk-ant-api…) or a Claude subscription setup token (sk-ant-oat…, created with 'claude setup-token'). Stored only in this Mac's Keychain."))
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.textDim)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("sk-ant-api03-… / sk-ant-oat01-…", text: $key)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())

            HStack(spacing: 10) {
                Button("Save") {
                    Credentials.save(key)
                    key = ""
                    saved = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Theme.Colors.accent, in: Capsule())
                .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)

                if saved {
                    Text("Saved")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Colors.textDim)
                }
                Spacer()
                Text("model: \(ModelClient.model)")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Colors.textDim)
            }
        }
        .padding(Theme.Metrics.panelPadding)
        .frame(width: 340)
        .glassSurface()
    }
}
