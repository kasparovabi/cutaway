import SwiftUI

struct SettingsView: View {
    var close: () -> Void

    @State private var key = ""
    @State private var groqKey = ""
    @State private var saved = false

    private var hasCredential: Bool { Credentials.available }
    private var hasGroq: Bool { Credentials.groqKey != nil }

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

            Divider().overlay(Color.white.opacity(0.1))

            Text("Groq API key (optional)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.Colors.text)

            Text(hasGroq
                 ? String(localized: "Groq key saved. Transcription can run in the cloud when whisper is missing.")
                 : String(localized: "Transcribes in the cloud (whisper-large-v3-turbo) when local whisper is missing. Free key: console.groq.com → API Keys → Create API Key."))
                .font(.system(size: 10))
                .foregroundStyle(Theme.Colors.textDim)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("gsk_…", text: $groqKey)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())

            HStack(spacing: 10) {
                Button("Save") {
                    let anthropic = key.trimmingCharacters(in: .whitespaces)
                    let groq = groqKey.trimmingCharacters(in: .whitespaces)
                    if !anthropic.isEmpty { Credentials.save(anthropic) }
                    if !groq.isEmpty { Credentials.saveGroq(groq) }
                    key = ""
                    groqKey = ""
                    saved = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Theme.Colors.accent, in: Capsule())
                .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty
                          && groqKey.trimmingCharacters(in: .whitespaces).isEmpty)

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
