# یادداشت انتشار سورس VYBE v0.5.0

**محدوده تغییر:** Android: بهینه‌سازی گسترده عملکرد و UI، رفع مسیرهای ناوبری، AudioSession و MediaSession؛ Windows: فقط قابلیت کشیدن thumb نوار اسکرول.

## سرعت واقعی برنامه

- کاهش ساخت دوباره کل UI با تیک‌های پخش (ValueNotifier موضعی).
- جداکردن ساخته‌شدن MaterialApp از تغییرات مکرر کنترلر پخش.
- اسکن داده کاور با سقف دو خواندن همزمان و Metadata به صورت گروهی روی isolate.
- کاستن Blur زنده در اسکرول و اصلاح lazy list و فیلتر جست‌وجو.
- شتاب انیمیشن صفحات به ۱۵۵ میلی‌ثانیه؛ شروع برنامه بدون تأخیر مصنوعی.
- استفاده از Android Release/AOT Preview برای تست عملکرد، به‌جای Debug.

## UI و امکانات

- فعال‌سازی مسیر Appearance و حفظ ۱۵ تم با ذخیره انتخاب.
- اصلاح مسیر Online Settings و منوهای آهنگ در Android.
- SafeArea نوار پایین، حذف آن در حین نمایش کیبورد.
- صفحه کامل Now Playing از طریق mini-player: seek/controls/queue/favorite.
- Splash با هویت VYBE؛ نشان بارگذاری تنها هنگام لود ضروری.
- مرورگر آنلاین چهار سایت مجاز و مدیریت دانلود مستقیم مانند نسخه 0.4.1 حفظ شده‌اند.

## بهبود صدای اندروید

- سطح داخلی player برابر ۱۰۰٪ (unity) در اندروید؛ ویندوز بدون تغییر در مقدار پیش‌فرض قبلی.
- Audio Focus، pause هنگام قطع هدفون و وقفه سیستم.
- Android MediaSession/notification/lock screen metadata + controls با `audio_service`.
- گزینه ReplayGain تگ‌محور با جلوگیری از clipping، خاموش به‌صورت پیش‌فرض.

## تست‌های موجود

- آزمون‌های Python شامل انطباق نسخه‌ها، UI/Performance contracts، XML/Kotlin bridge و Workflowها.
- بررسی ساختاری بلوک‌های Dart، YAML و صحت فایل‌های تصاویر و فشرده‌سازی ZIP.

**محدودیت:** Flutter SDK/Android SDK در محیط تهیه بسته نیست؛ `flutter analyze` و Build واقعی اندروید و ویندوز تا زمان اجرا روی GitHub یا سیستم دارای SDK تأیید نشده‌اند. در نتیجه FPS واقعی یا بهبود صوت اندازه‌گیری‌شده ادعا نمی‌شود.
