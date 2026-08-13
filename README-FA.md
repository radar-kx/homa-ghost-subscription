# راهنمای کامل Homa Ghost Subscription

نسخه پایدار: `2.3.0`

Homa Ghost یک قالب فارسی، سریع و واکنش‌گرا برای صفحه اشتراک مرزبان است. نسخه ۲.۳ علاوه بر رابط کامل نسخه‌های قبل، تنظیمات پایدار، ویزارد مدیریت، پیش‌بینی مصرف، تمدید هوشمند و گزارش عیب‌یابی امن را اضافه می‌کند.

## نصب تک‌خطی

از طریق SSH وارد **سرور لینوکسی مرزبان** شو و فقط این یک خط را اجرا کن:

```bash
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/radar-kx/homa-ghost-subscription/main/install-online.sh | sudo bash
```

این یک خط به‌ترتیب:

1. بسته رسمی `v2.3.0` و فایل SHA-256 آن را از مخزن پروژه می‌گیرد.
2. نام و مقدار checksum، مسیرهای ZIP، تعداد فایل‌ها، اندازه بازشده و نبود symlink را بررسی می‌کند.
3. در صورت نیاز `unzip` را روی Debian/Ubuntu/Fedora/RHEL/CentOS نصب می‌کند.
4. پیش از تغییر، از قالب، تنظیمات، ابزار مدیریت و `.env` مرزبان بکاپ می‌گیرد.
5. قالب و فرمان `homa-sub` را نصب و دو متغیر لازم مرزبان را ثبت می‌کند.
6. تنظیمات نسخه قبلی را نگه می‌دارد و مرزبان را ری‌استارت می‌کند.
7. در صورت شکست هر مرحله، بکاپ قبل از نصب را خودکار بازیابی می‌کند.
8. در اجرای تعاملی، پیشنهاد می‌دهد برند، لینک‌ها، رنگ، لوگو و پیام تمدید را همان لحظه تنظیم کنی.

اگر با کاربر `root` وارد شده‌ای و `sudo` روی سرور وجود ندارد:

```bash
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/radar-kx/homa-ghost-subscription/main/install-online.sh | bash
```

این فرمان مخصوص Linux است. آن را در PowerShell برنامه Codex یا ویندوز اجرا نکن؛ ابتدا با SSH به سرور مرزبان وصل شو.

## قابلیت‌های رابط

- طراحی Mobile-first برای عرض ۳۲۰ پیکسل تا دسکتاپ
- تم تاریک و روشن با ذخیره انتخاب کاربر و تشخیص تنظیم سیستم
- وضعیت‌های active، limited، expired، disabled و on_hold
- نمایش حجم مصرف‌شده/باقی‌مانده، تاریخ پایان، چرخه ریست و آخرین اتصال
- بروزرسانی بدون Reload از endpoint رسمی `/{token}/info`
- نمودار ۷، ۱۴ و ۳۰ روزه از endpoint رسمی `/{token}/usage`
- fallback به تاریخچه محلی در صورت در دسترس نبودن endpoint آمار
- میانگین روزانه، تخمین تعداد روز تا پایان حجم و هشدارهای ۸۰/۹۰ درصد
- کارت تمدید برای حجم تمام‌شده، انقضا، غیرفعال‌بودن، پایان نزدیک یا مصرف زیاد
- پیام تمدید قابل شخصی‌سازی با متغیرهای `{username}` و `{status}`
- گزارش امن شامل وضعیت کاربردی دستگاه و حساب، بدون URL، توکن یا کانفیگ
- QR داخلی برای لینک اشتراک و هر کانفیگ، بدون CDN اجرایی
- کپی لینک اصلی، کانفیگ تکی و تمام کانفیگ‌ها
- تست دانلود، آپلود، پینگ و جیتر فقط پس از درخواست کاربر
- ناوبری صفحه‌کلید، Reduced Motion، landmarkهای معنایی و نوار دسترسی موبایل
- بدون ردیاب یا تبلیغات داخل قالب

## کلاینت‌ها

| سیستم‌عامل | کلاینت‌ها |
|---|---|
| Android | Hiddify، v2rayNG، Happ، V2Box |
| iOS / iPadOS | Hiddify، Happ، Streisand، V2Box، Shadowrocket |
| Windows | Hiddify، Happ، v2rayN، Clash Verge Rev |
| macOS | Hiddify، Happ، v2rayN، Clash Verge Rev |
| Linux | Hiddify، Happ، v2rayN، Clash Verge Rev، v2rayA |

برای هر کلاینت چهار مرحله نصب، افزودن اشتراک، بروزرسانی و اتصال وجود دارد. V2Box در هر دو تب Android و iOS/iPadOS نمایش داده می‌شود و کاربر را به Google Play یا App Store رسمی همان پلتفرم می‌فرستد.

## ابزار مدیریت `homa-sub`

پس از نصب، منوی فارسی را باز کن:

```bash
sudo homa-sub
```

| فرمان | کاربرد |
|---|---|
| `sudo homa-sub status` | وضعیت نصب، نسخه و مسیرها |
| `sudo homa-sub configure` | ویزارد شخصی‌سازی |
| `sudo homa-sub update` | بروزرسانی با حفظ تنظیمات و rollback |
| `sudo homa-sub doctor` | بررسی فایل‌ها، includeها و تنظیمات مرزبان |
| `sudo homa-sub backup` | ساخت بکاپ دستی |
| `sudo homa-sub rollback` | بازیابی آخرین بکاپ |
| `sudo homa-sub uninstall` | حذف امن پس از ساخت بکاپ |

