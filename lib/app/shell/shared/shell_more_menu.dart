part of '../app_shell.dart';

const String _legacyProjectPathMarkerV1 = 'LIFEOS_PATH::V1';
const String _retiredProjectPathMarkerV1 = 'LIFEOS_PATH::V1_RETIRED';
const String _activeProjectPathMarkerV2 = 'LIFEOS_PATH::V2';
const String _retiredProjectPathMarkerV2 = 'LIFEOS_PATH::V2_RETIRED';
const String _kadrRealityV3Prefix = 'kadr-v3-';

/// Old Path rows are preserved as inert backups. Nothing is deleted during
/// automatic upgrades.
Future<void> _retireLegacyProjectPathsV1() async {
  final db = DatabaseService.instance;
  final tasks = await db.fetchBacklogPlans(includeCompleted: true);
  for (final task in tasks) {
    if ((task.notesPlain ?? '').trim() != _legacyProjectPathMarkerV1) continue;
    final ok = await db.updatePlanningTask(
      task.planRowIdForBackend,
      planBusinessId: task.planRowId,
      title: task.title,
      categoryId: task.categoryId,
      isDone: true,
      notesPlain: _retiredProjectPathMarkerV1,
      checklist: task.checklist,
      suppressAppSnack: true,
    );
    if (!ok) {
      throw StateError('Could not retire legacy Path for category ${task.categoryId}');
    }
  }
}

String _v3NormalizeProjectName(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '');

CategoryRule? _v3FindKadrCategory() {
  final db = DatabaseService.instance;
  for (final pair in db.allCategoryIdPathPairs) {
    final rule = db.getCategoryRuleById(pair.id);
    if (rule == null || rule.isArchived) continue;
    final name = _v3NormalizeProjectName(rule.name);
    if (name == 'кадр' || name == 'kadr') return rule;
  }
  return null;
}

bool _v3ChecklistIsKadrReality(List<Map<String, dynamic>> checklist) {
  if (checklist.isEmpty) return false;
  return checklist.any(
    (row) => (row['id'] ?? '').toString().startsWith(_kadrRealityV3Prefix),
  );
}

Map<String, dynamic> _v3Action(
  String id,
  String text,
  String result,
  int minutes,
  String track,
) => <String, dynamic>{
  'id': '$_kadrRealityV3Prefix$id',
  'text': text,
  'result': result,
  'minutes': minutes,
  'track': track,
  'isDone': false,
};

Map<String, dynamic> _v3Stage(
  int number,
  String title,
  String doneWhen,
  List<Map<String, dynamic>> actions,
) => <String, dynamic>{
  'type': 'stage',
  'id': '$_kadrRealityV3Prefix${number.toString().padLeft(2, '0')}',
  'text': title,
  'definitionOfDone': doneWhen,
  'isDone': false,
  'actions': actions,
};

