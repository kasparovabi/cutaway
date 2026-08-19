<p align="center"><img src=".github/screenshot.png" alt="Cutaway" width="820"></p>

# Cutaway

**Cutaway, kurgucuların araya girmek için kullandığı klipleri bulur.**

Kurguladığın videoyu ver. Konuşmayı çözer, her cümleyi okur ve o cümlenin hemen ardına oturacak kısa viral ya da tepki kliplerini internette arar. Beğendiklerini seçersin, Cutaway zaman damgalı adlarla indirir ve dosyalar Premiere, Final Cut ya da Resolve bin'ine doğrudan girer.

## Nasıl çalışır

1. **Video aç.** Cutaway konuşmayı Whisper ile yerelde çözer ve cümlelere böler.
2. **Tara.** Her cümle için Claude niyeti çıkarır (duygu, beklenen tepki, arama sorguları), Cutaway YouTube'da arar.
3. **Filtrele.** Adaylar kaynak videonun yönünü korur (dikey videoya dikey aday gelir) ve dil kuralına uyar. Konuşmalı klip videonun dilinde konuşmak zorundadır, konuşmasız klibin ise konuya uyması yeter.
4. **Puanla.** Claude her adayı cümleye göre 0-10 arası puanlar. En az beş aday kısa gerekçesiyle listeye düşer, sıralama izlenme sayısına göre çoktan azadır. Her öneri bir de kesit penceresi taşır (`kesit 0:04-0:07`), yani klibin cümlenin ardına en çok yakışacak saniyeleri.
5. **İzle.** Oynat düğmesi adayı uygulamanın içinde açar ve doğrudan önerilen kesitten başlatır. Tarayıcıya gitmek gerekmez.
6. **İndir.** Tek tık. Klip, videonun yanındaki `<video>-clips` klasörüne `00m12s-sasiran-adam.mp4` gibi bir adla iner. Addaki damga, ait olduğu cümlenin zamanıdır.

İndirilen her klip aynı zamanda yerel kütüphaneye girer. Sonraki taramalar önce kütüphaneye bakar, işe yaramış klipler yeniden indirme olmadan tekrar önüne gelir.

## Gereksinimler

- macOS 14 ve üzeri
- Komut satırı araçları

```bash
brew install openai-whisper ffmpeg
```

- Bir Anthropic kimliği (aşağıda)

yt-dlp'yi baştan kurman gerekmez. Cutaway ilk kullanımda resmi sürümü kendisi indirir ve haftada bir günceller, sende brew kopyası varsa onu kullanır. Uygulama açılışta kalan eksik araçları denetler ve kurulum komutlarını gösterir. İlk transkript Whisper modelini indirir (yaklaşık 1.5 GB), o yüzden biraz sürer; sonraki koşular hızlıdır.

whisper kurmak istemiyorsan bir Groq anahtarı ekle (aşağıda), transkripsiyon bulutta çalışır.

## Kurulum

Zip'i [Releases](../../releases) sayfasından indir, aç, Applications'a sürükle. Derleme imzasız olduğu için macOS ilk açılışta izin vermez. Karantina bayrağını temizle.

```bash
xattr -dr com.apple.quarantine /Applications/Cutaway.app
```

Ya da bir kez açmayı dene, sonra Sistem Ayarları içindeki Gizlilik ve Güvenlik bölümünden Yine de Aç ile onayla.

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

Taramalar `claude-sonnet-5` çağırır, cümle başına iki istek. Başka bir model istersen, örneğin daha güçlü Opus için şunu çalıştır.

```bash
defaults write com.kasparov.cutaway cutaway.model claude-opus-5
```

Birden çok makineye dağıtım için `scripts/embed-tokens.py` ile derlemeye token havuzu gömebilirsin (ardından `xcodegen generate` çalıştır). Bir token limitine takılınca Cutaway sıradakine geçer. `Secrets.plist` gitignore'dadır, token depoya hiç girmez.

## Groq ile bulut transkripsiyonu (isteğe bağlı)

Cutaway ana transkripti Whisper'ın large modeliyle yerelde çözer. Daha küçük bir modelin devreye gireceği her yerde, yani indirilen kliplerdeki hızlı konuşma denetiminde ya da whisper kurulu olmayan bir Mac'te, Groq anahtarı o adımı buluttaki `whisper-large-v3-turbo` modeline yükseltir. Böylece her transkript large kalitesinde kalır.

1. [console.groq.com](https://console.groq.com) adresinde oturum aç.
2. **API Keys** sayfasını aç ([console.groq.com/keys](https://console.groq.com/keys)) ve **Create API Key** düğmesine bas.
3. `gsk_…` ile başlayan anahtarı kopyala, Cutaway Ayarlarındaki **Groq API anahtarı** alanına yapıştır ve kaydet.

Ortam değişkeni olarak `GROQ_API_KEY` de çalışır. Ücretsiz katman istek başına 25 MB ses kabul eder. Cutaway videoyu değil sıkıştırılmış tek kanallı ses izini yükler, birkaç dakikalık bir video rahatça sığar.

## Notlar

- İndirmeler senin makinende yt-dlp ile yapılır. Klip sahiplerinin haklarına ve indirdiğin platformların şartlarına uy. Yayınlanan kurguda neyin kullanılabileceği senin sorumluluğundadır.
- Videonun kendisi Mac'inden çıkmaz. Anthropic API'sine yalnız taranan cümle ve aday başlıkları gider. Groq anahtarı eklersen ses izi transkripsiyon için Groq'a yüklenir, eklemezsen ses de yerelde kalır.

## Lisans

[MIT](LICENSE)