فقط سه بکاپ نهایی نگه‌داری می‌شوند تا فضای سرور بی‌دلیل پر نشود. مسیر پیش‌فرض بکاپ‌ها:

```text
/var/lib/marzban/templates/backups/
```

## شخصی‌سازی پایدار

روش پیشنهادی:

```bash
sudo homa-sub configure
```

موارد قابل تنظیم:

- نام برند، حداکثر ۶۰ نویسه
- لینک HTTPS پشتیبانی
- لینک HTTPS کانال
- رنگ اصلی به فرمت `#RRGGBB`
- لینک HTTPS لوگو یا بدون لوگو
- متن پیام تمدید، حداکثر ۲۴۰ نویسه

نمونه غیرتعاملی:

```bash
sudo homa-sub configure \
  --brand "برند من" \
  --support "https://t.me/MySupport" \
  --channel "https://t.me/MyChannel" \
  --color "#68edc4" \
  --logo "https://example.com/logo.png" \
  --renewal-message "سلام، برای تمدید {username} با وضعیت {status} پیام می‌دهم."
```

فایل اصلی تنظیمات با دسترسی `0600` در مسیر زیر ذخیره می‌شود:

```text
/etc/homa-ghost-subscription/config.env
```

هر بروزرسانی این فایل را حفظ می‌کند و یک `config.js` escapeشده برای قالب می‌سازد. برای شخصی‌سازی مستقیم `index.html` را ویرایش نکن، چون تغییر دستی ممکن است در بروزرسانی جایگزین شود.

## بروزرسانی

همان دستور نصب تک‌خطی برای بروزرسانی هم استفاده می‌شود، یا بعد از نصب اجرا کن:

```bash
sudo homa-sub update
```

پیش از بروزرسانی بکاپ ساخته می‌شود؛ تنظیمات شخصی حفظ و در صورت شکست نسخه قبلی بازیابی می‌شود.

## بازیابی و عیب‌یابی

بررسی سلامت:

```bash
sudo homa-sub doctor
```

بازگشت به آخرین بکاپ:

```bash
sudo homa-sub rollback
```

بازیابی یک بکاپ مشخص:

```bash
sudo homa-sub restore --path /var/lib/marzban/templates/backups/homa-ghost-YYYYMMDD-HHMMSS-XXXXXXXX
```

پیش از restore نیز یک safety backup ساخته می‌شود. manifest و فایل‌های بکاپ قبل از هر تغییری اعتبارسنجی می‌شوند.

## نصب دستی

[دانلود ZIP نسخه ۲.۳.۰](dist/Homa-Ghost-Subscription-v2.3.0.zip) · [SHA-256](dist/Homa-Ghost-Subscription-v2.3.0.zip.sha256)

```bash
unzip Homa-Ghost-Subscription-v2.3.0.zip
cd Homa-Ghost-Subscription-v2.3.0
chmod +x install.sh
sudo ./install.sh
```

برای مسیر سفارشی `.env`:

```bash
sudo MARZBAN_ENV_FILE="/path/to/.env" ./install.sh
```

نصب‌کننده این مقادیر را ثبت یا بروزرسانی می‌کند:

```env
CUSTOM_TEMPLATES_DIRECTORY="/var/lib/marzban/templates/"
SUBSCRIPTION_PAGE_TEMPLATE="subscription/index.html"
```

## سازگاری مرزبان

فیلدهای استفاده‌شده:

- `user.username`
- `user.status.value`
- `user.used_traffic`
- `user.data_limit`
- `user.expire`
- `user.data_limit_reset_strategy.value`
- `user.subscription_url`
- `user.online_at`
- `user.created_at`
- `user.on_hold_expire_duration`
- `user.links`

مسیرهای هم‌دامنه:

- `/{token}/info`
- `/{token}/usage`
- `/{token}/clash-meta`

این مسیرها و متغیرهای قالب در تاریخ انتشار با مستندات و سورس رسمی Marzban بررسی شده‌اند؛ لینک‌ها در [SOURCES.md](SOURCES.md) قرار دارند.

## تست توسعه

```bash
npm ci
npm test
```

۲۲ سناریوی خودکار، تمام وضعیت‌های حساب، QR، سیستم‌عامل‌ها، ۹ کلاینت، V2Box دو پلتفرم، Deep Linkها، نمودار و forecast، تمدید، گزارش امن، سرعت، Clipboard، تم، HTML، Axe، Bash، نصب، حفظ تنظیمات، ورودی نامعتبر، بکاپ خراب، rollback شکست، مهاجرت تنظیمات نسخه قبلی، حذف، HTTP smoke test و رد artifactهای انتشار ناامن را پوشش می‌دهند.

## حریم خصوصی و امنیت

- لینک اشتراک را محرمانه نگه دار.
- آن را در Issue عمومی، تصویر یا گزارش پشتیبانی قرار نده.
- گزارش امن داخل قالب عمداً URL، token و config را حذف می‌کند.
- لوگوی سفارشی از URL انتخابی مدیر بارگیری می‌شود؛ برای حفظ حریم خصوصی از دامنه‌ای استفاده کن که خودت کنترل می‌کنی.
- تست سرعت فقط با کلیک کاربر شروع می‌شود و نتیجه به مسیر شبکه او وابسته است.
