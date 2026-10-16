# یادداشت قدیمی نسخه 0.4.1؛ برای v0.5.0 از `README_FA.md` استفاده کنید.

# رفع خطای مشترک Windows و Android — VYBE v0.4.1

## تشخیص قطعی از دو لاگ ارسالی

- **Windows:** `google_fonts-6.3.0/lib/src/google_fonts_variant.dart(152,42): Constant evaluation error`
- **Android:** خطای تولید Kernel Snapshot در `google_fonts_variant.dart` و در بخش Map مربوط به `FontWeight`.
- اینها دو نمود یک مشکل وابستگی در Flutter جدید هستند، نه شکست MediaStore یا کد پخش.

## اصلاح اصلی فقط یک خط است

در `pubspec.yaml`:

```yaml
# OLD
  google_fonts: 6.3.0
# NEW
  google_fonts: 6.3.3
```

توضیح: نسخه 6.3.2 پکیج google_fonts مشکل Map با کلید FontWeight را رفع کرده و 6.3.3 سازگاری FontWeight.index را هم بهتر کرده است.
منبع رسمی: https://pub.dev/packages/google_fonts/changelog

## دو راه استفاده

**راحت‌ترین و کم‌حجم‌ترین راه:** در GitHub فقط فایل `pubspec.yaml` را ویرایش کن و `google_fonts: 6.3.0` را به `google_fonts: 6.3.3` تغییر بده. Commit کن تا هر دو Workflow دوباره اجرا شوند. نیازی به جایگزینی ۴۰ فایل نیست.

**راه دوم:** ZIP کامل v0.4.1 را Extract و جایگزین سورس قبلی کن. در این ZIP علاوه بر اصلاح پکیج، تست رگرسیون و بررسی زودهنگام نسخه نصب‌شده در هر دو Workflow اضافه شده است.

## پس از ثبت Commit

1. از Actions جدیدترین Build اندروید و ویندوز با Commit یکسان را بررسی کن.
2. با اجرای `flutter pub get`، نسخه `google_fonts` از روی pubspec جدید دوباره resolve می‌شود.
3. اگر کد قدیمی دوباره از Cache انتخاب شد، از لاگ `flutter pub deps` و `pubspec.lock` نسخه واقعی را بخوان؛ با نسخه جدید نباید 6.3.0 باشد.
4. هیچ اخطار امنیتی Windows/Play Protect را با خاموش کردن محافظت دور نزن.

**نکته:** Flutter SDK و ابزارهای Windows/Android در این محیط نصب نیستند؛ بنابراین تست Python و کنترل سورس موفق است اما Build واقعی EXE/APK تا اجرای GitHub Actions تأیید نمی‌شود.
