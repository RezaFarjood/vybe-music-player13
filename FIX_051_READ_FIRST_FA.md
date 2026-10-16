# VYBE v0.5.1 — رفع خطای واقعی Analyzer

## علت خطا
در لاگ GitHub Actions: `lib/ui/vybe_mobile_app.dart:324:26`، مقدار عددی `450` به ویژگی `scrollCacheExtent` داده شده بود.
این ویژگی در Flutter 3.47 به نوع `ScrollCacheExtent?` نیاز دارد، نه `int`.

## رفع خطا
خط `scrollCacheExtent: 450,` از `ListView.builder` حذف شد تا Flutter مقدار پیش‌فرض امن خود را استفاده کند.
این راه‌حل بدون دست‌زدن به UI ویندوز یا عملکرد پخش انجام شده است.

## رفع سریع، بدون آپلود ZIP
در مخزن GitHub فایل `lib/ui/vybe_mobile_app.dart` را باز کنید و خط
`scrollCacheExtent: 450,` را کامل حذف کنید. سپس Commit بزنید.
اگر Workflowهای موجود گزینه‌های `--no-fatal-infos --no-fatal-warnings` را دارند، آنها را تغییر ندهید.

## تست
تست‌های Python برای بررسی ساختار و قراردادهای سورس اجرا می‌شوند. در این محیط Flutter SDK نصب نیست؛ لذا اجرای واقعی `flutter analyze`، `flutter test` و Build ویندوز/اندروید اینجا تأیید نشده است.

## اگر خطای تازه دیدید
بهترین اطلاعات، اولین خط `error •` از کل گزارش Flutter analyzer است، نه آخر لاگ Gradle.