List<Map<String, dynamic>> _v3KadrChecklist() => <Map<String, dynamic>>[
  _v3Stage(
    1,
    'Определить, что именно продаёт КАДР',
    'На одной странице записано: для кого КАДР, что остаётся бесплатным, за какую конкретную ценность платят, что входит в платную версию и как мы сначала проверяем цену.',
    [
      _v3Action(
        '01-01',
        'Записать три реальных сценария, в которых человек сегодня делает скриншот и чем пользуется вместо КАДР',
        'Три сценария с текущим способом решения задачи',
        20,
        'offer',
      ),
      _v3Action(
        '01-02',
        'Выписать все уже работающие функции КАДР без будущих идей',
        'Фактический список функций текущей сборки',
        20,
        'product',
      ),
      _v3Action(
        '01-03',
        'Отметить функции, которые должны навсегда остаться бесплатными, чтобы бесплатная версия была полноценной',
        'Черновой состав бесплатной версии',
        20,
        'offer',
      ),
      _v3Action(
        '01-04',
        'Выписать три причины, за которые пользователь мог бы заплатить: не функции, а экономия времени или новый сценарий',
        'Три проверяемые гипотезы платной ценности',
        25,
        'offer',
      ),
      _v3Action(
        '01-05',
        'Выбрать один первый состав платной версии максимум из трёх преимуществ',
        'Один конкретный состав платной версии для проверки',
        20,
        'offer',
      ),
      _v3Action(
        '01-06',
        'Решить, что проверяем первым: разовую покупку, подписку или оба варианта',
        'Записанная модель первой оплаты с причиной выбора',
        15,
        'payments',
      ),
      _v3Action(
        '01-07',
        'Назначить одну стартовую цену или узкий диапазон цен для первого теста',
        'Цена, которую реально можно показать первым пользователям',
        15,
        'payments',
      ),
      _v3Action(
        '01-08',
        'Сформулировать одним предложением, почему человек должен перейти с бесплатного решения на платный КАДР',
        'Одно понятное объяснение платной ценности без рекламных общих слов',
        15,
        'demand',
      ),
    ],
  ),
  _v3Stage(
    2,
    'Зафиксировать готовность текущей Windows-версии',
    'Основной сценарий «запустить → выделить область → отредактировать → скопировать или сохранить» стабилен, а все известные проблемы разнесены на блокирующие и неблокирующие.',
    [
      _v3Action(
        '02-01',
        'Проверить выделение области на одном мониторе и записать все отклонения',
        'Результат проверки выделения области',
        15,
        'product',
      ),
      _v3Action(
        '02-02',
        'Проверить выделение области через границу двух мониторов',
        'Результат проверки многомониторного сценария',
        15,
        'product',
      ),
      _v3Action(
        '02-03',
        'Проверить Copy, Save и повторное открытие сохранённого файла',
        'Три фактических результата проверки',
        15,
        'product',
      ),
      _v3Action(
        '02-04',
        'Проверить основные инструменты редактора на одном скриншоте',
        'Список сломанных или неудобных инструментов',
        30,
        'product',
      ),
      _v3Action(
        '02-05',
        'Записать короткое видео и проверить его появление в истории',
        'Результат проверки видео и истории',
        15,
        'product',
      ),
      _v3Action(
        '02-06',
        'Перезапустить КАДР и проверить глобальную горячую клавишу',
        'Результат проверки горячей клавиши после перезапуска',
        10,
        'product',
      ),
      _v3Action(
        '02-07',
        'Разнести найденные проблемы на «мешает выпуску», «важно после выпуска» и «можно позже»',
        'Приоритетный список проблем без смешивания с идеями',
        20,
        'release',
      ),
    ],
  ),
  _v3Stage(
    3,
    'Сделать установку и обновление понятными постороннему человеку',
    'На чистом Windows-компьютере человек без моей помощи скачивает КАДР, устанавливает, запускает, обновляет и удаляет его; предупреждения и подпись приложения понятны.',
    [
      _v3Action(
        '03-01',
        'Записать полный путь от скачивания установщика до первого скриншота',
        'Пошаговый сценарий установки без пропущенных экранов',
        20,
        'windows_distribution',
      ),
      _v3Action(
        '03-02',
        'Проверить установщик в чистой Windows-среде и записать каждое предупреждение',
        'Список предупреждений и точек отказа установки',
        30,
        'windows_distribution',
      ),
      _v3Action(
        '03-03',
        'Проверить, есть ли сейчас механизм обновления, и записать его фактическое поведение',
        'Описание текущего обновления или подтверждение, что его нет',
        20,
        'release',
      ),
      _v3Action(
        '03-04',
        'Проверить требования к цифровой подписи для выбранного способа распространения Windows-версии',
        'Список конкретных требований к подписи и сертификату',
        30,
        'windows_distribution',
      ),
      _v3Action(
        '03-05',
        'Определить следующий шаг для получения нужного сертификата подписи',
        'Один конкретный следующий шаг: регистрация, покупка или подготовка данных',
        15,
        'windows_distribution',
      ),
      _v3Action(
        '03-06',
        'Проверить удаление КАДР и записать, какие файлы или настройки остаются',
        'Результат проверки удаления приложения',
        15,
        'release',
      ),
    ],
  ),
  _v3Stage(
    4,
    'Сделать сайт КАДР',
    'Есть рабочий домен и сайт, где человек за минуту понимает КАДР, видит бесплатную и платную версии, скачивает приложение, покупает его, находит документы и способ обратиться за помощью.',
    [
      _v3Action(
        '04-01',
        'Составить пять вариантов домена для КАДР и проверить их доступность',
        'Список доступных вариантов домена',
        20,
        'website',
      ),
      _v3Action(
        '04-02',
        'Выбрать один домен и зафиксировать, где он будет зарегистрирован',
        'Выбранный домен и регистратор',
        15,
        'website',
      ),
      _v3Action(
        '04-03',
        'Записать структуру сайта: главная, скачать, цены, вопросы, документы, поддержка',
        'Карта страниц сайта',
        20,
        'website',
      ),
      _v3Action(
        '04-04',
        'Написать первый экран сайта: что делает КАДР, для кого и одна главная кнопка',
        'Готовый текст первого экрана',
        20,
        'website',
      ),
      _v3Action(
        '04-05',
        'Подготовить блок сравнения бесплатной и платной версии без скрытых ограничений',
        'Понятная таблица бесплатной и платной версии',
        25,
        'offer',
      ),
      _v3Action(
        '04-06',
        'Выбрать три скриншота приложения, которые объясняют продукт без текста',
        'Три изображения для сайта',
        15,
        'website',
      ),
      _v3Action(
        '04-07',
        'Добавить на сайт ссылки на скачивание, покупку, документы и поддержку',
        'Полный набор рабочих пользовательских ссылок',
        25,
        'website',
      ),
      _v3Action(
        '04-08',
        'Открыть опубликованный сайт в чистом браузере и пройти путь до скачивания',
        'Результат проверки сайта как новый пользователь',
        15,
        'website',
      ),
    ],
  ),
  _v3Stage(
    5,
    'Настроить оплату, лицензию и обязательные документы',
    'Понятно, кто продаёт КАДР, как принимаются деньги и налоги, что получает покупатель, как восстанавливается доступ и делается возврат; тестовая покупка проходит от начала до конца.',
    [
      _v3Action(
        '05-01',
        'Записать, кто юридически будет продавцом КАДР и из какой страны',
        'Однозначно определён продавец',
        15,
        'legal',
      ),
      _v3Action(
        '05-02',
        'Выписать страны, где нужно принимать первые реальные платежи',
        'Список стран первого запуска',
        10,
        'payments',
      ),
      _v3Action(
        '05-03',
        'Сравнить два или три сервиса приёма платежей по доступности, налогам и возвратам',
        'Сравнение вариантов по одинаковым критериям',
        30,
        'payments',
      ),
      _v3Action(
        '05-04',
        'Выбрать один сервис для первой рабочей оплаты и записать причину',
        'Выбранный способ приёма оплаты',
        15,
        'payments',
      ),
      _v3Action(
        '05-05',
        'Нарисовать путь «оплата → подтверждение → выдача платного доступа»',
        'Схема выдачи доступа после оплаты',
        20,
        'licensing',
      ),
      _v3Action(
        '05-06',
        'Решить, чем подтверждается платная версия: ключом, аккаунтом или другим способом',
        'Один выбранный механизм лицензии',
        20,
        'licensing',
      ),
      _v3Action(
        '05-07',
        'Записать, как покупатель восстанавливает платную версию после переустановки Windows',
        'Понятное правило восстановления покупки',
        15,
        'licensing',
      ),
      _v3Action(
        '05-08',
        'Выписать, какие данные КАДР хранит локально и какие данные вообще могут уходить в интернет',
        'Карта данных для политики конфиденциальности',
        25,
        'legal',
      ),
      _v3Action(
        '05-09',
        'Подготовить структуру условий использования, лицензии, политики конфиденциальности и возвратов',
        'Черновая структура четырёх обязательных документов',
        30,
        'legal',
      ),
      _v3Action(
        '05-10',
        'Выписать юридические вопросы, которые надо проверить по официальным источникам или с юристом',
        'Список нерешённых юридических вопросов без догадок',
        20,
        'legal',
      ),
      _v3Action(
        '05-11',
        'Провести тестовую покупку и записать каждый шаг от страницы цены до включения платной версии',
        'Пройденная тестовая покупка или точная точка отказа',
        25,
        'payments',
      ),
      _v3Action(
        '05-12',
        'Провести тест возврата и проверить изменение платного доступа',
        'Пройденный возврат или точная точка отказа',
        20,
        'payments',
      ),
    ],
  ),
  _v3Stage(
    6,
    'Подготовить официальное распространение Windows-версии',
    'Есть стабильная прямая ссылка на установщик и готовая или опубликованная карточка КАДР в Microsoft Store; установка из обоих каналов проверена.',
    [
      _v3Action(
        '06-01',
        'Выбрать постоянное место для официального установщика, где ссылка не меняется между загрузками',
        'Постоянный адрес загрузки установщика',
        20,
        'windows_distribution',
      ),
      _v3Action(
        '06-02',
        'Проверить текущие требования Microsoft Store к обычным Windows-приложениям',
        'Актуальный список требований Microsoft Store',
        30,
        'microsoft_store',
      ),
      _v3Action(
        '06-03',
        'Решить, публикуем текущий EXE/MSI или сначала переходим на MSIX',
        'Выбранный формат публикации с причиной',
        20,
        'microsoft_store',
      ),
      _v3Action(
        '06-04',
        'Проверить или создать учётную запись разработчика Microsoft для публикации',
        'Доступ к кабинету публикации или список недостающих шагов',
        25,
        'microsoft_store',
      ),
      _v3Action(
        '06-05',
        'Зарезервировать название КАДР в кабинете Microsoft, если оно доступно',
        'Зарезервированное название или выбранная замена',
        15,
        'microsoft_store',
      ),
      _v3Action(
        '06-06',
        'Подготовить описание, иконку и требуемые изображения для карточки Microsoft Store',
        'Комплект материалов для карточки магазина',
        30,
        'microsoft_store',
      ),
      _v3Action(
        '06-07',
        'Отправить первую тестовую или рабочую заявку КАДР в Microsoft Store',
        'Номер или статус отправленной заявки',
        30,
        'microsoft_store',
      ),
      _v3Action(
        '06-08',
        'После публикации установить КАДР из Microsoft Store на чистой системе',
        'Результат установки из магазина',
        20,
        'microsoft_store',
      ),
    ],
  ),
  _v3Stage(
    7,
    'Проверить спрос на реальном использовании',
    'Минимум пять внешних людей самостоятельно установили КАДР и выполнили один и тот же сценарий; по каждому записано, пользовался ли он ещё раз без напоминания и что ему мешало.',
    [
      _v3Action(
        '07-01',
        'Выбрать три типа людей, для которых проблема со скриншотами выглядит наиболее реальной',
        'Три конкретных типа потенциальных пользователей',
        20,
        'demand',
      ),
      _v3Action(
        '07-02',
        'Составить список из десяти конкретных людей, которых можно попросить попробовать КАДР',
        'Десять имён или контактов',
        20,
        'demand',
      ),
      _v3Action(
        '07-03',
        'Написать короткое приглашение без подсказки, что именно человеку должно понравиться',
        'Один нейтральный текст приглашения',
        15,
        'demand',
      ),
      _v3Action(
        '07-04',
        'Отправить приглашение первым пяти людям',
        'Пять реально отправленных приглашений',
        15,
        'demand',
      ),
      _v3Action(
        '07-05',
        'Составить одинаковый сценарий проверки: установить, сделать скриншот, отредактировать, отправить или сохранить',
        'Один сценарий проверки для всех участников',
        20,
        'demand',
      ),
      _v3Action(
        '07-06',
        'Провести первое наблюдение за пользователем, не подсказывая интерфейс',
        'Карточка фактов по пользователю №1',
        30,
        'demand',
      ),
      _v3Action(
        '07-07',
        'Провести второе наблюдение за пользователем по тому же сценарию',
        'Карточка фактов по пользователю №2',
        30,
        'demand',
      ),
      _v3Action(
        '07-08',
        'Через несколько дней спросить каждого участника, открывал ли он КАДР сам после теста',
        'Факты повторного использования или отказа по каждому участнику',
        20,
        'demand',
      ),
    ],
  ),
  _v3Stage(
    8,
    'Проверить, готовы ли люди платить именно за выбранную платную ценность',
    'Платная версия реально предложена подходящим пользователям по настоящей цене и рабочей ссылке оплаты; есть хотя бы одна оплата либо понятные причины отказа, записанные без оправданий.',
    [
      _v3Action(
        '08-01',
        'Выбрать из тестировщиков тех, кто действительно столкнулся с проблемой, которую решает платная версия',
        'Список людей, которым предложение платной версии уместно',
        15,
        'demand',
      ),
      _v3Action(
        '08-02',
        'Проверить, что страница цены, оплата и выдача лицензии работают перед предложением людям',
        'Контрольная успешная тестовая покупка',
        20,
        'payments',
      ),
      _v3Action(
        '08-03',
        'Отправить первому подходящему пользователю предложение купить платную версию по реальной цене',
        'Одно реальное предложение с рабочей ссылкой оплаты',
        10,
        'demand',
      ),
      _v3Action(
        '08-04',
        'Записать ответ первого пользователя дословно по смыслу: купил, отказался или отложил и почему',
        'Факт решения пользователя без интерпретации',
        10,
        'demand',
      ),
      _v3Action(
        '08-05',
        'Повторить предложение ещё четырём подходящим пользователям',
        'Пять реальных предложений суммарно',
        20,
        'demand',
      ),
      _v3Action(
        '08-06',
        'Свести причины покупки и отказа в одну короткую таблицу',
        'Список повторяющихся причин платить или не платить',
        20,
        'demand',
      ),
      _v3Action(
        '08-07',
        'Решить по фактам: оставить состав платной версии, изменить его или изменить цену',
        'Одно решение о следующем варианте платного предложения',
        20,
        'offer',
      ),
    ],
  ),
  _v3Stage(
    9,
    'Разобраться с Apple и выбрать реальный путь',
    'Принято отдельное решение по macOS и по iPhone/iPad: что именно мы строим, зачем это пользователю, что требуется для разработки и публикации и в каком порядке это идёт после Windows.',
    [
      _v3Action(
        '09-01',
        'Выписать сценарии КАДР, которые должны работать на Mac как полноценное приложение',
        'Список сценариев полноценной macOS-версии',
        20,
        'apple',
      ),
      _v3Action(
        '09-02',
        'Отдельно выписать сценарии, где iPhone или iPad нужен как дополнение к Windows-КАДР',
        'Список сценариев мобильного приложения-компаньона',
        20,
        'apple',
      ),
      _v3Action(
        '09-03',
        'Решить отдельно по двум пунктам: делаем ли полноценный КАДР для macOS и делаем ли приложение для iPhone/iPad',
        'Два явных решения вместо общего слова «Apple»',
        15,
        'apple',
      ),
      _v3Action(
        '09-04',
        'Проверить, какой Mac и какая версия Xcode доступны для сборки и проверки Apple-версий',
        'Понятный доступный путь к среде разработки Apple',
        20,
        'apple',
      ),
      _v3Action(
        '09-05',
        'Проверить состояние участия в Apple Developer Program и доступ к App Store Connect',
        'Доступ подтверждён или записан точный следующий шаг регистрации',
        20,
        'apple',
      ),
      _v3Action(
        '09-06',
        'Открыть код КАДР и выписать модули, которые напрямую зависят от Windows',
        'Список Windows-зависимых частей, которые нельзя просто перенести',
        30,
        'apple',
      ),
      _v3Action(
        '09-07',
        'Для выбранной Apple-ветки составить отдельный технический подплан, где каждый следующий шаг не длиннее 30 минут',
        'Исполнимый технический подплан Apple до первой запускаемой сборки',
        30,
        'apple',
      ),
      _v3Action(
        '09-08',
        'Если выбран macOS, решить: только Mac App Store, прямое скачивание с подписью и нотариальным заверением Apple или оба канала',
        'Выбранная схема распространения macOS-версии',
        20,
        'apple',
      ),
      _v3Action(
        '09-09',
        'Если выбран iPhone/iPad, описать минимальную первую версию приложения-компаньона без лишних функций',
        'Состав первой iOS/iPadOS-версии',
        20,
        'apple',
      ),
      _v3Action(
        '09-10',
        'Записать путь проверки Apple-версии через TestFlight перед публичной публикацией',
        'Пошаговый путь тестовой публикации Apple',
        20,
        'apple',
      ),
    ],
  ),
  _v3Stage(
    10,
    'Не забыть Android и RuStore, но не придумывать несуществующее приложение',
    'Принято явное решение, нужен ли КАДР на Android. Если нужен — определён первый сценарий приложения и создан отдельный технический подплан; если не нужен сейчас — записана причина и условие возврата к решению.',
    [
      _v3Action(
        '10-01',
        'Выписать, что полезного Android-приложение КАДР могло бы делать вместе с Windows-версией',
        'Список реальных сценариев Android, а не список функций ради магазина',
        20,
        'android',
      ),
      _v3Action(
        '10-02',
        'Решить, нужен ли Android в текущей стратегии или его откладываем до подтверждения конкретного сценария',
        'Явное решение по Android с причиной',
        15,
        'android',
      ),
      _v3Action(
        '10-03',
        'Если Android нужен, описать минимальную первую версию приложения-компаньона',
        'Состав первой Android-версии',
        20,
        'android',
      ),
      _v3Action(
        '10-04',
        'Если Android нужен, разложить разработку первой сборки на технические действия не длиннее 30 минут',
        'Исполнимый технический подплан Android',
        30,
        'android',
      ),
      _v3Action(
        '10-05',
        'Перед публикацией Android-версии проверить актуальные требования RuStore к пакету, карточке и модерации',
        'Актуальный список требований RuStore',
        30,
        'android',
      ),
      _v3Action(
        '10-06',
        'Если Android отложен, записать конкретное условие, при котором мы возвращаемся к RuStore',
        'Условие возврата к Android вместо забытой идеи',
        10,
        'android',
      ),
    ],
  ),
  _v3Stage(
    11,
    'Настроить поддержку и безопасный выпуск новых версий',
    'Пользователь знает, куда писать; каждая версия имеет понятный выпуск и откат; покупка и лицензия не зависят от ручной памяти владельца проекта.',
    [
      _v3Action(
        '11-01',
        'Выбрать один основной адрес или форму поддержки КАДР',
        'Рабочий канал поддержки',
        10,
        'support',
      ),
      _v3Action(
        '11-02',
        'Составить короткий шаблон сообщения об ошибке с версией приложения и шагами воспроизведения',
        'Шаблон обращения об ошибке',
        15,
        'support',
      ),
      _v3Action(
        '11-03',
        'Записать минимальный порядок выпуска версии: сборка, проверка, подпись, публикация, заметка об изменениях',
        'Повторяемый порядок выпуска новой версии',
        20,
        'release',
      ),
      _v3Action(
        '11-04',
        'Записать способ быстро вернуть предыдущую рабочую версию при критической ошибке',
        'Понятный способ отката',
        15,
        'release',
      ),
      _v3Action(
        '11-05',
        'Проверить, где хранятся данные о покупках и лицензиях и как они восстанавливаются после сбоя',
        'Схема резервного восстановления платного доступа',
        20,
        'licensing',
      ),
      _v3Action(
        '11-06',
        'Пройти путь поддержки на тестовом обращении от отправки до ответа',
        'Проверенный пользовательский путь поддержки',
        15,
        'support',
      ),
    ],
  ),
  _v3Stage(
    12,
    'Провести контрольный коммерческий запуск от начала до конца',
    'Новый человек без моей помощи находит сайт, понимает бесплатную и платную версии, скачивает КАДР, устанавливает его, покупает платную версию, получает доступ и знает, куда обратиться; весь путь проверен на реальном устройстве.',
    [
      _v3Action(
        '12-01',
        'Открыть сайт как новый пользователь и пройти путь до скачивания Windows-версии',
        'Проверенный путь сайт → скачивание',
        15,
        'website',
      ),
      _v3Action(
        '12-02',
        'Установить опубликованную сборку на чистой Windows-системе',
        'Проверенный путь скачивание → установка',
        20,
        'windows_distribution',
      ),
      _v3Action(
        '12-03',
        'Проверить на опубликованной версии, что бесплатные функции работают без оплаты',
        'Подтверждение честной бесплатной версии',
        15,
        'offer',
      ),
      _v3Action(
        '12-04',
        'Купить платную версию через опубликованный сайт по реальному пользовательскому пути',
        'Контрольная покупка опубликованного продукта',
        20,
        'payments',
      ),
      _v3Action(
        '12-05',
        'Проверить активацию платной версии и восстановление покупки после переустановки',
        'Контрольная проверка лицензии и восстановления',
        25,
        'licensing',
      ),
      _v3Action(
        '12-06',
        'Отправить тестовое обращение в поддержку со страницы сайта',
        'Контрольный путь сайт → поддержка',
        10,
        'support',
      ),
      _v3Action(
        '12-07',
        'Записать все места, где в контрольном запуске понадобилась моя ручная помощь',
        'Финальный список ручных зависимостей перед самостоятельной продажей',
        15,
        'release',
      ),
    ],
  ),
];

