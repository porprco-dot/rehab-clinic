/// Interface labels (buttons, tab names, status lines).
///
/// Legal texts, amounts and notes are NOT here: they come from the server
/// file (`texts` and item fields) so they can change without an app update.
class AppStrings {
  static const appTitle = 'حقوق درمان';

  // Tabs
  static const tabHome = 'خانه';
  static const tabCases = 'پرونده‌های من';
  static const tabCalculator = 'ماشین‌حساب';
  static const tabAccount = 'حساب من';
  static const comingSoon = 'این بخش به‌زودی اضافه می‌شود.';

  // Calculator
  static const calculatorTitle = 'ماشین‌حساب دیه';
  static const helpTooltip = 'راهنما';
  static const ok = 'متوجه شدم';
  static const addInjury = 'افزودن آسیب';
  static const chooseInjury = 'انتخاب آسیب';
  static const emptyHint = 'برای شروع، آسیب را از فهرست انتخاب کنید.';
  static const remove = 'حذف';
  static const increase = 'بیشتر';
  static const decrease = 'کمتر';
  static const total = 'جمع دیه';
  static const fullDiyeh = 'دیه کامل';
  static const rateYear = 'نرخ سال';
  static const updatedAt = 'به‌روزرسانی';
  static const originNetwork = 'به‌روز از سرور';
  static const originCache = 'آخرین نرخ ذخیره‌شده';
  static const originBundled = 'نرخ پیش‌فرض داخل اپ';
  static const haramIncluded = 'شامل سهم اضافه‌ی ماه حرام';
  static const noPaymentSchedule = 'نمایش نده';
  static const loadError = 'خواندن نرخ دیه ممکن نشد. لطفاً اپ را دوباره باز کنید.';
  static const sourceOpenError = 'باز کردن منبع ممکن نشد.';
  static const percentSign = '٪';
}
