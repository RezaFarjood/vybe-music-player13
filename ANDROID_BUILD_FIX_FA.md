# راهنمای تاریخی 0.4.x — آخرین راهنما برای نسخه 0.5.0 در `BUILD_AND_QA_FA.md` و `V050_RELEASE_NOTES_FA.md` است.

# رفع خطای Android `FilePickerPlugin` — VYBE 0.3.2

## خطای تأییدشده

در GitHub Actions، جاوای پروژه به `GeneratedPluginRegistrant.java` می‌رسید و نمی‌توانست کلاس
`com.mr.flutter.plugin.filepicker.FilePickerPlugin` را پیدا کند.

این مشکل در شاخهٔ `file_picker` 11 با Android Gradle Plugin 9 و نحوهٔ فعال‌سازی کامپایلر Kotlin گزارش شده است؛ هنگامی که `android.builtInKotlin=false` باشد، فایل‌های Kotlin پلاگین ممکن است کامپایل نشوند.

## اصلاح اعمال‌شده

1. `pubspec.yaml`: ارتقای `file_picker` از `^11.0.3` به **نسخهٔ دقیق `12.1.3`** که در شاخهٔ federated نسخه 12 پشتیبانی AGP 9 را اصلاح کرده است.
2. `lib/services/music_controller.dart`: هماهنگ‌کردن دریافت فایل و تصویر با API نسخهٔ 12؛ خروجی `pickFiles` اکنون `List<PlatformFile>` است و لغو انتخاب، فهرست خالی برمی‌گرداند.
3. حفظ انتخاب پوشه در ویندوز و انتخاب دستی موسیقی/کاور؛ هیچ قابلیتی عمداً حذف نشده است.
4. حفظ اسکریپت مستقل مربوط به مشکلات قدیمی `on_audio_query_android` (Namespace/JVM)؛ این مشکل جداگانه است.
5. افزودن تست‌های جلوگیری از برگشت ناخواسته به API نسخهٔ 11.

## نحوهٔ استفاده در GitHub

محتویات ZIP را در **ریشه** ریپازیتوری بارگذاری کنید، نه خود ZIP را به‌عنوان تنها فایل.
پوشهٔ مخفی `.github/workflows` باید حفظ شود. پس از Commit، Workflowهای Android و Windows اجرا می‌شوند.

## محدودیت تست

تست‌های Python اجرا می‌شوند؛ اما Flutter SDK روی دستگاه سازندهٔ این بسته نصب نشده و Build واقعی APK/EXE تأیید نشده است. در صورت خطای بعدی، نخستین خطای مشخص در `Build installable Android preview APK` مبنای رفع اشکال خواهد بود.

### منابع فنی

- https://github.com/vicajilau/flutter_file_picker/issues/2200
- https://pub.dev/packages/file_picker/changelog
- https://pub.dev/packages/file_picker