const List<String> _v3KadrRequiredTracks = <String>[
  'offer',
  'product',
  'website',
  'payments',
  'licensing',
  'legal',
  'windows_distribution',
  'microsoft_store',
  'demand',
  'apple',
  'android',
  'support',
  'release',
];

String _v3TrackLabel(String track, bool ru) {
  if (!ru) {
    return switch (track) {
      'offer' => 'Free / paid offer',
      'product' => 'Product',
      'website' => 'Website',
      'payments' => 'Payments',
      'licensing' => 'Licensing',
      'legal' => 'Legal',
      'windows_distribution' => 'Windows distribution',
      'microsoft_store' => 'Microsoft Store',
      'demand' => 'Demand',
      'apple' => 'Apple',
      'android' => 'Android / RuStore',
      'support' => 'Support',
      'release' => 'Release process',
      _ => 'Execution',
    };
  }
  return switch (track) {
    'offer' => 'Бесплатное / платное',
    'product' => 'Продукт',
    'website' => 'Сайт',
    'payments' => 'Оплата',
    'licensing' => 'Лицензия',
    'legal' => 'Документы и право',
    'windows_distribution' => 'Windows-установка',
    'microsoft_store' => 'Microsoft Store',
    'demand' => 'Проверка спроса',
    'apple' => 'Apple',
    'android' => 'Android / RuStore',
    'support' => 'Поддержка',
    'release' => 'Выпуск версий',
    _ => 'Исполнение',
  };
}

