import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleStorageKey = '__locale_key__';

class FFLocalizations {
  FFLocalizations(this.locale);

  final Locale locale;

  static FFLocalizations of(BuildContext context) =>
      Localizations.of<FFLocalizations>(context, FFLocalizations)!;

  static List<String> languages() => ['ru', 'kk', 'uz'];

  static late SharedPreferences _prefs;
  static Future initialize() async =>
      _prefs = await SharedPreferences.getInstance();
  static Future storeLocale(String locale) =>
      _prefs.setString(_kLocaleStorageKey, locale);
  static Locale? getStoredLocale() {
    final locale = _prefs.getString(_kLocaleStorageKey);
    return locale != null && locale.isNotEmpty ? createLocale(locale) : null;
  }

  String get languageCode => locale.toString();
  String? get languageShortCode =>
      _languagesWithShortCode.contains(locale.toString())
          ? '${locale.toString()}_short'
          : null;
  int get languageIndex => languages().contains(languageCode)
      ? languages().indexOf(languageCode)
      : 0;

  String getText(String key) =>
      (kTranslationsMap[key] ?? {})[locale.toString()] ?? '';

  String getVariableText({
    String? ruText = '',
    String? kkText = '',
    String? uzText = '',
  }) =>
      [ruText, kkText, uzText][languageIndex] ?? '';

  static const Set<String> _languagesWithShortCode = {
    'ar',
    'az',
    'ca',
    'cs',
    'da',
    'de',
    'dv',
    'en',
    'es',
    'et',
    'fi',
    'fr',
    'gr',
    'he',
    'hi',
    'hu',
    'it',
    'km',
    'ku',
    'mn',
    'ms',
    'no',
    'pt',
    'ro',
    'ru',
    'rw',
    'sv',
    'th',
    'uk',
    'vi',
  };
}

/// Used if the locale is not supported by GlobalMaterialLocalizations.
class FallbackMaterialLocalizationDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      SynchronousFuture<MaterialLocalizations>(
        const DefaultMaterialLocalizations(),
      );

  @override
  bool shouldReload(FallbackMaterialLocalizationDelegate old) => false;
}

/// Used if the locale is not supported by GlobalCupertinoLocalizations.
class FallbackCupertinoLocalizationDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
        const DefaultCupertinoLocalizations(),
      );

  @override
  bool shouldReload(FallbackCupertinoLocalizationDelegate old) => false;
}

class FFLocalizationsDelegate extends LocalizationsDelegate<FFLocalizations> {
  const FFLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<FFLocalizations> load(Locale locale) =>
      SynchronousFuture<FFLocalizations>(FFLocalizations(locale));

  @override
  bool shouldReload(FFLocalizationsDelegate old) => false;
}

Locale createLocale(String language) => language.contains('_')
    ? Locale.fromSubtags(
        languageCode: language.split('_').first,
        scriptCode: language.split('_').last,
      )
    : Locale(language);

bool _isSupportedLocale(Locale locale) {
  final language = locale.toString();
  return FFLocalizations.languages().contains(
    language.endsWith('_')
        ? language.substring(0, language.length - 1)
        : language,
  );
}

