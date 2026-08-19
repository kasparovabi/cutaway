<p align="center"><img src=".github/screenshot.png" alt="Cutaway" width="820"></p>

# Cutaway

**Cutaway finds the clips editors cut away to.**

Give it the video you're editing. It transcribes the speech, reads every sentence, and hunts down short viral or reaction clips that land right after that sentence. You pick the ones you like, Cutaway downloads them with timestamp names, and they drop straight into your Premiere, Final Cut, or Resolve bin.

A cutaway is the clip you briefly cut to before returning to your scene. This app finds yours.

## How it works

1. **Open a video.** Cutaway transcribes it locally with Whisper and splits the speech into sentences.
2. **Scan.** For each sentence, Claude extracts the intent (emotion, expected reaction, search queries) and Cutaway searches YouTube.
3. **Filter.** Candidates keep the source video's orientation (a vertical video gets vertical candidates) and obey the language rule: a clip with speech must speak the video's language, while a speechless clip only has to fit the topic.
4. **Score.** Claude rates each candidate 0-10 against the sentence; the top five appear with a short reason.
5. **Download.** One click. The clip lands in a `<video>-clips` folder next to your video, named like `00m12s-surprised-guy.mp4`, the timestamp of the sentence it belongs to.

Every download also joins a local library. Future scans match against the library first, so your proven clips resurface without another download.

## Requirements

- macOS 14 or newer
- Command line tools:

```bash
brew install openai-whisper yt-dlp ffmpeg
```

- An Anthropic credential (see below)

The app checks for missing tools on launch and shows the install commands.

## Install

Grab the zip from [Releases](../../releases), unzip, drag to Applications. The build is unsigned, so open it the first time with right-click → Open, or run:

```bash
xattr -dr com.apple.quarantine /Applications/Cutaway.app
```

Or build from source:

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Cutaway.xcodeproj -scheme Cutaway -configuration Release build
```

## Credentials

Open Settings (gear icon) and paste one of:

- **Anthropic API key** (`sk-ant-api…`) from [console.anthropic.com](https://console.anthropic.com). Pay per use.
- **Claude subscription setup token** (`sk-ant-oat…`). If you have a Claude Pro or Max subscription, run `claude setup-token` in a terminal and paste the result. Usage then counts against your subscription; whether that fits Anthropic's terms for your account is yours to check.

An `ANTHROPIC_API_KEY` environment variable works too. Credentials live in the macOS Keychain and are never written to disk in the project.

For a fleet of machines you can embed a token pool into the build with `scripts/embed-tokens.py`, then re-run `xcodegen generate`; Cutaway rotates to the next token when one hits its rate limit. `Secrets.plist` is gitignored, so tokens never enter the repo.

## Notes

- Downloads run through yt-dlp on your machine. Respect the rights of clip owners and the terms of the platforms you download from; what ends up in a published edit is your responsibility.
- The video itself never leaves your Mac. Only the sentence being scanned and the candidate titles are sent to the Anthropic API.

Türkçe okumak için: [README.tr.md](README.tr.md)

## License

[MIT](LICENSE)