Future<void> _upgradeKadrRealityPathV3() async {
  final db = DatabaseService.instance;
  await db.refreshCategoryRulesFromServer();
  final category = _v3FindKadrCategory();
  if (category == null) return;

  var tasks = await db.fetchBacklogPlans(
    categoryId: category.id,
    includeCompleted: true,
  );
  for (final task in tasks) {
    if ((task.notesPlain ?? '').trim() == _activeProjectPathMarkerV2 &&
        _v3ChecklistIsKadrReality(task.checklist)) {
      return;
    }
  }

  for (final task in tasks) {
    if ((task.notesPlain ?? '').trim() != _activeProjectPathMarkerV2) continue;
    final ok = await db.updatePlanningTask(
      task.planRowIdForBackend,
      planBusinessId: task.planRowId,
      title: task.title,
      categoryId: task.categoryId,
      isDone: true,
      notesPlain: _retiredProjectPathMarkerV2,
      checklist: task.checklist,
      suppressAppSnack: true,
    );
    if (!ok) throw StateError('Could not preserve previous KADR Path');
  }

  final order = await db.nextBacklogPlanningOrder();
  final created = await db.addPlanningTask(
    PlanningTask(
      id: 0,
      title:
          'Довести КАДР от текущей Windows-сборки до продукта, который человек может понять, скачать, установить, купить и использовать без моей ручной помощи; затем последовательно вывести нужные версии на другие платформы.',
      categoryId: category.id,
      isDone: true,
      dateKey: '',
      order: order,
      checklist: _v3KadrChecklist(),
      notesPlain: _activeProjectPathMarkerV2,
      isSynced: false,
    ),
  );
  if (!created) throw StateError('Could not create KADR reality Path');
}

