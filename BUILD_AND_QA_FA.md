# راهنمای ساخت VYBE v0.5.0

## سازگاری

- Flutter 3.47.7 (ثابت در هر دو Workflow)
- Java 17، Android compileSdk 36، minSdk 24
- google_fonts 6.3.3، file_picker 12.1.3
- Android media controls: audio_service 0.18.19، audio_session 0.2.4
- Android music scanning: Kotlin MediaStore bridge؛ بدون on_audio_query قدیمی

## ساخت

پس از آپلود **محتویات** بسته به ریشه GitHub (شامل پوشه مخفی `.github/workflows`)، Actions باید Windows v0.5 و Android v0.5 Release Preview را نشان بدهد.

برای آزمون محلی یا در CI:

```bash
flutter pub get
python -m unittest discover -s scripts/tests -p 'test_*.py' -v
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build apk --release
```

در صورت ساخت در محیط تازه، ابتدا `flutter create --empty --project-name vybe --platforms=android .` و سپس `python scripts/configure_android.py` اجرا شود. برای Windows از Workflow مخصوص همان پلتفرم استفاده کنید.

فایل خروجی اندروید `build/app/outputs/flutter-apk/app-release.apk` است. در صورت موفقیت هر دو Workflow، Artifact از بخش Summary همان Run دانلود می‌شود. کل پوشه Release ویندوز باید کنار EXE باقی بماند.

## تفسیر نتایج

- آزمون‌های ساختاری Python **Build واقعی نیستند**.
- APK آزمایشی Release از نظر کارایی برای مقایسه با Debug مناسب‌تر است، ولی امضای تولیدکننده رسمی ندارد.
- خطاهای احتمالی Build را از **اولین** خطای meaningful در GitHub log بررسی کنید، نه صرفاً `Gradle task failed`.
- ویندوز و اندروید را پس از نصب در شرایط واقعی تست کنید؛ مخصوصاً اعلان و کنترل صفحه قفل، مجوز فایل صوتی، صدای دستگاه و دانلودهای درون‌برنامه‌ای.
