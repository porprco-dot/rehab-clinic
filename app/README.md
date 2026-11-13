# اپ حقوق درمان (Flutter، اندروید)

فعلاً فقط تب «ماشین‌حساب» ساخته شده؛ سه تب دیگر صفحه‌ی خالی هستند و در فازهای بعد، هر کدام در پوشه‌ی خودش زیر `lib/features/` ساخته می‌شود.

## ساختار
```
lib/
├── main.dart                       ← ساخت repository و اجرای اپ
├── app/                            ← MaterialApp (فارسی/راست‌به‌چپ)، تم روشن/تاریک، نوار ۴ تب
├── core/
│   ├── config/api_config.dart      ← آدرس سرور (از --dart-define)
│   ├── math/fraction.dart          ← کسر دقیق (بدون float)
│   ├── format/persian_number.dart  ← ارقام فارسی، جداکننده‌ی هزارگان، تاریخ
│   └── strings/app_strings.dart    ← برچسب‌های رابط کاربری (دکمه‌ها، تب‌ها)
└── features/
    ├── home/ cases/ account/       ← فعلاً خالی
    └── calculator/
        ├── data/                   ← خواندن فایل نرخ + کش (سرور ← کش ← پیش‌فرض)
        ├── domain/                 ← منطق محاسبه و زمان‌بندی پرداخت
        └── presentation/           ← صفحه و ویجت‌ها
assets/
├── data/diyeh_rates_default.json   ← نسخه‌ی آفلاین داخل اپ (کپی فایل سرور)
└── fonts/                          ← وزیرمتن (لایسنس OFL)
```

همه‌ی عددها، کسرها و متن‌های حقوقی از فایل نرخ می‌آیند؛ فقط برچسب‌های رابط کاربری در `app_strings.dart` هستند.

## اجرا
```bash
flutter pub get
flutter test                      # همه‌ی تست‌ها
flutter run                       # بدون سرور: فقط نرخ داخل اپ / کش
flutter run --dart-define=DIYEH_API_BASE_URL=https://api.vakilrobot.ir
```
برای آزمایش با سرور روی همان کامپیوتر در شبیه‌ساز اندروید (فقط نسخه‌ی debug اجازه‌ی http دارد):
```bash
flutter run --dart-define=DIYEH_API_BASE_URL=http://10.0.2.2:8105
```

## هر بار که فایل نرخ سرور عوض شد
فایل سرور را در `assets/data/diyeh_rates_default.json` کپی کنید تا نسخه‌ی آفلاین اپ‌های جدید هم به‌روز باشد. تست `bundled_rates_sync_test.dart` اگر این دو یکی نباشند خطا می‌دهد. (برای اپ‌های نصب‌شده لازم نیست؛ آن‌ها از سرور می‌گیرند.)

## قبل از انتشار در کافه‌بازار
- `applicationId` فعلاً `com.hoghooghdarman.hoghoogh_darman` است؛ بعد از اولین انتشار **قابل تغییر نیست**. قبل از انتشار نهایی‌اش کنید.
- آدرس نهایی سرور (HTTPS) با `--dart-define` در build داده شود.
- قاعده‌ی دیه‌ی زن هنوز پیاده نشده (در انتظار تصمیم حقوقی)؛ تا آن موقع گزینه‌ی جنسیت نمایش داده نمی‌شود.