class _V3PathAction {
  const _V3PathAction({
    required this.id,
    required this.text,
    required this.result,
    required this.minutes,
    required this.track,
    required this.done,
  });

  final String id;
  final String text;
  final String result;
  final int minutes;
  final String track;
  final bool done;

  _V3PathAction copyWith({
    String? text,
    String? result,
    int? minutes,
    String? track,
    bool? done,
  }) => _V3PathAction(
    id: id,
    text: text ?? this.text,
    result: result ?? this.result,
    minutes: minutes ?? this.minutes,
    track: track ?? this.track,
    done: done ?? this.done,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'text': text,
    'result': result,
    'minutes': minutes,
    'track': track,
    'isDone': done,
  };
}

class _V3PathStage {
  const _V3PathStage({
    required this.id,
    required this.title,
    required this.doneWhen,
    required this.done,
    required this.actions,
  });

  final String id;
  final String title;
  final String doneWhen;
  final bool done;
  final List<_V3PathAction> actions;

  _V3PathStage copyWith({
    String? title,
    String? doneWhen,
    bool? done,
    List<_V3PathAction>? actions,
  }) => _V3PathStage(
    id: id,
    title: title ?? this.title,
    doneWhen: doneWhen ?? this.doneWhen,
    done: done ?? this.done,
    actions: actions ?? this.actions,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': 'stage',
    'id': id,
    'text': title,
    'definitionOfDone': doneWhen,
    'isDone': done,
    'actions': actions.map((e) => e.toJson()).toList(growable: false),
  };
}