final kTranslationsMap = <Map<String, Map<String, String>>>[
  // home
  {
    'l7ffz7mf': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // Login
  {
    '5c0uhmth': {
      'ru': 'Добро пожаловать',
      'kk': '',
      'uz': '',
    },
    'm69w17go': {
      'ru': 'Войдите в аккаунт',
      'kk': '',
      'uz': '',
    },
    'b91momt2': {
      'ru': 'Номер телефона',
      'kk': '',
      'uz': '',
    },
    'dbx6n1gd': {
      'ru': 'Пароль',
      'kk': '',
      'uz': '',
    },
    'rvgqhe8k': {
      'ru': 'Войти',
      'kk': '',
      'uz': '',
    },
    'h91bvvf3': {
      'ru': 'Нету аккаунта? ',
      'kk': '',
      'uz': '',
    },
    'eoyp6qd1': {
      'ru': 'Создать аккаунт',
      'kk': '',
      'uz': '',
    },
    'm3z8yf7a': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // regPage
  {
    'atishnqh': {
      'ru': 'Добро пожаловать',
      'kk': '',
      'uz': '',
    },
    'kiwqvnc9': {
      'ru': 'Создайте аккаунт',
      'kk': '',
      'uz': '',
    },
    '1vlgmsq3': {
      'ru': 'Выберите роль',
      'kk': '',
      'uz': '',
    },
    '0z84ciu0': {
      'ru': 'Search...',
      'kk': '',
      'uz': '',
    },
    '02o5g2ck': {
      'ru': 'Владелец бизнеса',
      'kk': '',
      'uz': '',
    },
    'hsdl2yh6': {
      'ru': 'Сотрудник',
      'kk': '',
      'uz': '',
    },
    'w3ks1z7n': {
      'ru': 'Номер телефона',
      'kk': '',
      'uz': '',
    },
    '52jngx1b': {
      'ru': 'Пароль',
      'kk': '',
      'uz': '',
    },
    'roel40to': {
      'ru': 'Страна',
      'kk': '',
      'uz': '',
    },
    'o979jmg8': {
      'ru': 'Search...',
      'kk': '',
      'uz': '',
    },
    'visacvua': {
      'ru': 'Отрасль',
      'kk': '',
      'uz': '',
    },
    '0cxv4rho': {
      'ru': 'Search...',
      'kk': '',
      'uz': '',
    },
    'v0izdy53': {
      'ru': 'Тип бизнеса',
      'kk': '',
      'uz': '',
    },
    'r8ak391o': {
      'ru': 'Search...',
      'kk': '',
      'uz': '',
    },
    '0gtflmk3': {
      'ru': 'Налоговый режим',
      'kk': '',
      'uz': '',
    },
    '2iusru9x': {
      'ru': 'Search...',
      'kk': '',
      'uz': '',
    },
    'rdnfwefx': {
      'ru': 'Введение бухгалтерского учета',
      'kk': '',
      'uz': '',
    },
    'aipxx4wt': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'diaru9tk': {
      'ru': 'Далее',
      'kk': '',
      'uz': '',
    },
    'q4url6dh': {
      'ru': 'Номер телефона',
      'kk': '',
      'uz': '',
    },
    'v6lesc6j': {
      'ru': 'Индификатор компании',
      'kk': '',
      'uz': '',
    },
    'yscz3zly': {
      'ru': 'Пароль',
      'kk': '',
      'uz': '',
    },
    'ya2xwme6': {
      'ru': 'Должность',
      'kk': '',
      'uz': '',
    },
    'b0crdeun': {
      'ru': 'Search...',
      'kk': '',
      'uz': '',
    },
    '1z5za0uy': {
      'ru': 'Далее',
      'kk': '',
      'uz': '',
    },
    'gb3tybbs': {
      'ru': 'Уже есть аккаунт? ',
      'kk': '',
      'uz': '',
    },
    'l34i6gd5': {
      'ru': 'Войти',
      'kk': '',
      'uz': '',
    },
    'l3oxaic2': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // regPageDirector
  {
    'vstixhyh': {
      'ru': 'Загрузить логотип',
      'kk': '',
      'uz': '',
    },
    'p3a3v56a': {
      'ru': 'Наименование компании',
      'kk': '',
      'uz': '',
    },
    '99sbq5oc': {
      'ru': 'БИН',
      'kk': '',
      'uz': '',
    },
    'ba7wqp8m': {
      'ru': 'Юридический адрес',
      'kk': '',
      'uz': '',
    },
    'f7lldivs': {
      'ru': 'ФИО директора',
      'kk': '',
      'uz': '',
    },
    'pybbq2pj': {
      'ru': 'Выберите ОКЭДы',
      'kk': '',
      'uz': '',
    },
    'pziob21x': {
      'ru': 'Поиск',
      'kk': '',
      'uz': '',
    },
    '0mskmcum': {
      'ru': 'Плательщик НДС',
      'kk': '',
      'uz': '',
    },
    '0un5xcth': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    '6iwly1mb': {
      'ru': 'Далее',
      'kk': '',
      'uz': '',
    },
    'sva1mt7h': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // homeAdmin
  {
    'db6gl5y5': {
      'ru': 'Обзор',
      'kk': '',
      'uz': '',
    },
    '7euncc1p': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // companyAdmin
  {
    '3adu4af3': {
      'ru': 'Компании',
      'kk': '',
      'uz': '',
    },
    '6t0citun': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // usersAdmin
  {
    '6ii2zua9': {
      'ru': 'Пользователи',
      'kk': '',
      'uz': '',
    },
    'zbew6vxz': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // tarifAdmin
  {
    '8u6wd75j': {
      'ru': 'Тарифы',
      'kk': '',
      'uz': '',
    },
    'jrh56akl': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // bilingAdmin
  {
    'fgaa1ciy': {
      'ru': 'Оплата',
      'kk': '',
      'uz': '',
    },
    'vb70s4pl': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // analitikaAdmin
  {
    '7os497k9': {
      'ru': 'Аналитика',
      'kk': '',
      'uz': '',
    },
    '8xcn9fqo': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // supportAdmin
  {
    'boa1g06q': {
      'ru': 'Поддержка',
      'kk': '',
      'uz': '',
    },
    'myucji2r': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // marketingAdmin
  {
    'f1tjbn2j': {
      'ru': 'Маркетинг',
      'kk': '',
      'uz': '',
    },
    'kfcccihw': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // statPageAdmin
  {
    'zsjf9szq': {
      'ru': 'Статические данные',
      'kk': '',
      'uz': '',
    },
    't7i839jo': {
      'ru': 'Страны',
      'kk': '',
      'uz': '',
    },
    '7wzo7v9c': {
      'ru': 'Добавить страну',
      'kk': '',
      'uz': '',
    },
    'mfpiqwz6': {
      'ru': 'Поиск страны',
      'kk': '',
      'uz': '',
    },
    'q8cl6u0t': {
      'ru': 'Валюты',
      'kk': '',
      'uz': '',
    },
    'uox5w6o1': {
      'ru': 'Добавить валюту',
      'kk': '',
      'uz': '',
    },
    'mh2p1psz': {
      'ru': 'Поиск валюты',
      'kk': '',
      'uz': '',
    },
    'j0k2d54h': {
      'ru': 'Окэд',
      'kk': '',
      'uz': '',
    },
    'nud6bgtu': {
      'ru': 'Добавить ОКЭД',
      'kk': '',
      'uz': '',
    },
    'lpuutvbs': {
      'ru': 'Поиск ОКЭДов',
      'kk': '',
      'uz': '',
    },
    'r6f4n1ba': {
      'ru': 'Налоги',
      'kk': '',
      'uz': '',
    },
    'eot5wkpz': {
      'ru': 'Добавить налог',
      'kk': '',
      'uz': '',
    },
    'd0t45d76': {
      'ru': 'Поиск налогов',
      'kk': '',
      'uz': '',
    },
    'i28kilro': {
      'ru': 'Отрасли',
      'kk': '',
      'uz': '',
    },
    'zj3djpn5': {
      'ru': 'Добавить отрасль',
      'kk': '',
      'uz': '',
    },
    '2gvldksp': {
      'ru': 'Поиск отрасли',
      'kk': '',
      'uz': '',
    },
    'sks1t8sb': {
      'ru': 'Тип бизнеса',
      'kk': '',
      'uz': '',
    },
    'a46e0hu3': {
      'ru': 'Добавить форму введения бизнеса',
      'kk': '',
      'uz': '',
    },
    'e617dx9y': {
      'ru': 'Поиск формы введения бизнеса',
      'kk': '',
      'uz': '',
    },
    'hn7gv5he': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // secruritiAdmin
  {
    'xbobu53p': {
      'ru': 'Безопастность',
      'kk': '',
      'uz': '',
    },
    'dgb43uz5': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // settingAdmin
  {
    'cweybuge': {
      'ru': 'Настройки',
      'kk': '',
      'uz': '',
    },
    '8rf93az1': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // scheta
  {
    '04twn8uh': {
      'ru': 'Добавить счет ',
      'kk': '',
      'uz': '',
    },
    'i3pxn6w9': {
      'ru': 'Наличные',
      'kk': '',
      'uz': '',
    },
    'pwuhdecq': {
      'ru': 'Банковские счета',
      'kk': '',
      'uz': '',
    },
    't0c6pkcy': {
      'ru': 'Средства владельца',
      'kk': '',
      'uz': '',
    },
    'mthz6m53': {
      'ru': 'Баланс',
      'kk': '',
      'uz': '',
    },
    '58hpkz9s': {
      'ru': 'Добавить счет ',
      'kk': '',
      'uz': '',
    },
    '33sctllh': {
      'ru': 'Наличные',
      'kk': '',
      'uz': '',
    },
    '7en1uz3c': {
      'ru': 'Банковские счета',
      'kk': '',
      'uz': '',
    },
    'o9fty5wx': {
      'ru': 'Средства владельца',
      'kk': '',
      'uz': '',
    },
    '2ep1kw84': {
      'ru': 'Баланс',
      'kk': '',
      'uz': '',
    },
  },
  // uchet
  {
    'elhhzymi': {
      'ru': 'Разница',
      'kk': '',
      'uz': '',
    },
    '4k9ldt5z': {
      'ru': 'Сравнение учетов',
      'kk': '',
      'uz': '',
    },
    '3aj6264g': {
      'ru': 'Доходы',
      'kk': '',
      'uz': '',
    },
    'nftym07v': {
      'ru': 'Управленческий (С):',
      'kk': '',
      'uz': '',
    },
    '0osjs1tg': {
      'ru': 'Бухгалтерский:',
      'kk': '',
      'uz': '',
    },
    'kjgz01zv': {
      'ru': 'Разница:',
      'kk': '',
      'uz': '',
    },
    'z9lc3kmf': {
      'ru': 'Расходы',
      'kk': '',
      'uz': '',
    },
    'ntoi29p5': {
      'ru': 'Управленческий (С):',
      'kk': '',
      'uz': '',
    },
    'f0pbga3b': {
      'ru': 'Бухгалтерский:',
      'kk': '',
      'uz': '',
    },
    'fesdlr5e': {
      'ru': 'Разница:',
      'kk': '',
      'uz': '',
    },
    'c7coag5o': {
      'ru': 'Чистая прибыль',
      'kk': '',
      'uz': '',
    },
    'tly0uo9w': {
      'ru': 'Управленческий (С):',
      'kk': '',
      'uz': '',
    },
    'hptx4wke': {
      'ru': 'Бухгалтерский:',
      'kk': '',
      'uz': '',
    },
    '8qbussoz': {
      'ru': 'Разница:',
      'kk': '',
      'uz': '',
    },
    '6p9eptjz': {
      'ru': 'Баланс',
      'kk': '',
      'uz': '',
    },
    'v8wlkj80': {
      'ru': 'Управленческий (С):',
      'kk': '',
      'uz': '',
    },
    'bzs40j7y': {
      'ru': 'Бухгалтерский:',
      'kk': '',
      'uz': '',
    },
    '2fle2k22': {
      'ru': 'Разница:',
      'kk': '',
      'uz': '',
    },
    'wvypvhj9': {
      'ru': 'Управленческий учет (С)',
      'kk': '',
      'uz': '',
    },
    '87xp3kwh': {
      'ru': 'Основная статистика',
      'kk': '',
      'uz': '',
    },
    'rlckllnl': {
      'ru': 'Доходы',
      'kk': '',
      'uz': '',
    },
    'ear26k8h': {
      'ru': 'Расходы',
      'kk': '',
      'uz': '',
    },
    'fhjxgdgo': {
      'ru': 'Чистая прибыль',
      'kk': '',
      'uz': '',
    },
    'l5eo7zwo': {
      'ru': 'Баланс',
      'kk': '',
      'uz': '',
    },
    '4h49xsk0': {
      'ru': 'Налоги и платежи',
      'kk': '',
      'uz': '',
    },
    '4x3xbukq': {
      'ru': 'НДС начислено',
      'kk': '',
      'uz': '',
    },
    'n8mbfl1u': {
      'ru': 'НДС к уплате',
      'kk': '',
      'uz': '',
    },
    'l4ee373f': {
      'ru': 'Налог на доходы/прибыль начислено',
      'kk': '',
      'uz': '',
    },
    'c81zziys': {
      'ru': 'Налог на доходы/прибыль к уплате',
      'kk': '',
      'uz': '',
    },
    '07bcszpr': {
      'ru': 'Бухгалтерский учет',
      'kk': '',
      'uz': '',
    },
    '9drhdtr6': {
      'ru': 'Основная статистика',
      'kk': '',
      'uz': '',
    },
    'vwl8xzfk': {
      'ru': 'Доходы',
      'kk': '',
      'uz': '',
    },
    '51l8akqc': {
      'ru': 'Расходы',
      'kk': '',
      'uz': '',
    },
    '7p4jbi37': {
      'ru': 'Чистая прибыль',
      'kk': '',
      'uz': '',
    },
    'tpqq22nh': {
      'ru': 'Баланс',
      'kk': '',
      'uz': '',
    },
    'bxz51txm': {
      'ru': 'Налоги и платежи',
      'kk': '',
      'uz': '',
    },
    'c0g4bw2d': {
      'ru': 'НДС начислено',
      'kk': '',
      'uz': '',
    },
    'yo9pu2yh': {
      'ru': 'НДС к уплате',
      'kk': '',
      'uz': '',
    },
    'bs6cviqk': {
      'ru': 'Налог на доходы/прибыль начислено',
      'kk': '',
      'uz': '',
    },
    '9qryj0s1': {
      'ru': 'Налог на доходы/прибыль к уплате',
      'kk': '',
      'uz': '',
    },
    '53fusjly': {
      'ru': 'Разница',
      'kk': '',
      'uz': '',
    },
    '19iirv3s': {
      'ru': 'Доходы',
      'kk': '',
      'uz': '',
    },
    'jhktzara': {
      'ru': 'Управленческий (С):',
      'kk': '',
      'uz': '',
    },
    'z26i6w0p': {
      'ru': 'Бухгалтерский:',
      'kk': '',
      'uz': '',
    },
    'ijhcb1me': {
      'ru': 'Разница:',
      'kk': '',
      'uz': '',
    },
    'd67x4c72': {
      'ru': 'Расходы',
      'kk': '',
      'uz': '',
    },
    'wf3ksbw8': {
      'ru': 'Управленческий (С):',
      'kk': '',
      'uz': '',
    },
    'arbmdm0y': {
      'ru': 'Бухгалтерский:',
      'kk': '',
      'uz': '',
    },
    '410wphpr': {
      'ru': 'Разница:',
      'kk': '',
      'uz': '',
    },
    'zyaca18z': {
      'ru': 'Чистая прибыль',
      'kk': '',
      'uz': '',
    },
    '25z85c1b': {
      'ru': 'Управленческий (С):',
      'kk': '',
      'uz': '',
    },
    'ageecl93': {
      'ru': 'Бухгалтерский:',
      'kk': '',
      'uz': '',
    },
    '55izjwlz': {
      'ru': 'Разница:',
      'kk': '',
      'uz': '',
    },
    'qa5yso0o': {
      'ru': 'Баланс',
      'kk': '',
      'uz': '',
    },
    'pwktgntk': {
      'ru': 'Управленческий (С):',
      'kk': '',
      'uz': '',
    },
    'yp73pdch': {
      'ru': 'Бухгалтерский:',
      'kk': '',
      'uz': '',
    },
    'd0t5wr9t': {
      'ru': 'Разница:',
      'kk': '',
      'uz': '',
    },
    '5z2ugz71': {
      'ru': 'Управленческий учет (С)',
      'kk': '',
      'uz': '',
    },
    'vaef602a': {
      'ru': 'Доходы',
      'kk': '',
      'uz': '',
    },
    'b68qwjv4': {
      'ru': 'Расходы',
      'kk': '',
      'uz': '',
    },
    'a0dfx1ri': {
      'ru': 'Чистая прибыль',
      'kk': '',
      'uz': '',
    },
    '5446e493': {
      'ru': 'Баланс',
      'kk': '',
      'uz': '',
    },
    'yfki72mz': {
      'ru': 'НДС начислено',
      'kk': '',
      'uz': '',
    },
    'y9mm46xe': {
      'ru': 'НДС к уплате',
      'kk': '',
      'uz': '',
    },
    'dbdl61bv': {
      'ru': 'Налог на доходы/прибыль начислено',
      'kk': '',
      'uz': '',
    },
    'vity91nq': {
      'ru': 'Налог на доходы/прибыль к уплате',
      'kk': '',
      'uz': '',
    },
    'op5gkt23': {
      'ru': 'Бухгалтерский учет',
      'kk': '',
      'uz': '',
    },
    'xu3405un': {
      'ru': 'Доходы',
      'kk': '',
      'uz': '',
    },
    '49flbfj5': {
      'ru': 'Расходы',
      'kk': '',
      'uz': '',
    },
    'q03wkviz': {
      'ru': 'Чистая прибыль',
      'kk': '',
      'uz': '',
    },
    'rtdx7j5v': {
      'ru': 'Баланс',
      'kk': '',
      'uz': '',
    },
    'lxxq91yg': {
      'ru': 'НДС начислено',
      'kk': '',
      'uz': '',
    },
    'w8u9vkxu': {
      'ru': 'НДС к уплате',
      'kk': '',
      'uz': '',
    },
    'dxmlv1n4': {
      'ru': 'Налог на доходы/прибыль начислено',
      'kk': '',
      'uz': '',
    },
    'bvskumzs': {
      'ru': 'Налог на доходы/прибыль к уплате',
      'kk': '',
      'uz': '',
    },
    'r26twjd0': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // tranzaction
  {
    'ztsdaii4': {
      'ru': 'Период',
      'kk': '',
      'uz': '',
    },
    'aw483qkm': {
      'ru': 'Добавить',
      'kk': '',
      'uz': '',
    },
    'ujbkr6va': {
      'ru': 'Доходы',
      'kk': '',
      'uz': '',
    },
    '98rlz7w8': {
      'ru': 'Расходы',
      'kk': '',
      'uz': '',
    },
    '6dd6rpek': {
      'ru': 'Управленческий учет (С)',
      'kk': '',
      'uz': '',
    },
    'imoro50f': {
      'ru': 'Бухгалтерский учет',
      'kk': '',
      'uz': '',
    },
    't6ymmcg8': {
      'ru': 'Период',
      'kk': '',
      'uz': '',
    },
    'uuddor7f': {
      'ru': 'Добавить',
      'kk': '',
      'uz': '',
    },
    '6b1q1spq': {
      'ru': 'Доходы',
      'kk': '',
      'uz': '',
    },
    'k1wrbgee': {
      'ru': 'Расходы',
      'kk': '',
      'uz': '',
    },
    'ow9ec7g4': {
      'ru': 'Управленческий учет (С)',
      'kk': '',
      'uz': '',
    },
    '5hygyz90': {
      'ru': 'Бухгалтерский учет',
      'kk': '',
      'uz': '',
    },
    'zgzcgwc7': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // obyaz
  {
    'oduu9g3x': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // statRas
  {
    'ufk244vb': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // tovar
  {
    'wosic6q4': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // PortProduct
  {
    '4jf4n4tk': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // uslugi
  {
    '4lk3b4mc': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // kontrAgent
  {
    'vdg9dsmy': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // sclad
  {
    'm1824awf': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // controlsSale
  {
    'wtjjkiuu': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // shop
  {
    'uyncwxxa': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // client
  {
    'q5tijf66': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // controlsSales
  {
    '7s7n2j6f': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // incomeShop
  {
    'rpkoaw3i': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // decomeShop
  {
    'kplkra8o': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // pribilShop
  {
    'iz3vza9g': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // pribilKassir
  {
    'nayr4dmw': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // abcPageSale
  {
    'th4k06u6': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // finOtchet
  {
    'skyedil7': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // otchetSale
  {
    'x4fnzm3h': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // finModels
  {
    'fp7rh7kt': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // investOtchet
  {
    'yg8mlkfm': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // marja
  {
    'n0kcjawr': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // orgStructura
  {
    '0dzz10vk': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // hrControls
  {
    '6aoffbip': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // blocApps
  {
    '8kejyhq1': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // deleteData
  {
    '2icq47dy': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // recovery
  {
    'g62ywneq': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // myMoney
  {
    'ssltp6gv': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // myMoneyComp
  {
    'z92rohov': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // myDecome
  {
    'm5h93qf0': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // myDecomeComp
  {
    '3b5l09io': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // rekviziti
  {
    '20s8khb7': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // roli
  {
    'io4gz5bm': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // nalogi
  {
    '5yfu38yc': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // valuta
  {
    '6ig0ltc7': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // calculat
  {
    'rpdq3r6p': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // addPinCode
  {
    'sewih1cg': {
      'ru': 'Создайте пин код для входа',
      'kk': '',
      'uz': '',
    },
    '02ojuddz': {
      'ru': '1',
      'kk': '',
      'uz': '',
    },
    'smmdt67z': {
      'ru': '2',
      'kk': '',
      'uz': '',
    },
    'x7g5xons': {
      'ru': '3',
      'kk': '',
      'uz': '',
    },
    'hmvbuxwv': {
      'ru': '4',
      'kk': '',
      'uz': '',
    },
    'rofnpkkj': {
      'ru': '5',
      'kk': '',
      'uz': '',
    },
    'mwhpb1g0': {
      'ru': '6',
      'kk': '',
      'uz': '',
    },
    'gmccnkmo': {
      'ru': '7',
      'kk': '',
      'uz': '',
    },
    'm81fx7w8': {
      'ru': '8',
      'kk': '',
      'uz': '',
    },
    'ijf8qmrg': {
      'ru': '9',
      'kk': '',
      'uz': '',
    },
    'sjivv3rs': {
      'ru': '0',
      'kk': '',
      'uz': '',
    },
    'e2110zim': {
      'ru': 'Home',
      'kk': '',
      'uz': '',
    },
  },
  // drawers
  {
    'mltonid9': {
      'ru': 'Панель управления',
      'kk': '',
      'uz': '',
    },
    '660l0fej': {
      'ru': 'Панель управления',
      'kk': '',
      'uz': '',
    },
    '2v600ixn': {
      'ru': 'Компании',
      'kk': '',
      'uz': '',
    },
    'sieu1p3c': {
      'ru': 'Пользователи',
      'kk': '',
      'uz': '',
    },
    'swspp6ow': {
      'ru': 'Тарифы',
      'kk': '',
      'uz': '',
    },
    'ih10cid9': {
      'ru': 'Оплата',
      'kk': '',
      'uz': '',
    },
    'zuzznfk5': {
      'ru': 'Аналитика',
      'kk': '',
      'uz': '',
    },
    'rrqyg7qs': {
      'ru': 'Поддержка',
      'kk': '',
      'uz': '',
    },
    'h9rypr3a': {
      'ru': 'Маркетинг',
      'kk': '',
      'uz': '',
    },
    'bktn81eb': {
      'ru': 'Статические данные',
      'kk': '',
      'uz': '',
    },
    '88alq2r6': {
      'ru': 'Безопасность',
      'kk': '',
      'uz': '',
    },
    'e3squbha': {
      'ru': 'Настройки',
      'kk': '',
      'uz': '',
    },
    'v9eu1q74': {
      'ru': 'Выход',
      'kk': '',
      'uz': '',
    },
  },
  // addValuta
  {
    'rel232s7': {
      'ru': 'Добавить валюту',
      'kk': '',
      'uz': '',
    },
    'nawhgvro': {
      'ru': 'Название',
      'kk': '',
      'uz': '',
    },
    'hvhvvmp8': {
      'ru': 'Код',
      'kk': '',
      'uz': '',
    },
    'bxgb60mc': {
      'ru': 'Символ',
      'kk': '',
      'uz': '',
    },
    'ub40ph3t': {
      'ru': 'Добавить',
      'kk': '',
      'uz': '',
    },
  },
  // addCountry
  {
    'rtiipzq3': {
      'ru': 'Добавить страну',
      'kk': '',
      'uz': '',
    },
    '8cqopdt9': {
      'ru': 'Название',
      'kk': '',
      'uz': '',
    },
    'qslogvzm': {
      'ru': 'Код',
      'kk': '',
      'uz': '',
    },
    'cdgckp49': {
      'ru': 'Валюта',
      'kk': '',
      'uz': '',
    },
    'djqx0pqr': {
      'ru': 'Добавить',
      'kk': '',
      'uz': '',
    },
  },
  // addOced
  {
    'u74p7z7y': {
      'ru': 'Добавить ОКЭД',
      'kk': '',
      'uz': '',
    },
    'etr2xnom': {
      'ru': 'Название',
      'kk': '',
      'uz': '',
    },
    '2536hjhf': {
      'ru': 'Код',
      'kk': '',
      'uz': '',
    },
    '2ybw6nqq': {
      'ru': 'Секция',
      'kk': '',
      'uz': '',
    },
    'fn79u29z': {
      'ru': 'Страна',
      'kk': '',
      'uz': '',
    },
    '272ijiur': {
      'ru': 'Добавить',
      'kk': '',
      'uz': '',
    },
  },
  // addNalog
  {
    't2uqgqz1': {
      'ru': 'Добавить режим налогообложения',
      'kk': '',
      'uz': '',
    },
    'wfm2yf3s': {
      'ru': 'Название',
      'kk': '',
      'uz': '',
    },
    '1ce1ypjm': {
      'ru': 'Обозначения',
      'kk': '',
      'uz': '',
    },
    'lfgljgyw': {
      'ru': 'Проценты',
      'kk': '',
      'uz': '',
    },
    'zgwsr9ox': {
      'ru': 'Страна',
      'kk': '',
      'uz': '',
    },
    '31eva9b8': {
      'ru': 'Добавить',
      'kk': '',
      'uz': '',
    },
  },
  // addOtrasl
  {
    '4dahktsi': {
      'ru': 'Добавить отрасль',
      'kk': '',
      'uz': '',
    },
    '0jipn35n': {
      'ru': 'Название',
      'kk': '',
      'uz': '',
    },
    '7fmzoc1c': {
      'ru': 'Выберите страну',
      'kk': '',
      'uz': '',
    },
    'p0fcg8bt': {
      'ru': 'Поиск',
      'kk': '',
      'uz': '',
    },
    'b0t7arlu': {
      'ru': 'Выберите ОКЭДы',
      'kk': '',
      'uz': '',
    },
    'a0rcpumv': {
      'ru': 'Выберите ОКЭДы',
      'kk': '',
      'uz': '',
    },
    'vrkgfexs': {
      'ru': 'Поиск',
      'kk': '',
      'uz': '',
    },
    '13otcgjj': {
      'ru': 'Добавить',
      'kk': '',
      'uz': '',
    },
  },
  // addTip
  {
    'dfd4ah0g': {
      'ru': 'Добавить форму введения бизнеса',
      'kk': '',
      'uz': '',
    },
    'dr3q1gn7': {
      'ru': 'Название',
      'kk': '',
      'uz': '',
    },
    'clzvz3up': {
      'ru': 'Выберите страну',
      'kk': '',
      'uz': '',
    },
    '086a8mab': {
      'ru': 'Поиск',
      'kk': '',
      'uz': '',
    },
    '6ht5c689': {
      'ru': 'Добавить',
      'kk': '',
      'uz': '',
    },
  },
  // drawersUsers
  {
    'win9ju05': {
      'ru': 'Деньги компании',
      'kk': '',
      'uz': '',
    },
    'col4smk0': {
      'ru': 'Счета',
      'kk': '',
      'uz': '',
    },
    'e49lht85': {
      'ru': 'Финансовый учет компании',
      'kk': '',
      'uz': '',
    },
    'xq19vlv6': {
      'ru': 'Платежи',
      'kk': '',
      'uz': '',
    },
    'e74ljg33': {
      'ru': 'Обязательства',
      'kk': '',
      'uz': '',
    },
    '2hdymksq': {
      'ru': 'Бюджет',
      'kk': '',
      'uz': '',
    },
    'd81sslj1': {
      'ru': 'Товары',
      'kk': '',
      'uz': '',
    },
    'eqoq34ua': {
      'ru': 'Товары',
      'kk': '',
      'uz': '',
    },
    '5np2lb2d': {
      'ru': 'Портфель продуктов',
      'kk': '',
      'uz': '',
    },
    'urs2evgn': {
      'ru': 'Услуги',
      'kk': '',
      'uz': '',
    },
    'lw5c81d0': {
      'ru': 'Контрагенты',
      'kk': '',
      'uz': '',
    },
    'n68sqxcn': {
      'ru': 'Склады',
      'kk': '',
      'uz': '',
    },
    '53srmciz': {
      'ru': 'Управление скидками',
      'kk': '',
      'uz': '',
    },
    'up5h54fb': {
      'ru': 'Продажи',
      'kk': '',
      'uz': '',
    },
    'zliveeb8': {
      'ru': 'Магазины',
      'kk': '',
      'uz': '',
    },
    '2xtr8k22': {
      'ru': 'Клиенты',
      'kk': '',
      'uz': '',
    },
    '7rkhisgl': {
      'ru': 'Управление скидками',
      'kk': '',
      'uz': '',
    },
    'u65lwzuz': {
      'ru': 'Доходы магазинов',
      'kk': '',
      'uz': '',
    },
    'jwrsbzyt': {
      'ru': 'Расходы магазинов',
      'kk': '',
      'uz': '',
    },
    'vdzh89qi': {
      'ru': 'Чистая прибыль',
      'kk': '',
      'uz': '',
    },
    'a10yhdor': {
      'ru': 'Прибыль по кассирам',
      'kk': '',
      'uz': '',
    },
    '003diwf3': {
      'ru': 'Заявки на закуп товаров',
      'kk': '',
      'uz': '',
    },
    'uub8snhv': {
      'ru': 'Аналитика',
      'kk': '',
      'uz': '',
    },
    'm8t7x50z': {
      'ru': 'Фин отчеты',
      'kk': '',
      'uz': '',
    },
    'hvoo7blc': {
      'ru': 'Отчеты про продажам',
      'kk': '',
      'uz': '',
    },
    'gaej7bmt': {
      'ru': 'Финансовая модель',
      'kk': '',
      'uz': '',
    },
    'qh40yqcp': {
      'ru': 'Инвестиционные отчеты',
      'kk': '',
      'uz': '',
    },
    '56yajhft': {
      'ru': 'Маржинальность',
      'kk': '',
      'uz': '',
    },
    'rd83xark': {
      'ru': 'Компания',
      'kk': '',
      'uz': '',
    },
    'tumlh7nq': {
      'ru': 'Структура бизнеса',
      'kk': '',
      'uz': '',
    },
    'wtqoktpl': {
      'ru': 'Штатная структура и расчет мотивации / HR',
      'kk': '',
      'uz': '',
    },
    'kipkxeux': {
      'ru': 'Безопасность',
      'kk': '',
      'uz': '',
    },
    'lw7rutdf': {
      'ru': 'Блокировка приложения',
      'kk': '',
      'uz': '',
    },
    'vaoc4lkd': {
      'ru': 'Очистка данных',
      'kk': '',
      'uz': '',
    },
    'c0t1m2o0': {
      'ru': 'Восстановление данных',
      'kk': '',
      'uz': '',
    },
    '0adhv4vh': {
      'ru': 'Личные деньги',
      'kk': '',
      'uz': '',
    },
    'mjr1qv7d': {
      'ru': 'Доходы личные',
      'kk': '',
      'uz': '',
    },
    'b0oq4wd8': {
      'ru': 'Доходы компании',
      'kk': '',
      'uz': '',
    },
    'skrptuka': {
      'ru': 'Расходы личные',
      'kk': '',
      'uz': '',
    },
    '66juhpbh': {
      'ru': 'Рахсоды на компанию',
      'kk': '',
      'uz': '',
    },
    'ytgmbu9a': {
      'ru': 'Настройки',
      'kk': '',
      'uz': '',
    },
    '7lxep4bw': {
      'ru': 'Реквизиты',
      'kk': '',
      'uz': '',
    },
    'lqpoh5ah': {
      'ru': 'Валюта',
      'kk': '',
      'uz': '',
    },
    '9u77chkx': {
      'ru': 'Налоги',
      'kk': '',
      'uz': '',
    },
    'l3nnwzu8': {
      'ru': 'Калькулятор',
      'kk': '',
      'uz': '',
    },
    '1ugg0mir': {
      'ru': 'Роли',
      'kk': '',
      'uz': '',
    },
    'uyv5m01n': {
      'ru': 'Выйти',
      'kk': '',
      'uz': '',
    },
  },
  // addSchet
  {
    'qavjdeil': {
      'ru': 'Добавить счет',
      'kk': '',
      'uz': '',
    },
    'cl8n8xrn': {
      'ru': 'Тип счета',
      'kk': '',
      'uz': '',
    },
    '2jrsefte': {
      'ru': 'Выберите тип счета',
      'kk': '',
      'uz': '',
    },
    '5ffpmq8i': {
      'ru': 'Search...',
      'kk': '',
      'uz': '',
    },
    'z7x305g0': {
      'ru': 'Наличные',
      'kk': '',
      'uz': '',
    },
    'v96f53v3': {
      'ru': 'Банковский счет ',
      'kk': '',
      'uz': '',
    },
    'yhcdqd4m': {
      'ru': 'Средства владельца',
      'kk': '',
      'uz': '',
    },
    'scskm4mi': {
      'ru': 'Название',
      'kk': '',
      'uz': '',
    },
    '2r7mnp19': {
      'ru': 'Например: Главная касса',
      'kk': '',
      'uz': '',
    },
    'e1ujx0jx': {
      'ru': 'Баланс',
      'kk': '',
      'uz': '',
    },
    '57s982ob': {
      'ru': '0',
      'kk': '',
      'uz': '',
    },
    '3m8k7l0g': {
      'ru': 'Заметки',
      'kk': '',
      'uz': '',
    },
    'jfvtu0wl': {
      'ru': 'Дополнительная информация...',
      'kk': '',
      'uz': '',
    },
    '1uwd4lba': {
      'ru': 'Отменить',
      'kk': '',
      'uz': '',
    },
    'j4omfp7e': {
      'ru': 'Добавить',
      'kk': '',
      'uz': '',
    },
  },
  // editSchet
  {
    'ua7yq78h': {
      'ru': 'Редактировать счет',
      'kk': '',
      'uz': '',
    },
    'sggqa047': {
      'ru': 'Тип счета',
      'kk': '',
      'uz': '',
    },
    'qfeipzj9': {
      'ru': 'Выберите тип счета',
      'kk': '',
      'uz': '',
    },
    '4kwb3zhf': {
      'ru': 'Search...',
      'kk': '',
      'uz': '',
    },
    'qlpvs4wf': {
      'ru': 'Наличные',
      'kk': '',
      'uz': '',
    },
    'uuki7xgw': {
      'ru': 'Банковский счет ',
      'kk': '',
      'uz': '',
    },
    'pmed91k0': {
      'ru': 'Средства владельца',
      'kk': '',
      'uz': '',
    },
    'jfksiy9w': {
      'ru': 'Название',
      'kk': '',
      'uz': '',
    },
    'hfede2ri': {
      'ru': 'Например: Главная касса',
      'kk': '',
      'uz': '',
    },
    'e8io4r0q': {
      'ru': 'Баланс',
      'kk': '',
      'uz': '',
    },
    '52pfogfa': {
      'ru': '0',
      'kk': '',
      'uz': '',
    },
    '7qedvveo': {
      'ru': 'Заметки',
      'kk': '',
      'uz': '',
    },
    'utq58n6m': {
      'ru': 'Дополнительная информация...',
      'kk': '',
      'uz': '',
    },
    '1jo0ut2d': {
      'ru': 'Отменить',
      'kk': '',
      'uz': '',
    },
    'p2vfid4v': {
      'ru': 'Сохранить',
      'kk': '',
      'uz': '',
    },
  },
  // addTranzaction
  {
    '77lnzp31': {
      'ru':
          'Добавить транзакцию                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             ',
      'kk': '',
      'uz': '',
    },
    'eb00dn5t': {
      'ru': 'Тип операции',
      'kk': '',
      'uz': '',
    },
    'wdu26cak': {
      'ru': 'Выберите тип счета',
      'kk': '',
      'uz': '',
    },
    'ovjlunbt': {
      'ru': 'Search...',
      'kk': '',
      'uz': '',
    },
    'w63qyytc': {
      'ru': 'Доход',
      'kk': '',
      'uz': '',
    },
    'lfbc8wi1': {
      'ru': 'Расход',
      'kk': '',
      'uz': '',
    },
    '77dxo9vd': {
      'ru': 'Тип учета',
      'kk': '',
      'uz': '',
    },
    'y63itftx': {
      'ru': 'Выберите тип счета',
      'kk': '',
      'uz': '',
    },
    'czc0nkab': {
      'ru': 'Search...',
      'kk': '',
      'uz': '',
    },
    'o9jq56ot': {
      'ru': 'Управленческий (С)',
      'kk': '',
      'uz': '',
    },
    's1hlso2f': {
      'ru': 'Бухгалтерский',
      'kk': '',
      'uz': '',
    },
    'y2mro0qu': {
      'ru': 'Категория',
      'kk': '',
      'uz': '',
    },
    '76s8a5vt': {
      'ru': 'Выберите тип счета',
      'kk': '',
      'uz': '',
    },
    'si5raevf': {
      'ru': 'Search...',
      'kk': '',
      'uz': '',
    },
    '5dpig5ai': {
      'ru': 'Доход',
      'kk': '',
      'uz': '',
    },
    'awwbmthz': {
      'ru': 'Расход',
      'kk': '',
      'uz': '',
    },
    'ul0hf1lx': {
      'ru': 'Название',
      'kk': '',
      'uz': '',
    },
    'jw0ui9eq': {
      'ru': 'Например: Продажа товаров',
      'kk': '',
      'uz': '',
    },
    'wcf4lur0': {
      'ru': 'Сумма',
      'kk': '',
      'uz': '',
    },
    'v5x0x8gn': {
      'ru': '0',
      'kk': '',
      'uz': '',
    },
    'wu5d35gm': {
      'ru': 'С НДС',
      'kk': '',
      'uz': '',
    },
    'qvssdn8k': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    '5rptk4x3': {
      'ru': 'Сумма НДС',
      'kk': '',
      'uz': '',
    },
    'rlwv10p8': {
      'ru': '0',
      'kk': '',
      'uz': '',
    },
    '0jzyzltf': {
      'ru': 'Отменить',
      'kk': '',
      'uz': '',
    },
    'c66vbz61': {
      'ru': 'Добавить',
      'kk': '',
      'uz': '',
    },
  },
  // Miscellaneous
  {
    '366rfuua': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'h6aabn85': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'prqoo6an': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'gu4afg2q': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'rj23d3j8': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'erdm0f4w': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    '7v7emers': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'fs3d1w3e': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'ghdmyngq': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'wk713lbn': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'z21qax6c': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    '6nkbweda': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    '15aqzcqj': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'n3nfvbv9': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'udhcuvnz': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'uqbphiw7': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'd20k5d8o': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    '38dgdqmm': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'shmrtnzz': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'kxdpbmi7': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'dr5e67mv': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'fjc8z2bc': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    '51r20k3b': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    '2m5zdtw9': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    '70dd21ft': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'bhdd7g5v': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
    'wc23gxvb': {
      'ru': '',
      'kk': '',
      'uz': '',
    },
  },
].reduce((a, b) => a..addAll(b));
