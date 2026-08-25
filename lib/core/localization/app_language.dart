enum AppLanguage {
  vi('vi', 'Tiếng Việt', '🇻🇳'),
  en('en', 'English', '🇬🇧');

  final String code;
  final String title;
  final String flag;

  const AppLanguage(this.code, this.title, this.flag);

  static AppLanguage fromCode(String? code) {
    if (code == 'en') return AppLanguage.en;
    return AppLanguage.vi;
  }
}
