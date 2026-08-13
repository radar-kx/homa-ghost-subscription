# Homa Ghost Subscription

قالب مدرن، فارسی و کاملاً واکنش‌گرای صفحه سابسکریپشن **مرزبان** با دو پوسته تاریک و روشن، نمودار مصرف، QR داخلی، تست شبکه و مرکز آموزش کلاینت‌ها.

[راهنمای فارسی کامل](README-FA.md) · [تغییرات نسخه‌ها](CHANGELOG.md) · [گزارش تست](QA-REPORT.md) · [منابع](SOURCES.md)

## امکانات

- طراحی Mobile-first برای موبایل، تبلت و دسکتاپ
- تم تاریک و روشن با ذخیره انتخاب کاربر
- نمایش وضعیت فعال، اتمام حجم، انقضا، غیرفعال و در انتظار شروع
- نمایش مصرف، حجم باقی‌مانده، تاریخ پایان، چرخه ریست و آخرین اتصال
- نمودار واقعی مصرف ۷، ۱۴ و ۳۰ روزه از endpoint رسمی `/usage`
- بروزرسانی اطلاعات حساب بدون Reload از `/info`
- QR داخلی بدون وابستگی اجرایی به CDN
- کپی لینک اشتراک، کانفیگ تکی و همه کانفیگ‌ها
- تشخیص Android، iOS، Windows، macOS و Linux
- آموزش مرحله‌ای ۹ کلاینت و ورود یک‌کلیکی در کلاینت‌های پشتیبانی‌شده
- V2Box برای Android و iPhone/iPad با لینک رسمی Google Play و App Store
- تست اختیاری دانلود، آپلود، پینگ و جیتر
- نصب یا بروزرسانی کامل قالب فقط با یک خط کد
- دانلود خودکار بسته رسمی و بررسی SHA-256 پیش از نصب
- نصب‌کننده با بکاپ خودکار و Rollback در صورت شکست
- بدون ردیاب، تبلیغات یا کتابخانه ظاهری خارجی

## کلاینت‌های پشتیبانی‌شده

| سیستم‌عامل | کلاینت‌ها |
|---|---|
| Android | Hiddify، v2rayNG، Happ، V2Box |
| iOS / iPadOS | Hiddify، Happ، Streisand، V2Box، Shadowrocket |
| Windows | Hiddify، Happ، v2rayN، Clash Verge Rev |
| macOS | Hiddify، Happ، v2rayN، Clash Verge Rev |
| Linux | Hiddify، Happ، v2rayN، Clash Verge Rev، v2rayA |

## نصب تک‌خطی روی سرور مرزبان

روی سرور لینوکسی مرزبان فقط همین یک خط را اجرا کن:

```bash
curl -fsSL https://raw.githubusercontent.com/radar-kx/homa-ghost-subscription/main/install-online.sh | sudo bash
```

با همین یک خط، آخرین بسته پایدار `v2.2.0` دانلود می‌شود، صحت آن با SHA-256 بررسی می‌شود، از قالب و تنظیمات فعلی بکاپ گرفته می‌شود، قالب جدید نصب می‌شود و مرزبان ری‌استارت می‌شود. اگر نصب شکست بخورد، نسخه قبلی به‌صورت خودکار برمی‌گردد.

اگر از قبل با کاربر `root` وارد سرور شده‌ای و `sudo` نصب نیست، انتهای همان دستور را از `sudo bash` به `bash` تغییر بده. این دستور مخصوص ترمینال لینوکس سرور است و در PowerShell ویندوز اجرا نمی‌شود.

## نصب دستی

اگر نصب دستی را ترجیح می‌دهی، فایل ZIP نسخه `v2.2.0` را دانلود و استخراج کن:

[دانلود Homa Ghost Subscription v2.2.0](dist/Homa-Ghost-Subscription-v2.2.0.zip) · [مشاهده SHA-256](dist/Homa-Ghost-Subscription-v2.2.0.zip.sha256)

```bash
unzip Homa-Ghost-Subscription-v2.2.0.zip
cd Homa-Ghost-Subscription-v2.2.0
chmod +x install.sh
sudo ./install.sh
```

نصب‌کننده:

1. فایل‌ها و ساختار قالب را بررسی می‌کند.
2. از قالب فعلی، QR محلی و فایل `.env` بکاپ می‌گیرد.
3. قالب را در `/var/lib/marzban/templates/subscription/` نصب می‌کند.
4. متغیرهای لازم را در `/opt/marzban/.env` تنظیم می‌کند.
5. مرزبان را ری‌استارت می‌کند و در صورت شکست نسخه قبلی را برمی‌گرداند.

اگر فایل `.env` جای دیگری است:

```bash
sudo MARZBAN_ENV_FILE="/path/to/.env" ./install.sh
```

## تنظیم پشتیبانی و برند

قبل از نصب، در انتهای `index.html` مقدار `YourSupport` را با آیدی پشتیبانی خودت جایگزین کن:

```js
supportUrl: "https://t.me/YourSupport"
```

## تنظیمات مرزبان

نصب‌کننده این مقادیر را به‌صورت خودکار تنظیم می‌کند:

```env
CUSTOM_TEMPLATES_DIRECTORY="/var/lib/marzban/templates/"
SUBSCRIPTION_PAGE_TEMPLATE="subscription/index.html"
```

## تست توسعه

```bash
npm ci
npm test
```

نسخه `2.2.0` در ۱۷ سناریو شامل وضعیت‌های حساب، Jinja، QR، کلاینت‌ها، Deep Linkها، نمودار مصرف، تست شبکه، Clipboard، دو پوسته، HTML، دسترس‌پذیری، نصب‌کننده محلی، نصب تک‌خطی و HTTP smoke test بررسی شده است.

## فایل‌های مهم

- `index.html`: قالب اصلی مرزبان
- `install-online.sh`: دانلود، اعتبارسنجی و نصب تک‌خطی نسخه پایدار
- `install.sh`: نصب، بکاپ و Rollback خودکار
- `vendor/qrcode.js`: تولید QR داخلی
- `tests/`: تست‌های خودکار قالب و endpointها
- `README-FA.md`: مستندات کامل فارسی
- `QA-REPORT.md`: نتیجه کنترل کیفیت نسخه

## نکته امنیتی

لینک سابسکریپشن هر کاربر محرمانه است. آن را در Issue، Screenshot عمومی یا پیام‌های پشتیبانی منتشر نکن.

## English summary

Homa Ghost Subscription is a modern Persian Marzban subscription template featuring responsive dark/light themes, account status and quota cards, 7/14/30-day usage analytics, self-hosted QR generation, configuration tools, network tests, detailed client guides, and a checksum-verified one-line installer.

See [README-FA.md](README-FA.md) for full installation and configuration details.