List<_V3PathStage> _v3ParseStages(PlanningTask task) {
  final stages = <_V3PathStage>[];
  for (var si = 0; si < task.checklist.length; si++) {
    final row = task.checklist[si];
    final title = (row['text'] ?? '').toString().trim();
    if (title.isEmpty) continue;
    final actions = <_V3PathAction>[];
    final rawActions = row['actions'];
    if (rawActions is List) {
      for (var ai = 0; ai < rawActions.length; ai++) {
        final raw = rawActions[ai];
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final text = (map['text'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        final rawMinutes = map['minutes'];
        final minutes = rawMinutes is int
            ? rawMinutes
            : int.tryParse(rawMinutes?.toString() ?? '') ?? 0;
        actions.add(
          _V3PathAction(
            id: (map['id'] ?? 'action-$si-$ai').toString(),
            text: text,
            result: (map['result'] ?? '').toString().trim(),
            minutes: minutes,
            track: (map['track'] ?? 'execution').toString().trim(),
            done: map['isDone'] == true,
          ),
        );
      }
    }
    stages.add(
      _V3PathStage(
        id: (row['id'] ?? 'stage-$si').toString(),
        title: title,
        doneWhen: (row['definitionOfDone'] ?? '').toString().trim(),
        done: row['isDone'] == true,
        actions: actions,
      ),
    );
  }
  return stages;
}

class _V3RealityCheck {
  const _V3RealityCheck({
    required this.structureProblems,
    required this.missingTracks,
    required this.audited,
  });

  final List<String> structureProblems;
  final List<String> missingTracks;
  final bool audited;

  bool get executableNow => structureProblems.isEmpty;
}

_V3RealityCheck _v3CheckPath(CategoryRule category, PlanningTask root) {
  final stages = _v3ParseStages(root);
  final structure = <String>[];
  final covered = <String>{};
  if (stages.isEmpty) structure.add('Нет этапов.');
  for (var si = 0; si < stages.length; si++) {
    final stage = stages[si];
    if (stage.doneWhen.isEmpty) {
      structure.add('Этап ${si + 1}: не записано, когда он считается завершённым.');
    }
    if (!stage.done && stage.actions.isEmpty) {
      structure.add('Этап ${si + 1}: нет конкретных действий.');
    }
    for (var ai = 0; ai < stage.actions.length; ai++) {
      final action = stage.actions[ai];
      if (action.track.isNotEmpty) covered.add(action.track);
      if (action.minutes < 1 || action.minutes > 30) {
        structure.add('Этап ${si + 1}, действие ${ai + 1}: нужно разбить до 30 минут.');
      }
      if (action.result.isEmpty) {
        structure.add('Этап ${si + 1}, действие ${ai + 1}: не указан результат.');
      }
    }
  }

  final normalized = _v3NormalizeProjectName(category.name);
  final audited = (normalized == 'кадр' || normalized == 'kadr') &&
      _v3ChecklistIsKadrReality(root.checklist);
  final required = audited ? _v3KadrRequiredTracks : const <String>[];
  final missing = <String>[
    for (final track in required)
      if (!covered.contains(track)) track,
  ];
  return _V3RealityCheck(
    structureProblems: structure,
    missingTracks: missing,
    audited: audited,
  );
}

class ProjectPathsV3Page extends StatefulWidget {
  const ProjectPathsV3Page({super.key});

  @override
  State<ProjectPathsV3Page> createState() => _ProjectPathsV3PageState();
}

class _ProjectPathsV3PageState extends State<ProjectPathsV3Page> {
  bool _loading = true;
  String? _error;
  List<CategoryRule> _categories = const <CategoryRule>[];
  Map<int, PlanningTask> _roots = const <int, PlanningTask>{};
  int? _selectedCategoryId;

  bool get _ru => currentLocale.value.toLowerCase().startsWith('ru');

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapAndLoad());
  }

  Future<void> _bootstrapAndLoad() async {
    try {
      await bootstrapExecutablePortfolioPaths();
      await _upgradeKadrRealityPathV3();
    } catch (e) {
      _error = e.toString();
    }
    await _load();
  }

  Future<void> _load() async {
    final db = DatabaseService.instance;
    await db.refreshCategoryRulesFromServer();
    final tasks = await db.fetchBacklogPlans(includeCompleted: true);
    final roots = <int, PlanningTask>{};
    for (final task in tasks) {
      if ((task.notesPlain ?? '').trim() != _activeProjectPathMarkerV2) continue;
      final current = roots[task.categoryId];
      if (current == null ||
          (!_v3ChecklistIsKadrReality(current.checklist) &&
              _v3ChecklistIsKadrReality(task.checklist))) {
        roots[task.categoryId] = task;
      }
    }

    final categories = <CategoryRule>[];
    final seen = <int>{};
    for (final pair in db.allCategoryIdPathPairs) {
      if (!seen.add(pair.id)) continue;
      if (!roots.containsKey(pair.id)) continue;
      final rule = db.getCategoryRuleById(pair.id);
      if (rule == null || rule.isArchived) continue;
      categories.add(rule);
    }
    categories.sort((a, b) {
      final an = _v3NormalizeProjectName(a.name);
      final bn = _v3NormalizeProjectName(b.name);
      final ak = an == 'кадр' || an == 'kadr';
      final bk = bn == 'кадр' || bn == 'kadr';
      if (ak != bk) return ak ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    var selected = _selectedCategoryId;
    if (selected == null || !roots.containsKey(selected)) {
      selected = categories.isEmpty ? null : categories.first.id;
    }
    if (!mounted) return;
    setState(() {
      _roots = roots;
      _categories = categories;
      _selectedCategoryId = selected;
      _loading = false;
    });
  }

  Future<bool> _saveRoot(
    CategoryRule category,
    PlanningTask root,
    List<_V3PathStage> stages, {
    String? goal,
  }) async {
    final ok = await DatabaseService.instance.updatePlanningTask(
      root.planRowIdForBackend,
      planBusinessId: root.planRowId,
      title: goal ?? root.title,
      categoryId: category.id,
      isDone: true,
      notesPlain: _activeProjectPathMarkerV2,
      checklist: stages.map((e) => e.toJson()).toList(growable: false),
      suppressAppSnack: true,
    );
    if (!ok) return false;
    await _load();
    return true;
  }

  void _saveFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(_ru ? 'Не удалось сохранить изменение.' : 'Could not save the change.')),
      );
  }

  Future<String?> _textDialog({
    required String title,
    required String label,
    required String initial,
    int maxLines = 5,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 620,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: maxLines,
            decoration: InputDecoration(labelText: label),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(_ru ? 'Отмена' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(ctx).pop(value);
            },
            child: Text(_ru ? 'Сохранить' : 'Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _editGoal(CategoryRule category, PlanningTask root) async {
    final value = await _textDialog(
      title: _ru ? 'Цель проекта' : 'Project goal',
      label: _ru ? 'Конечное состояние проекта' : 'Project end state',
      initial: root.title,
    );
    if (value == null || value == root.title) return;
    final ok = await _saveRoot(category, root, _v3ParseStages(root), goal: value);
    if (!ok) _saveFailed();
  }

  Future<void> _toggleStage(
    CategoryRule category,
    PlanningTask root,
    int stageIndex,
    bool done,
  ) async {
    final stages = _v3ParseStages(root);
    if (stageIndex < 0 || stageIndex >= stages.length) return;
    stages[stageIndex] = stages[stageIndex].copyWith(done: done);
    final ok = await _saveRoot(category, root, stages);
    if (!ok) _saveFailed();
  }

  Future<void> _toggleAction(
    CategoryRule category,
    PlanningTask root,
    int stageIndex,
    int actionIndex,
    bool done,
  ) async {
    final stages = _v3ParseStages(root);
    if (stageIndex < 0 || stageIndex >= stages.length) return;
    final actions = List<_V3PathAction>.from(stages[stageIndex].actions);
    if (actionIndex < 0 || actionIndex >= actions.length) return;
    actions[actionIndex] = actions[actionIndex].copyWith(done: done);
    stages[stageIndex] = stages[stageIndex].copyWith(actions: actions);
    final ok = await _saveRoot(category, root, stages);
    if (!ok) _saveFailed();
  }

  Future<void> _editStage(
    CategoryRule category,
    PlanningTask root,
    int stageIndex,
  ) async {
    final stages = _v3ParseStages(root);
    if (stageIndex < 0 || stageIndex >= stages.length) return;
    final title = await _textDialog(
      title: _ru ? 'Название этапа' : 'Stage title',
      label: _ru ? 'Какой результат должен быть достигнут' : 'Stage outcome',
      initial: stages[stageIndex].title,
      maxLines: 3,
    );
    if (title == null) return;
    final doneWhen = await _textDialog(
      title: _ru ? 'Когда этап завершён' : 'Done criterion',
      label: _ru ? 'Проверяемое условие завершения' : 'Verifiable done condition',
      initial: stages[stageIndex].doneWhen,
    );
    if (doneWhen == null) return;
    stages[stageIndex] = stages[stageIndex].copyWith(
      title: title,
      doneWhen: doneWhen,
    );
    final ok = await _saveRoot(category, root, stages);
    if (!ok) _saveFailed();
  }

  Future<void> _addStage(CategoryRule category, PlanningTask root) async {
    final title = await _textDialog(
      title: _ru ? 'Новый этап' : 'New stage',
      label: _ru ? 'Результат этапа' : 'Stage outcome',
      initial: '',
      maxLines: 3,
    );
    if (title == null) return;
    final doneWhen = await _textDialog(
      title: _ru ? 'Когда этап завершён' : 'Done criterion',
      label: _ru ? 'Проверяемое условие завершения' : 'Verifiable done condition',
      initial: '',
    );
    if (doneWhen == null) return;
    final stages = _v3ParseStages(root)
      ..add(
        _V3PathStage(
          id: 'manual-stage-${DateTime.now().microsecondsSinceEpoch}',
          title: title,
          doneWhen: doneWhen,
          done: false,
          actions: const <_V3PathAction>[],
        ),
      );
    final ok = await _saveRoot(category, root, stages);
    if (!ok) _saveFailed();
  }

  Future<_V3PathAction?> _actionDialog({_V3PathAction? initial}) async {
    final textController = TextEditingController(text: initial?.text ?? '');
    final resultController = TextEditingController(text: initial?.result ?? '');
    var minutes = initial?.minutes ?? 20;
    final action = await showDialog<_V3PathAction>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(_ru ? 'Конкретное действие' : 'Concrete action'),
          content: SizedBox(
            width: 680,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: _ru ? 'Что физически сделать' : 'What to do',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: resultController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _ru ? 'Что должно остаться после действия' : 'Expected output',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: minutes,
                  decoration: InputDecoration(labelText: _ru ? 'Время' : 'Time'),
                  items: const <int>[5, 10, 15, 20, 25, 30]
                      .map(
                        (m) => DropdownMenuItem<int>(
                          value: m,
                          child: Text(_ru ? '$m мин' : '$m min'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setLocal(() => minutes = value ?? 20),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(_ru ? 'Отмена' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = textController.text.trim();
                final result = resultController.text.trim();
                if (text.isEmpty || result.isEmpty) return;
                Navigator.of(ctx).pop(
                  _V3PathAction(
                    id: initial?.id ?? 'manual-action-${DateTime.now().microsecondsSinceEpoch}',
                    text: text,
                    result: result,
                    minutes: minutes,
                    track: initial?.track ?? 'execution',
                    done: initial?.done ?? false,
                  ),
                );
              },
              child: Text(_ru ? 'Сохранить' : 'Save'),
            ),
          ],
        ),
      ),
    );
    textController.dispose();
    resultController.dispose();
    return action;
  }

  Future<void> _editAction(
    CategoryRule category,
    PlanningTask root,
    int stageIndex,
    int actionIndex,
  ) async {
    final stages = _v3ParseStages(root);
    if (stageIndex < 0 || stageIndex >= stages.length) return;
    final actions = List<_V3PathAction>.from(stages[stageIndex].actions);
    if (actionIndex < 0 || actionIndex >= actions.length) return;
    final edited = await _actionDialog(initial: actions[actionIndex]);
    if (edited == null) return;
    actions[actionIndex] = edited;
    stages[stageIndex] = stages[stageIndex].copyWith(actions: actions);
    final ok = await _saveRoot(category, root, stages);
    if (!ok) _saveFailed();
  }

  Future<void> _addAction(
    CategoryRule category,
    PlanningTask root,
    int stageIndex,
  ) async {
    final stages = _v3ParseStages(root);
    if (stageIndex < 0 || stageIndex >= stages.length) return;
    final action = await _actionDialog();
    if (action == null) return;
    final inheritedTrack = stages[stageIndex].actions.isEmpty
        ? 'execution'
        : stages[stageIndex].actions.first.track;
    final actions = List<_V3PathAction>.from(stages[stageIndex].actions)
      ..add(action.copyWith(track: inheritedTrack));
    stages[stageIndex] = stages[stageIndex].copyWith(actions: actions);
    final ok = await _saveRoot(category, root, stages);
    if (!ok) _saveFailed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_ru ? 'Пути' : 'Paths'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _ru
                    ? 'Цель → этап → конкретное действие. В день попадают только действия до 30 минут.'
                    : 'Goal → stage → concrete action. Only actions up to 30 minutes belong in a day.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
          ? Center(child: Text(_ru ? 'Пути не найдены.' : 'No paths found.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 900;
                if (!desktop) return _mobileList();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 320, child: _projectList()),
                    const VerticalDivider(width: 1),
                    Expanded(child: _selectedProject()),
                  ],
                );
              },
            ),
    );
  }

  Widget _mobileList() {
    return _projectList(
      onOpen: (category) {
        setState(() => _selectedCategoryId = category.id);
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => _MobilePathDetail(host: this, category: category)),
        );
      },
    );
  }

  Widget _projectList({void Function(CategoryRule category)? onOpen}) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _ru ? 'Часть автоматического обновления не прошла.' : 'Part of the automatic upgrade failed.',
              style: TextStyle(color: scheme.error),
            ),
          ),
        for (final category in _categories)
          Builder(
            builder: (context) {
              final root = _roots[category.id]!;
              final stages = _v3ParseStages(root);
              final current = stages.where((stage) => !stage.done).firstOrNull;
              final check = _v3CheckPath(category, root);
              final selected = category.id == _selectedCategoryId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: selected
                      ? scheme.primaryContainer.withValues(alpha: 0.55)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: CircleAvatar(
                      backgroundColor: category.colorOrDefault.withValues(alpha: 0.14),
                      foregroundColor: category.colorOrDefault,
                      child: Icon(category.iconOrDefault, size: 20),
                    ),
                    title: Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      current == null
                          ? (_ru ? 'Все этапы отмечены' : 'All stages marked')
                          : '${_ru ? 'Сейчас' : 'Now'}: ${current.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(
                      check.audited &&
                              check.structureProblems.isEmpty &&
                              check.missingTracks.isEmpty
                          ? Icons.verified_outlined
                          : Icons.error_outline_rounded,
                      size: 20,
                      color: check.audited &&
                              check.structureProblems.isEmpty &&
                              check.missingTracks.isEmpty
                          ? scheme.primary
                          : scheme.outline,
                    ),
                    onTap: () {
                      if (onOpen != null) {
                        onOpen(category);
                      } else {
                        setState(() => _selectedCategoryId = category.id);
                      }
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _selectedProject() {
    final id = _selectedCategoryId;
    if (id == null) return const SizedBox.shrink();
    CategoryRule? category;
    for (final item in _categories) {
      if (item.id == id) {
        category = item;
        break;
      }
    }
    if (category == null) return const SizedBox.shrink();
    return _detail(category);
  }

  Widget _detail(CategoryRule category) {
    final root = _roots[category.id];
    if (root == null) return const SizedBox.shrink();
    final stages = _v3ParseStages(root);
    final check = _v3CheckPath(category, root);
    var currentIndex = -1;
    for (var i = 0; i < stages.length; i++) {
      if (!stages[i].done) {
        currentIndex = i;
        break;
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(root.title, style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => unawaited(_editGoal(category!, root)),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: _ru ? 'Изменить цель' : 'Edit goal',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _realityCard(category, root, check),
            if (currentIndex >= 0) ...[
              const SizedBox(height: 12),
              _currentCard(stages[currentIndex]),
            ],
            const SizedBox(height: 16),
            for (var i = 0; i < stages.length; i++)
              _stageCard(category, root, stages[i], i, i == currentIndex),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => unawaited(_addStage(category!, root)),
              icon: const Icon(Icons.add_rounded),
              label: Text(_ru ? 'Добавить этап' : 'Add stage'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _realityCard(
    CategoryRule category,
    PlanningTask root,
    _V3RealityCheck check,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final ok = check.audited &&
        check.structureProblems.isEmpty &&
        check.missingTracks.isEmpty;
    return Card(
      elevation: 0,
      color: ok
          ? scheme.secondaryContainer.withValues(alpha: 0.42)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.fact_check_outlined : Icons.search_rounded),
                const SizedBox(width: 8),
                Text(
                  _ru ? 'Проверка плана на реальность' : 'Reality check',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!check.audited)
              Text(
                _ru
                    ? 'Этот путь ещё не проходил полную проверку слепых зон. Я не считаю его проверенным, даже если формально в нём есть этапы.'
                    : 'This path has not yet received a full blind-spot audit and is not considered verified.',
              )
            else ...[
              Text(
                _ru
                    ? 'Проверяется не красота формулировок, а наличие всех обязательных частей пути до реального результата.'
                    : 'The check covers the complete route to a real outcome, not wording quality.',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final track in _v3KadrRequiredTracks)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: check.missingTracks.contains(track)
                            ? scheme.errorContainer
                            : scheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: check.missingTracks.contains(track)
                              ? scheme.error
                              : scheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            check.missingTracks.contains(track)
                                ? Icons.close_rounded
                                : Icons.check_rounded,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(_v3TrackLabel(track, _ru)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            if (check.structureProblems.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _ru ? 'Что сломано в структуре:' : 'Structural problems:',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              for (final problem in check.structureProblems.take(8))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $problem'),
                ),
            ],
            if (check.missingTracks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${_ru ? 'Не покрыто' : 'Missing'}: ${check.missingTracks.map((e) => _v3TrackLabel(e, _ru)).join(', ')}',
                style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _currentCard(_V3PathStage stage) {
    final scheme = Theme.of(context).colorScheme;
    final next = stage.actions.where((a) => !a.done).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _ru ? 'Сейчас' : 'Now',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stage.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_ru ? 'Следующее действие' : 'Next action'}: ${next.text} · ${next.minutes} ${_ru ? 'мин' : 'min'}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _stageCard(
    CategoryRule category,
    PlanningTask root,
    _V3PathStage stage,
    int stageIndex,
    bool current,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final doneActions = stage.actions.where((a) => a.done).length;
    final allActionsDone = stage.actions.isNotEmpty && doneActions == stage.actions.length;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: current ? scheme.primary.withValues(alpha: 0.45) : scheme.outlineVariant,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: current,
        tilePadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 12, 14),
        leading: Checkbox(
          value: stage.done,
          onChanged: (value) => unawaited(
            _toggleStage(category, root, stageIndex, value ?? false),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_ru ? 'Этап' : 'Stage'} ${stageIndex + 1}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              stage.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                decoration: stage.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${_ru ? 'Готово, когда' : 'Done when'}: ${stage.doneWhen.isEmpty ? '—' : stage.doneWhen}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$doneActions/${stage.actions.length}'),
            IconButton(
              onPressed: () => unawaited(_editStage(category, root, stageIndex)),
              icon: const Icon(Icons.edit_outlined, size: 19),
              tooltip: _ru ? 'Изменить этап' : 'Edit stage',
            ),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
        children: [
          if (allActionsDone && !stage.done)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _ru
                    ? 'Все действия отмечены. Теперь отдельно проверьте условие «Готово, когда» — этап не закрывается автоматически.'
                    : 'All actions are checked. Verify the done criterion separately; the stage is not closed automatically.',
              ),
            ),
          for (var ai = 0; ai < stage.actions.length; ai++)
            _actionRow(category, root, stageIndex, ai, stage.actions[ai]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => unawaited(_addAction(category, root, stageIndex)),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(_ru ? 'Добавить действие' : 'Add action'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(
    CategoryRule category,
    PlanningTask root,
    int stageIndex,
    int actionIndex,
    _V3PathAction action,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: action.done,
            onChanged: (value) => unawaited(
              _toggleAction(
                category,
                root,
                stageIndex,
                actionIndex,
                value ?? false,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () => unawaited(
                _editAction(category, root, stageIndex, actionIndex),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.text,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: action.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_ru ? 'Результат' : 'Output'}: ${action.result.isEmpty ? '—' : action.result}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${action.minutes} ${_ru ? 'мин' : 'min'}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            onPressed: () => unawaited(
              _editAction(category, root, stageIndex, actionIndex),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: _ru ? 'Изменить действие' : 'Edit action',
          ),
        ],
      ),
    );
  }
}

class _MobilePathDetail extends StatelessWidget {
  const _MobilePathDetail({required this.host, required this.category});

  final _ProjectPathsV3PageState host;
  final CategoryRule category;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: host._detail(category),
    );
  }
}

mixin ShellMoreMenu on ShellCoreLogic {
  static bool _moreMenuDiagnosticsMarkerLogged = false;

  bool get _desktopVoiceDevDiagnosticsVisible {
    const devToolsDefine = bool.fromEnvironment(
      'DESKTOP_VOICE_DEV_TOOLS',
      defaultValue: false,
    );
    final visible = kDebugMode || devToolsDefine;
    if (!_moreMenuDiagnosticsMarkerLogged) {
      _moreMenuDiagnosticsMarkerLogged = true;
      DesktopVoicePipeline.mark('DESKTOP_VOICE_MORE_MENU_DIAGNOSTICS_REMOVED');
      if (visible) {
        DesktopVoicePipeline.mark('DESKTOP_VOICE_DEV_ENTRY_GATED', 'dev_only');
      }
    }
    return visible;
  }

  void openProjectPaths() {
    unawaited(_openProjectPathsV3());
  }

  Future<void> _openProjectPathsV3() async {
    var migrationFailed = false;
    try {
      await _retireLegacyProjectPathsV1();
    } catch (e) {
      migrationFailed = true;
      debugPrint('[PROJECT_PATHS_V3] legacy migration failed: $e');
    }
    if (!mounted) return;

    if (migrationFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось обновить одну старую запись пути. Остальные данные не изменены.'),
        ),
      );
    }

    final formFactor = shellFormFactorForWidth(MediaQuery.sizeOf(context).width);
    if (formFactor != ShellFormFactor.desktop) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const ProjectPathsV3Page()),
      );
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => DesktopShellFrame(
          selectedIndex: 6,
          onTabSelected: (navIndex) {
            if (navIndex == 6) return;
            Navigator.of(routeContext).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              onDesktopSideNavSelected(navIndex);
            });
          },
          child: const ProjectPathsV3Page(),
        ),
      ),
    );
  }

  void openMoreMenu({bool secondaryOnly = false}) {
    final loc = currentLocale.value;
    final isRu = loc.toLowerCase().startsWith('ru');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StreamBuilder<UserSettings>(
        stream: DatabaseService.instance.userSettingsStream,
        initialData: DatabaseService.instance.settings,
        builder: (context, snapshot) {
          final isAdmin =
              snapshot.data?.isAdmin ??
              DatabaseService.instance.settings.isAdmin;
          debugPrint(
            '[ADMIN_FLAG] More bottom sheet settings.isAdmin=$isAdmin renderDevLab=$isAdmin',
          );
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!secondaryOnly) ...[
                  ListTile(
                    leading: const Icon(Icons.person_rounded),
                    title: Text(t(loc, 'more_menu_profile')),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() => setShellPageIndex(5));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.label_rounded),
                    title: Text(t(loc, 'more_menu_categories')),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() => setShellPageIndex(4));
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.alt_route_rounded),
                  title: Text(isRu ? 'Пути проектов' : 'Project paths'),
                  subtitle: Text(
                    isRu
                        ? 'От конечной цели до действий не длиннее 30 минут'
                        : 'From the end goal to actions no longer than 30 minutes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    openProjectPaths();
                  },
                ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.design_services_rounded),
                    title: const Text('Dev / Design Lab'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const ComponentLabPage(),
                        ),
                      );
                    },
                  ),
                if (_desktopVoiceDevDiagnosticsVisible)
                  ListTile(
                    leading: const Icon(Icons.graphic_eq_rounded),
                    title: Text(t(loc, 'more_menu_voice_diagnostics')),
                    subtitle: Text(
                      t(loc, 'more_menu_voice_diagnostics_subtitle'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      showDesktopVoiceAttemptDialog(context);
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    'Admin flag: $isAdmin',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void onShellTabSelected(int i) {
    if (i == 4) {
      openMoreMenu(secondaryOnly: false);
      return;
    }
    setState(() => setShellPageIndex(i));
    if (i == 0 || i == 1) {
      final target = DatabaseService.instance.getTimelineDeviceLocalToday();
      applySharedSelectedDate(target, loadTimelineTasks: i == 0);
    }
  }

  void onDesktopSideNavSelected(int navIndex) {
    // 0–3 primary tabs, 4 Categories, 5 Profile, 6 Paths, 7 More.
    if (navIndex == 6) {
      openProjectPaths();
      return;
    }
    if (navIndex == 7) {
      openMoreMenu(secondaryOnly: true);
      return;
    }
    if (navIndex <= 5) {
      setState(() => setShellPageIndex(navIndex));
      if (navIndex == 0 || navIndex == 1) {
        final target = DatabaseService.instance.getTimelineDeviceLocalToday();
        applySharedSelectedDate(target, loadTimelineTasks: navIndex == 0);
      }
    }
  }

  int desktopSideNavSelectedIndex(int shellPageIndex) {
    return switch (shellPageIndex) {
      0 || 1 || 2 || 3 || 4 || 5 => shellPageIndex,
      _ => 7,
    };
  }
}
