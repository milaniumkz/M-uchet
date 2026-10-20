const String kModuleMoney = 'money';
const String kModuleGoods = 'goods';
const String kModuleSales = 'sales';
const String kModuleAnalytics = 'analytics';
const String kModuleCompany = 'company';
const String kModuleSecurity = 'security';
const String kModulePersonal = 'personal';
const String kModuleSettings = 'settings';

const List<String> kCompanyModuleKeys = [
  kModuleMoney,
  kModuleGoods,
  kModuleSales,
  kModuleAnalytics,
  kModuleCompany,
  kModuleSecurity,
  kModulePersonal,
  kModuleSettings,
];

const Map<String, String> kCompanyModuleLabels = {
  kModuleMoney: 'Деньги',
  kModuleGoods: 'Товары / склады',
  kModuleSales: 'Продажи',
  kModuleAnalytics: 'Аналитика',
  kModuleCompany: 'Компания / HR',
  kModuleSecurity: 'Безопасность',
  kModulePersonal: 'Личные деньги',
  kModuleSettings: 'Настройки',
};

const Map<String, List<String>> kBusinessTypeModulePresets = {
  'real_estate': [
    kModuleMoney,
    kModuleSales,
    kModuleCompany,
    kModuleSecurity,
    kModuleSettings,
  ],
  'trade': [
    kModuleMoney,
    kModuleGoods,
    kModuleSales,
    kModuleCompany,
    kModuleSecurity,
    kModuleSettings,
  ],
  'agriculture': [
    kModuleMoney,
    kModuleGoods,
    kModuleCompany,
    kModuleSecurity,
    kModuleSettings,
  ],
  'services': [
    kModuleMoney,
    kModuleSales,
    kModuleCompany,
    kModuleSecurity,
    kModuleSettings,
  ],
  'construction': [
    kModuleMoney,
    kModuleGoods,
    kModuleSales,
    kModuleCompany,
    kModuleSecurity,
    kModuleSettings,
  ],
};

const Map<String, String> kBusinessTypeLabels = {
  'real_estate': 'Недвижимость',
  'trade': 'Торговля / товары',
  'agriculture': 'Сельхоз / продукты',
  'services': 'Услуги',
  'construction': 'Строительство',
};

Map<String, bool> normalizeCompanyModules(dynamic raw) {
  final result = {for (final key in kCompanyModuleKeys) key: true};
  if (raw is Map) {
    for (final key in kCompanyModuleKeys) {
      if (raw.containsKey(key)) result[key] = raw[key] == true;
    }
  }
  return result;
}

Map<String, bool> modulesForBusinessType(String? businessType) {
  final enabled =
      kBusinessTypeModulePresets[businessType] ?? kCompanyModuleKeys;
  return {for (final key in kCompanyModuleKeys) key: enabled.contains(key)};
}
