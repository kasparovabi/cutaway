<p align="center"><img src=".github/screenshot.png" alt="Cutaway" width="820"></p>

# Cutaway

**Cutaway, kurgucuların araya girmek için kullandığı klipleri bulur.**

Kurguladığın videoyu ver. Konuşmayı çözer, her cümleyi okur ve o cümlenin hemen ardına oturacak kısa viral ya da tepki kliplerini internette arar. Beğendiklerini seçersin, Cutaway zaman damgalı adlarla indirir ve dosyalar Premiere, Final Cut ya da Resolve bin'ine doğrudan girer.

## Nasıl çalışır

1. **Video aç.** Cutaway konuşmayı Whisper ile yerelde çözer ve cümlelere böler.
2. **Tara.** Her cümle için Claude niyeti çıkarır (duygu, beklenen tepki, arama sorguları), Cutaway YouTube'da arar.
3. **Filtrele.** Adaylar kaynak videonun yönünü korur (dikey videoya dikey aday gelir) ve dil kuralına uyar. Konuşmalı klip videonun dilinde konuşmak zorundadır, konuşmasız klibin ise konuya uyması yeter.
4. **Puanla.** Claude her adayı cümleye göre 0-10 arası puanlar, en iyi beşi kısa bir gerekçeyle listeye düşer.
5. **İndir.** Tek tık. Klip, videonun yanındaki `<video>-clips` klasörüne `00m12s-sasiran-adam.mp4` gibi bir adla iner. Addaki damga, ait olduğu cümlenin zamanıdır.

İndirilen her klip aynı zamanda yerel kütüphaneye girer. Sonraki taramalar önce kütüphaneye bakar, işe yaramış klipler yeniden indirme olmadan tekrar önüne gelir.

## Gereksinimler

- macOS 14 ve üzeri
- Komut satırı araçları

```bash
brew install openai-whisper yt-dlp ffmpeg
```

- Bir Anthropic kimliği (aşağıda)

Uygulama açılışta eksik araçları denetler ve kurulum komutlarını gösterir.

## Kurulum

Zip'i [Releases](../../releases) sayfasından indir, aç, Applications'a sürükle. Derleme imzasız olduğu için ilk açılışta sağ tık ve Aç yolunu kullan, ya da şunu çalıştır.

```bash
xattr -dr com.apple.quarantine /Applications/Cutaway.app
```

Kaynaktan derlemek istersen

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Cutaway.xcodeproj -scheme Cutaway -configuration Release build
```

## Kimlikler

Ayarları aç (dişli simgesi) ve şunlardan birini yapıştır.

- **Anthropic API anahtarı** (`sk-ant-api…`), [console.anthropic.com](https://console.anthropic.com) üzerinden. Kullandıkça ödersin.
- **Claude abonelik setup token'ı** (`sk-ant-oat…`). Claude Pro ya da Max aboneliğin varsa terminalde `claude setup-token` çalıştırıp çıktıyı yapıştır. Kullanım aboneliğinden düşer. Bunun kendi hesabın için Anthropic şartlarına uyup uymadığını kontrol etmek sana düşer.

Ortam değişkeni olarak `ANTHROPIC_API_KEY` de çalışır. Kimlikler macOS Keychain'inde durur, projede diske yazılmaz.

Birden çok makineye dağıtım için `scripts/embed-tokens.py` ile derlemeye token havuzu gömebilirsin. Bir token limitine takılınca Cutaway sıradakine geçer. `Secrets.plist` gitignore'dadır, token depoya hiç girmez.

## Notlar

- İndirmeler senin makinende yt-dlp ile yapılır. Klip sahiplerinin haklarına ve indirdiğin platformların şartlarına uy. Yayınlanan kurguda neyin kullanılabileceği senin sorumluluğundadır.
- Videonun kendisi Mac'inden çıkmaz. Anthropic API'sine yalnız taranan cümle ve aday başlıkları gider.

## Lisans

[MIT](LICENSE)
