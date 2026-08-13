# Homa Ghost Subscription

قالب فارسی، مدرن و واکنش‌گرای صفحه سابسکریپشن **مرزبان** با نصب تک‌خطی، شخصی‌سازی پایدار، نمودار و پیش‌بینی مصرف، تمدید هوشمند، QR داخلی و آموزش ۹ کلاینت.

[راهنمای کامل فارسی](README-FA.md) · [تغییرات نسخه‌ها](CHANGELOG.md) · [گزارش تست](QA-REPORT.md) · [منابع](SOURCES.md)

## نصب یا بروزرسانی با یک خط

این خط را در ترمینال **سرور لینوکسی مرزبان** اجرا کن:

```bash
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/radar-kx/homa-ghost-subscription/main/install-online.sh | sudo bash
```

همین یک دستور نسخه پایدار `v2.3.0` را دانلود می‌کند، SHA-256 و ساختار امن ZIP را بررسی می‌کند، از نسخه فعلی بکاپ می‌گیرد، قالب را نصب یا بروزرسانی می‌کند و مرزبان را ری‌استارت می‌کند. تنظیمات برند و پشتیبانی در بروزرسانی حفظ می‌شوند و اگر نصب شکست بخورد، وضعیت قبلی خودکار برمی‌گردد.

اگر از قبل با کاربر `root` وارد شده‌ای و `sudo` نداری، انتهای دستور را به `bash` تغییر بده. این فرمان در PowerShell ویندوز اجرا نمی‌شود؛ از SSH وارد سرور شو و آن را همان‌جا اجرا کن.

## امکانات نسخه ۲.۳

- طراحی Mobile-first برای موبایل، تبلت و دسکتاپ، با تم تاریک/روشن ماندگار
- نمایش وضعیت فعال، اتمام حجم، انقضا، غیرفعال و در انتظار شروع
- نمودار واقعی ۷، ۱۴ و ۳۰ روزه از endpoint رسمی `/usage`
- میانگین مصرف روزانه، تخمین زمان تمام‌شدن حجم و هشدار ۸۰/۹۰ درصد
- پیشنهاد تمدید هوشمند بر اساس حجم، تاریخ پایان و وضعیت حساب
- گزارش عیب‌یابی امن، بدون لینک سابسکریپشن، توکن یا کانفیگ
- QR داخلی و کپی لینک/کانفیگ بدون وابستگی اجرایی به CDN
- تشخیص Android، iOS، Windows، macOS و Linux
- آموزش ۹ کلاینت و ورود یک‌کلیکی در کلاینت‌های پشتیبانی‌شده
- V2Box برای Android و iPhone/iPad با لینک رسمی فروشگاه‌ها
- تست اختیاری دانلود، آپلود، پینگ و جیتر
- ویزارد شخصی‌سازی نام برند، پشتیبانی، کانال، رنگ، لوگو و پیام تمدید
- فرمان مدیریتی `homa-sub` برای وضعیت، تنظیم، بروزرسانی، بکاپ، بازیابی، عیب‌یابی و حذف
- نگه‌داری تنظیمات بین بروزرسانی‌ها و حفظ حداکثر سه بکاپ سالم

## مدیریت بعد از نصب

منوی فارسی:

```bash
sudo homa-sub
```

فرمان‌های پرکاربرد:

```bash
sudo homa-sub configure   # شخصی‌سازی قالب
sudo homa-sub update      # بروزرسانی امن با حفظ تنظیمات
sudo homa-sub doctor      # بررسی سلامت نصب
sudo homa-sub backup      # ساخت بکاپ دستی
sudo homa-sub rollback    # بازگشت به آخرین بکاپ
sudo homa-sub status      # نمایش وضعیت و نسخه
```

تنظیمات پایدار در `/etc/homa-ghost-subscription/config.env` نگه‌داری و هنگام هر بروزرسانی دوباره به `config.js` امن تبدیل می‌شوند.

## کلاینت‌های پشتیبانی‌شده

| سیستم‌عامل | کلاینت‌ها |
|---|---|
| Android | Hiddify، v2rayNG، Happ، V2Box |
| iOS / iPadOS | Hiddify، Happ، Streisand، V2Box، Shadowrocket |
| Windows | Hiddify، Happ، v2rayN، Clash Verge Rev |
| macOS | Hiddify، Happ، v2rayN، Clash Verge Rev |
| Linux | Hiddify، Happ، v2rayN، Clash Verge Rev، v2rayA |

## نصب دستی

[دانلود Homa Ghost Subscription v2.3.0](dist/Homa-Ghost-Subscription-v2.3.0.zip) · [مشاهده SHA-256](dist/Homa-Ghost-Subscription-v2.3.0.zip.sha256)

```bash
unzip Homa-Ghost-Subscription-v2.3.0.zip
cd Homa-Ghost-Subscription-v2.3.0
chmod +x install.sh
sudo ./install.sh
```

اگر فایل `.env` مرزبان در مسیر دیگری است:

```bash
sudo MARZBAN_ENV_FILE="/path/to/.env" ./install.sh
```

## تست توسعه

```bash
npm ci
npm test
```

نسخه `2.3.0` با ۲۲ سناریوی خودکار شامل وضعیت‌های حساب، Jinja، QR، کلاینت‌ها، پیش‌بینی و تمدید، گزارش امن، HTML، دسترس‌پذیری، نصب، حفظ تنظیمات، بکاپ، rollback، مهاجرت نسخه قدیمی، حذف، endpointهای مرزبان و بسته‌های انتشار ناامن بررسی می‌شود.

## فایل‌های مهم

- `index.html`: قالب اصلی مرزبان
- `config.default.env`: تنظیمات پیش‌فرض پایدار
- `homa-sub`: ابزار مدیریت نصب
- `install-online.sh`: نصب تک‌خطی با اعتبارسنجی بسته
- `install.sh`: نصب محلی، بکاپ و rollback
- `vendor/qrcode.js`: تولید QR داخلی
- `tests/`: تست‌های رابط و چرخه نصب

## نکته امنیتی

لینک سابسکریپشن هر کاربر محرمانه است. آن را در Issue، اسکرین‌شات عمومی یا پیام پشتیبانی منتشر نکن. برای پشتیبانی از دکمه «کپی گزارش امن» داخل قالب استفاده کن.

## English summary

Homa Ghost Subscription v2.3.0 is a Persian Marzban subscription template with responsive dark/light themes, persistent branding, smart renewal prompts, usage forecasting, safe diagnostics, self-hosted QR generation, nine client guides, and a checksum-verified one-line installer with backup and rollback support.

See [README-FA.md](README-FA.md) for the complete Persian guide.
