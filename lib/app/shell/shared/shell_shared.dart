import 'dart:async';

import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';
import 'package:counter/l10n/dictionary.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Shell-local time helpers (Planetary: UTC + profile offset). ---
DateTime shellDateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

bool shellSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String shellTwoDigits(int n) => n.toString().padLeft(2, '0');

DateTime shellLocalToday() =>
    DatabaseService.instance.getTimelineDeviceLocalToday();

/// Planning task opened from quick-add / draft: not yet on server (no PATCH id).
bool shellIsNewPlanningDraft(PlanningTask t) {
  if (t.id != 0) return false;
  final p = t.planRowId?.trim() ?? '';
  return p.isEmpty;
}

/// Hides a plan on the current day in optimistic merge until DELETE completes (see [DatabaseService.applyOptimisticPlanningTask]).
const String shellOptimisticPurgeDateKey = '2099-12-31';
const String shellPrefsRecordLinkSuggestionsEnabled =
    'plans_record_link_suggestions_enabled';
const String shellPrefsRecordLinkSuggestionMode =
    'plans_record_link_suggestion_mode';
const String shellPrefsRecordLinkSuggestionDismissed =
    'plans_record_link_suggestion_dismissed_record_ids';
const String shellRecordLinkSuggestionModeAsk = 'ask';
const String shellRecordLinkSuggestionModeAuto = 'auto';

// ---------------------------------------------------------------------------
// Profile hydration failure banner (authenticated session, PB profile missing).
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// EXECUTABLE PROJECT PATHS V2
//
// A Path is not a list of wishes. It is executable only when every unfinished
// stage has a Definition of Done and every action has a concrete output plus an
// estimate of 1–30 minutes. The Daily Planner may consume actions later; it
// must never receive a milestone such as "get first payment" as a daily task.
// ---------------------------------------------------------------------------

const String _lifeOsPathMarkerV1 = 'LIFEOS_PATH::V1';
const String _lifeOsPathMarkerV2 = 'LIFEOS_PATH::V2';
const String _portfolioExecutableBootstrapPref =
    'lifeos.portfolio.bootstrap.2026-08-17.executable-v2';

class _PathActionSeed {
  const _PathActionSeed({
    required this.text,
    required this.result,
    required this.minutes,
    required this.track,
  });

  final String text;
  final String result;
  final int minutes;
  final String track;
}

class _PathStageSeed {
  const _PathStageSeed({
    required this.title,
    required this.doneWhen,
    required this.actions,
  });

  final String title;
  final String doneWhen;
  final List<_PathActionSeed> actions;
}

class _ProjectPathSeed {
  const _ProjectPathSeed({
    required this.name,
    required this.aliases,
    required this.goal,
    required this.icon,
    required this.color,
    required this.requiredTracks,
    required this.stages,
  });

  final String name;
  final List<String> aliases;
  final String goal;
  final IconData icon;
  final Color color;
  final List<String> requiredTracks;
  final List<_PathStageSeed> stages;
}

const List<_ProjectPathSeed> _executablePortfolioSeeds = [
  _ProjectPathSeed(
    name: 'КАДР',
    aliases: ['КАДР', 'KADR'],
    goal:
        'Превратить КАДР в стабильный, легально продаваемый и удобно распространяемый инструмент для захвата экрана, ценность которого подтверждена реальными пользователями и оплатами.',
    icon: Icons.crop_free_rounded,
    color: Color(0xFF546E7A),
    requiredTracks: [
      'product',
      'reliability',
      'demand',
      'distribution',
      'payments',
      'legal',
      'operations',
    ],
    stages: [
      _PathStageSeed(
        title: 'Зафиксировать фактическое состояние текущей Windows-сборки',
        doneWhen:
            'Есть один актуальный список blocker / important / later, и каждый core-сценарий КАДР проверен на текущей сборке.',
        actions: [
          _PathActionSeed(
            text: 'Проверить выделение области на одном и двух мониторах и записать отклонения',
            result: 'Список найденных проблем capture или отметка OK',
            minutes: 20,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Проверить Copy, Save и повторное открытие последнего скриншота',
            result: 'Три результата проверки с фактическим поведением',
            minutes: 15,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Проверить пять основных инструментов редактора на одном скриншоте',
            result: 'Список конкретных сломанных или неудобных инструментов',
            minutes: 25,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Записать короткое видео и проверить, что оно появилось в истории',
            result: 'Факт прохождения video → history либо воспроизводимый blocker',
            minutes: 15,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Проверить hotkey после перезапуска приложения и записать результат',
            result: 'Подтверждение стабильности hotkey либо шаги воспроизведения ошибки',
            minutes: 10,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Разнести найденные проблемы по Blocker, Important и Later без исправления по ходу',
            result: 'Приоритизированный список текущей сборки',
            minutes: 20,
            track: 'operations',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Сделать сборку пригодной для установки посторонним человеком',
        doneWhen:
            'Чистый Windows-ПК устанавливает, запускает, обновляет и удаляет КАДР без ручных файлов и инструкций разработчика.',
        actions: [
          _PathActionSeed(
            text: 'Записать полный путь clean install от скачивания файла до первого capture',
            result: 'Чек-лист установки с каждым экраном и вмешательством пользователя',
            minutes: 20,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Проверить installer на чистой Windows-среде и выписать все предупреждения',
            result: 'Список SmartScreen, permissions и installer-проблем',
            minutes: 30,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Проверить текущий механизм обновления или зафиксировать, что его пока нет',
            result: 'Описание update-flow и конкретный следующий технический gap',
            minutes: 20,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Составить список требований к code signing для выбранного Windows-способа распространения',
            result: 'Короткий checklist signing с источниками для последующей проверки',
            minutes: 30,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Проверить uninstall и остаточные файлы после удаления КАДР',
            result: 'Список оставшихся файлов/настроек или отметка clean',
            minutes: 15,
            track: 'reliability',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Подготовить юридический, платёжный и лицензионный контур',
        doneWhen:
            'Определён продавец и схема платежей, есть проверенные Terms/Privacy/Refund, тестовая покупка выдаёт доступ, а возврат и восстановление покупки проверены.',
        actions: [
          _PathActionSeed(
            text: 'Зафиксировать, кто юридически будет продавцом КАДР и из какой страны',
            result: 'Одна записанная seller-схема без неоднозначности',
            minutes: 15,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Выписать страны, в которых нужно принимать первые платежи',
            result: 'Список launch-географий для проверки налогов и checkout',
            minutes: 10,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Сравнить merchant-of-record и собственный processor по налогам, возвратам и доступности',
            result: 'Таблица двух-трёх вариантов и выбранный следующий кандидат',
            minutes: 30,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Составить карту данных КАДР: что хранится локально, что может уходить на сервер и зачем',
            result: 'Data-flow список для Privacy Policy',
            minutes: 25,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Составить структуру Terms/EULA, Privacy и Refund Policy без финальной юридической редакции',
            result: 'Черновой перечень разделов трёх документов',
            minutes: 30,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Составить список юридических вопросов, которые нельзя надёжно решить без актуальной проверки',
            result: 'Список вопросов для официальных источников или юриста',
            minutes: 20,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Определить минимальную модель лицензии Free/Pro и правило восстановления покупки',
            result: 'Одностраничная схема entitlement и restore',
            minutes: 25,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Провести sandbox-покупку после подключения checkout и записать каждый шаг',
            result: 'Пройденный purchase-flow или список конкретных ошибок',
            minutes: 20,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Провести тест возврата и проверить, что доступ меняется ожидаемо',
            result: 'Пройденный refund-flow или воспроизводимая ошибка',
            minutes: 20,
            track: 'payments',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Подготовить реальные каналы публикации и поддержки',
        doneWhen:
            'Есть работающая download-страница, понятный direct-install канал, подготовлен релевантный store submission и определён support/update процесс.',
        actions: [
          _PathActionSeed(
            text: 'Собрать одну download-страницу с обещанием продукта, системными требованиями и кнопкой скачивания',
            result: 'Опубликованный или локально готовый launch-page draft',
            minutes: 30,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Выписать актуальные требования Microsoft Store к текущему типу Windows-пакета',
            result: 'Store submission checklist со ссылками на официальные требования',
            minutes: 30,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Зафиксировать матрицу платформ: Windows сейчас, Android/RuStore и Apple только при появлении соответствующих сборок',
            result: 'Одно решение, какие stores относятся к текущему релизу, а какие отложены',
            minutes: 15,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Создать шаблон release notes из пяти обязательных пунктов',
            result: 'Повторяемый шаблон release notes',
            minutes: 15,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Определить один support-канал и текст, куда пользователь отправляет баг',
            result: 'Рабочий support entry point',
            minutes: 15,
            track: 'operations',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Проверить спрос через наблюдаемое использование, а не вопрос «нравится?»',
        doneWhen:
            'Минимум 5 внешних пользователей самостоятельно установили КАДР, выполнили сценарии, а по каждому есть наблюдения, повторное использование и причины возврата/отказа.',
        actions: [
          _PathActionSeed(
            text: 'Выписать три предполагаемых типа пользователя и по одной проблеме capture для каждого',
            result: 'Три persona/problem гипотезы',
            minutes: 20,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Составить список из десяти конкретных людей, которых можно пригласить в beta',
            result: '10 имён или контактов без абстрактного «найти пользователей»',
            minutes: 20,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Написать одно короткое приглашение без подсказки, какую функцию тестер должен полюбить',
            result: 'Готовый текст beta-приглашения',
            minutes: 15,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Отправить beta-приглашение первым пяти людям из списка',
            result: '5 реально отправленных приглашений',
            minutes: 15,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Составить 20-минутный сценарий наблюдения: install, capture, edit, share/save без обучения',
            result: 'Один неизменяемый test script для первых пяти пользователей',
            minutes: 25,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Провести наблюдение с пользователем №1 и записать факты, а не интерпретации',
            result: 'Одна карточка наблюдения с проблемами и неожиданными сценариями',
            minutes: 30,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Провести наблюдение с пользователем №2 и записать факты, а не интерпретации',
            result: 'Вторая карточка наблюдения',
            minutes: 30,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Через три дня спросить первых тестеров, пользовались ли они КАДР без напоминания',
            result: 'Факт повторного использования по каждому доступному тестеру',
            minutes: 20,
            track: 'demand',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Проверить платную ценность на работающем checkout',
        doneWhen:
            'Есть хотя бы одна реальная попытка купить выбранную Pro-ценность; результат покупки или отказа разобран по фактам.',
        actions: [
          _PathActionSeed(
            text: 'Выписать три функции, которыми beta-пользователи реально пользовались повторно',
            result: 'Три кандидата на Pro, основанные на использовании',
            minutes: 15,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Выбрать одну Pro-гипотезу и записать, какую проблему она решает лучше Free',
            result: 'Одна тестируемая платная гипотеза',
            minutes: 20,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Установить одну тестовую цену и проверить её отображение в checkout',
            result: 'Рабочая цена в реальном или production-like checkout',
            minutes: 15,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Предложить Pro одному активному beta-пользователю и не объяснять цену после отправки',
            result: 'Факт покупки или конкретный отказ первого пользователя',
            minutes: 10,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Задать некупившему пользователю три вопроса о причине отказа и записать ответы дословно',
            result: 'Причина отказа без домысла',
            minutes: 20,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Проверить письмо/экран после успешной оплаты и путь восстановления лицензии',
            result: 'Подтверждённый post-purchase flow',
            minutes: 20,
            track: 'operations',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Сделать выпуск и поддержку повторяемыми',
        doneWhen:
            'Новый релиз, support-запрос, возврат и обновление можно провести по коротким SOP без восстановления процесса из памяти.',
        actions: [
          _PathActionSeed(
            text: 'Записать release SOP от merge до опубликованного installer',
            result: 'Один пошаговый release checklist',
            minutes: 30,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Записать support SOP для bug, payment и refund обращений',
            result: 'Три коротких support маршрута',
            minutes: 25,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Определить три числа, которые проверяются после каждого релиза',
            result: 'Минимальный health-check продукта без большого CRM',
            minutes: 15,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Составить критерии решения Scale / Niche / Reposition после платной проверки',
            result: 'Письменное правило следующего стратегического решения',
            minutes: 20,
            track: 'demand',
          ),
        ],
      ),
    ],
  ),
  _ProjectPathSeed(
    name: 'Игропоиск',
    aliases: ['Игропоиск', 'Igropoisk'],
    goal:
        'Довести Игропоиск до самопополняемого игрового продукта, где данные, страницы, контент и ссылки работают автоматически, сайт индексируется, а спрос и монетизация проверяются на реальном трафике.',
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF6A5ACD),
    requiredTracks: [
      'product',
      'content',
      'reliability',
      'seo',
      'demand',
      'legal',
      'payments',
      'operations',
    ],
    stages: [
      _PathStageSeed(
        title: 'Проверить полный production lifecycle на реальных текущих данных',
        doneWhen:
            'Popular, Releases и News создают/находят правильную игру через Registry, каждая ссылка открывает полноценную production-страницу без ручного вмешательства.',
        actions: [
          _PathActionSeed(
            text: 'Выбрать пять текущих игр из Popular и записать URL их страниц',
            result: 'Контрольный список 5 Popular игр',
            minutes: 10,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Открыть пять Popular страниц и отметить отсутствующие данные или «готовится»',
            result: 'Список lifecycle-проблем по пяти страницам',
            minutes: 25,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Проверить пять game-hashtag ссылок из свежих новостей',
            result: '5 результатов hashtag → game page',
            minutes: 20,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Сравнить ближайшие десять релизов сайта с одним внешним контрольным источником',
            result: 'Список пропусков, дублей или ошибок дат',
            minutes: 30,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Запустить один известный путь создания новой game page и записать каждый автоматический шаг',
            result: 'Фактическая lifecycle-схема или конкретный blocker',
            minutes: 30,
            track: 'operations',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Закрыть качество обзоров, оценок и похожих игр',
        doneWhen:
            'У контрольной выборки нет конфликтующих рейтингов, обзор опирается на понятные источники, русский текст читается естественно, а похожие игры объяснимы.',
        actions: [
          _PathActionSeed(
            text: 'Выбрать три игры с обзором и сверить итоговую оценку с оценками источников',
            result: 'Три арифметические проверки rating pipeline',
            minutes: 20,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Проверить, что в source pool есть минимум пять сильных русскоязычных изданий',
            result: 'Список реально подключённых русскоязычных источников',
            minutes: 20,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Прочитать три абзаца свежего обзора и выписать признаки машинного перевода',
            result: 'Конкретные редакционные дефекты или отметка OK',
            minutes: 15,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Выбрать две игры с плохой похожестью и записать ожидаемые похожие игры вручную',
            result: 'Два gold-set примера для Similar Games',
            minutes: 20,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Сравнить признаки GAME DNA двух gold-set примеров с фактическим ranking',
            result: 'Список конкретных признаков, которые дают неверный вес',
            minutes: 30,
            track: 'product',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Сделать сайт технически индексируемым и юридически аккуратным',
        doneWhen:
            'Ключевые страницы имеют стабильные URL/canonical/meta, sitemap содержит их, а использование контента и изображений имеет зафиксированные правила.',
        actions: [
          _PathActionSeed(
            text: 'Проверить canonical и title на пяти разных game pages',
            result: '5 результатов SEO-проверки',
            minutes: 20,
            track: 'seo',
          ),
          _PathActionSeed(
            text: 'Открыть sitemap и проверить наличие пяти контрольных game URL',
            result: '5 sitemap-проверок',
            minutes: 15,
            track: 'seo',
          ),
          _PathActionSeed(
            text: 'Составить список типов внешнего контента: обложки, скриншоты, оценки, цитаты, пересказ',
            result: 'Content/legal inventory для последующей проверки прав',
            minutes: 20,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Выписать вопросы по лицензиям/цитированию, которые требуют актуальной проверки источников',
            result: 'Юридический research checklist без догадок',
            minutes: 20,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Проверить, какие пользовательские данные сейчас собираются аналитикой и формами',
            result: 'Минимальный privacy data-flow',
            minutes: 20,
            track: 'legal',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Проверить реальный поисковый спрос и повторное использование',
        doneWhen:
            'Есть реальные поисковые показы/переходы и понятны страницы/запросы, которые приводят людей, а не только внутренние просмотры владельца.',
        actions: [
          _PathActionSeed(
            text: 'Проверить, подключены ли Search Console/Яндекс Вебмастер или эквивалентные источники поиска',
            result: 'Статус каждого search-data источника',
            minutes: 15,
            track: 'seo',
          ),
          _PathActionSeed(
            text: 'Записать baseline органических показов и кликов за доступный период',
            result: 'Одна стартовая точка organic traffic',
            minutes: 15,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Выписать десять страниц с максимальными поисковыми показами',
            result: 'Top-10 search entry pages',
            minutes: 15,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Открыть три страницы с показами и проверить, отвечает ли первый экран на запрос',
            result: 'Три наблюдения search intent → page value',
            minutes: 20,
            track: 'demand',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Проверить одну модель монетизации на существующем трафике',
        doneWhen:
            'Одна выбранная модель реально показана пользователям, есть клики/доход либо доказанный нулевой результат и решение о следующей гипотезе.',
        actions: [
          _PathActionSeed(
            text: 'Выписать три монетизации, допустимые для текущих страниц: affiliate, ads, partnership',
            result: 'Три кандидата с местом показа и ожидаемым действием пользователя',
            minutes: 20,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Проверить юридические/платформенные требования выбранного способа монетизации',
            result: 'Список обязательных disclosure/policy шагов',
            minutes: 30,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Выбрать одну монетизацию и один тип страницы для первого теста',
            result: 'Одна ограниченная monetization hypothesis',
            minutes: 15,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Добавить один измеряемый CTA/placement в тестовую выборку страниц',
            result: 'Рабочий измеряемый monetization placement',
            minutes: 30,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Зафиксировать правило, когда тест считается проваленным или заслуживает продолжения',
            result: 'Письменный decision rule до просмотра результата',
            minutes: 15,
            track: 'operations',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Сделать контентный цикл обслуживаемым без постоянного ручного контроля',
        doneWhen:
            'Ошибки источников, page creation и news/release pipelines видны автоматически, а обычный выпуск не требует ежедневного ручного обхода сайта.',
        actions: [
          _PathActionSeed(
            text: 'Выписать пять отказов pipeline, о которых владелец должен узнавать автоматически',
            result: 'Alert checklist',
            minutes: 20,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Определить один ежедневный health-check и один недельный quality-check',
            result: 'Два коротких операционных ритуала',
            minutes: 15,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Проверить, какие ручные действия повторялись минимум три раза за последнюю неделю',
            result: 'Список кандидатов на автоматизацию',
            minutes: 20,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Выбрать один повторяющийся ручной шаг и описать вход, выход и безопасный fallback',
            result: 'Техническое задание на следующую автоматизацию',
            minutes: 25,
            track: 'operations',
          ),
        ],
      ),
    ],
  ),
  _ProjectPathSeed(
    name: 'GOLOS',
    aliases: ['GOLOS', 'Golos', 'Голос'],
    goal:
        'Довести GOLOS до надёжного voice+typing продукта с простым installer, понятной приватностью, рабочей дистрибуцией и платной ценностью, подтверждённой реальным использованием.',
    icon: Icons.mic_rounded,
    color: Color(0xFF00897B),
    requiredTracks: [
      'product',
      'reliability',
      'privacy',
      'distribution',
      'demand',
      'payments',
      'legal',
      'operations',
    ],
    stages: [
      _PathStageSeed(
        title: 'Восстановить гарантированно рабочий Parakeet pipeline',
        doneWhen:
            'Чистая установка загружает нужную GGUF, warm session создаётся, 5 последовательных диктовок возвращают текст, а отсутствие модели даёт явную ошибку.',
        actions: [
          _PathActionSeed(
            text: 'Проверить наличие GGUF и installed.json в текущей models/parakeet папке',
            result: 'Точный статус двух обязательных файлов',
            minutes: 10,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Запустить одну диктовку и записать TRANSCRIBE_MS и финальный результат',
            result: 'Один фактический inference trace',
            minutes: 10,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Проверить downloader на сценарии отсутствующей модели и записать точку отказа',
            result: 'Воспроизводимый download/install gap',
            minutes: 20,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Проверить, что inference error показывается пользователю вместо final_empty',
            result: 'UI-результат ошибки или конкретный blocker',
            minutes: 15,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Сделать пять диктовок подряд по 5–10 секунд и записать результат каждой',
            result: '5-run stability table',
            minutes: 20,
            track: 'reliability',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Закрыть desktop UX, installer и приватность',
        doneWhen:
            'Hotkey/overlay/insertion/RU-EN/light-dark работают после clean install, пользователь понимает, где обрабатывается голос и какие данные сохраняются.',
        actions: [
          _PathActionSeed(
            text: 'Проверить hotkey → запись → вставка текста в трёх разных приложениях',
            result: 'Три end-to-end результата',
            minutes: 20,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Проверить light/dark и RU/EN переключение после перезапуска приложения',
            result: 'Persistence check четырёх комбинаций',
            minutes: 15,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Проверить dropdown-слои на каждом экране, где есть выбор языка или модели',
            result: 'Список z-index проблем или отметка OK',
            minutes: 20,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Составить карту: аудио, текст, логи и модели — что хранится и куда передаётся',
            result: 'Privacy data-flow GOLOS',
            minutes: 25,
            track: 'privacy',
          ),
          _PathActionSeed(
            text: 'Проверить clean install и uninstall на отдельном Windows-профиле',
            result: 'Install/uninstall checklist',
            minutes: 30,
            track: 'distribution',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Подготовить продажу и публикацию GOLOS',
        doneWhen:
            'Определены seller/payment/license правила, подготовлены документы и checkout, есть рабочий direct download и релевантный store plan.',
        actions: [
          _PathActionSeed(
            text: 'Зафиксировать продавца GOLOS и первые страны продаж',
            result: 'Seller + launch geography',
            minutes: 15,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Сравнить два доступных способа checkout по налогам, refund и лицензиям',
            result: 'Выбранный кандидат для тестовой интеграции',
            minutes: 30,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Составить структуру Privacy, Terms/EULA и Refund Policy на основе data-flow',
            result: 'Документированный legal checklist',
            minutes: 30,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Определить Free/Pro entitlement и способ восстановления покупки',
            result: 'Минимальная license схема',
            minutes: 20,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Выписать требования Microsoft Store к текущему Windows package GOLOS',
            result: 'Актуальный store checklist',
            minutes: 30,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Провести test purchase и test refund после подключения checkout',
            result: 'Два записанных end-to-end payment результата',
            minutes: 30,
            track: 'payments',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Проверить, есть ли регулярная потребность в GOLOS',
        doneWhen:
            '5 внешних людей установили GOLOS и минимум часть из них использует диктовку повторно без напоминания; причины использования и отказа записаны.',
        actions: [
          _PathActionSeed(
            text: 'Выписать три ситуации, где voice typing должен быть лучше обычной печати',
            result: 'Три use-case гипотезы',
            minutes: 15,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Составить список десяти потенциальных тестеров с разными типами работы',
            result: '10 конкретных кандидатов',
            minutes: 20,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Отправить приглашение первым пяти тестерам с одним install-link',
            result: '5 отправленных приглашений',
            minutes: 15,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Провести 20-минутный тест с пользователем №1: установка, hotkey, три диктовки',
            result: 'Карточка наблюдения №1',
            minutes: 30,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Через три дня спросить тестеров, сколько раз они реально использовали GOLOS',
            result: 'Повторное использование по доступным тестерам',
            minutes: 20,
            track: 'demand',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Проверить одну платную ценность GOLOS',
        doneWhen:
            'Одна Pro-гипотеза предложена активным пользователям через рабочий checkout, есть покупка или конкретные причины отказа.',
        actions: [
          _PathActionSeed(
            text: 'Выписать три функции, которые активные тестеры просили или использовали чаще всего',
            result: 'Три data-based Pro кандидата',
            minutes: 15,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Выбрать одну Pro-гипотезу и сформулировать её в одном предложении',
            result: 'Один monetization experiment',
            minutes: 15,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Настроить одну тестовую цену и проверить checkout со своей тестовой учётной записью',
            result: 'Рабочий checkout с ценой',
            minutes: 20,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Предложить Pro первому активному пользователю и записать реакцию без убеждения',
            result: 'Покупка или причина отказа №1',
            minutes: 10,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Обновить решение Scale/Niche/Pause на основании фактического платного теста',
            result: 'Следующее стратегическое решение с причиной',
            minutes: 20,
            track: 'operations',
          ),
        ],
      ),
    ],
  ),
  _ProjectPathSeed(
    name: 'LIFE OS',
    aliases: ['LIFE OS', 'Life OS', 'LIFEOS'],
    goal:
        'Сделать LIFE OS постоянной памятью целей и исполнимых планов: от долгосрочного пути проекта до конкретного действия на день, без зависимости от памяти конкретного AI-чата.',
    icon: Icons.hub_rounded,
    color: Color(0xFF3949AB),
    requiredTracks: [
      'product',
      'reliability',
      'privacy',
      'validation',
      'operations',
    ],
    stages: [
      _PathStageSeed(
        title: 'Довести Paths до исполнимого формата',
        doneWhen:
            'Каждый активный проект имеет цель, этапы с Definition of Done и действия ≤30 минут с ожидаемым результатом; валидатор показывает слепые зоны.',
        actions: [
          _PathActionSeed(
            text: 'Заменить плоские этапы Path структурой Stage → Done When → Actions',
            result: 'Новая структура хранится и редактируется в LIFE OS',
            minutes: 30,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Добавить обязательную оценку времени 1–30 минут для каждого action',
            result: 'Невалидные длинные действия видны пользователю',
            minutes: 20,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Добавить ожидаемый результат для каждого action и проверку пустого результата',
            result: 'Vague action без output помечается как непроработанный',
            minutes: 20,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Добавить coverage-аудит обязательных областей проекта',
            result: 'Видимый список покрытых и пропущенных областей',
            minutes: 30,
            track: 'validation',
          ),
          _PathActionSeed(
            text: 'Проверить миграцию текущих десяти bootstrap Paths без дублей категорий',
            result: '10 проектов открываются с V2-планами или отмеченными legacy gaps',
            minutes: 25,
            track: 'reliability',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Связать Path actions с существующим Daily Planner',
        doneWhen:
            'Из готового action можно создать/запланировать обычную задачу, а выполнение дневной задачи возвращается в Path без дублирования смысла.',
        actions: [
          _PathActionSeed(
            text: 'Записать, какие поля Daily Planner нужны для action: title, category, duration, date и source id',
            result: 'Минимальный contract Path → Planner',
            minutes: 20,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Проверить текущий create-plan API и отметить, как передать точную duration без обходных строк',
            result: 'Один безопасный технический путь интеграции',
            minutes: 25,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Добавить source Path/action id в создаваемую planner-задачу без новой CRM-сущности',
            result: 'Однозначная связь задачи с action',
            minutes: 30,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Проверить сценарий action → today → complete → Path на одной тестовой задаче',
            result: 'Один end-to-end execution test',
            minutes: 20,
            track: 'validation',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Подключить AI как читателя и редактора постоянной памяти',
        doneWhen:
            'AI может прочитать цель/Path/выполненные actions, предложить изменение и записать его только по разрешённым правилам.',
        actions: [
          _PathActionSeed(
            text: 'Выписать минимальные AI tools: read paths, propose action, complete action, revise stage',
            result: 'Tool contract v1',
            minutes: 20,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Разделить AI-операции на auto и require-confirmation',
            result: 'Permission matrix',
            minutes: 20,
            track: 'privacy',
          ),
          _PathActionSeed(
            text: 'Определить, какие данные LIFE OS никогда не отправляет модели без явного разрешения',
            result: 'AI privacy boundary',
            minutes: 20,
            track: 'privacy',
          ),
          _PathActionSeed(
            text: 'Сделать один read-only AI запрос по KADR Path и сравнить ответ с базой',
            result: 'Проверка, что AI продолжает план, а не придумывает его заново',
            minutes: 30,
            track: 'validation',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Проверить систему на реальном ежедневном использовании',
        doneWhen:
            'Минимум 14 дней планы реально используются, а проблемы системы выявлены по фактам, а не по дизайну в вакууме.',
        actions: [
          _PathActionSeed(
            text: 'Каждый вечер отметить, какие Path actions реально попали в день, в течение первых семи дней',
            result: '7 записей plan-vs-actual',
            minutes: 10,
            track: 'validation',
          ),
          _PathActionSeed(
            text: 'После первой недели выписать пять причин, почему action не выполнялся',
            result: 'Топ причин несрабатывания системы',
            minutes: 20,
            track: 'validation',
          ),
          _PathActionSeed(
            text: 'Проверить backup/sync Path данных на втором устройстве или браузере',
            result: 'Факт восстановления Path из backend',
            minutes: 20,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Удалить одно правило планирования, которое не использовалось за 14 дней',
            result: 'Система стала проще на основании использования',
            minutes: 15,
            track: 'operations',
          ),
        ],
      ),
    ],
  ),
  _ProjectPathSeed(
    name: 'Atozed / IntraWeb17',
    aliases: ['Atozed / IntraWeb17', 'Atozed', 'IntraWeb17', 'IntraWeb 17', 'IW17', 'IntraWeb'],
    goal:
        'Стабильно обслуживать текущих клиентов Atozed и одновременно довести IntraWeb17 до запуска с повторяемой системой beta, CMS/content, distribution и продаж.',
    icon: Icons.language_rounded,
    color: Color(0xFF1976D2),
    requiredTracks: [
      'operations',
      'product',
      'content',
      'distribution',
      'sales',
      'legal',
      'payments',
      'validation',
    ],
    stages: [
      _PathStageSeed(
        title: 'Сделать ежедневный Atozed Operations контур предсказуемым',
        doneWhen:
            'Почта, лицензии, платежные вопросы и клиентские ответы проходят по короткому ежедневному процессу без забытых обращений.',
        actions: [
          _PathActionSeed(
            text: 'Открыть входящие Atozed и выписать только письма, требующие моего действия',
            result: 'Короткий action-list по текущей почте',
            minutes: 15,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Ответить на самый срочный клиентский вопрос из action-list',
            result: 'Отправленный ответ или зафиксированный blocker',
            minutes: 20,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Проверить покупки/лицензии, которые ждут выдачи или исправления',
            result: 'Список незакрытых license actions',
            minutes: 10,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Оформить одну ожидающую лицензию полностью и зафиксировать номер/покупателя',
            result: 'Одна закрытая license operation',
            minutes: 15,
            track: 'operations',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Свести IntraWeb17 beta и CMS с Артёмом в один launch sequence',
        doneWhen:
            'Есть один список launch blockers/owners, CMS выполняет согласованный минимальный цикл, а beta feedback приходит в единый backlog.',
        actions: [
          _PathActionSeed(
            text: 'Выписать текущие IW17 launch blockers из последних обсуждений одним списком',
            result: 'Launch blocker list',
            minutes: 20,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Отметить владельца каждого blocker: я, Артём, Alexandre/Chad или другой',
            result: 'Owner у каждого активного blocker',
            minutes: 15,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Записать один минимальный CMS flow от исходного материала до опубликованного канала',
            result: 'CMS happy-path v1',
            minutes: 20,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Сверить с Артёмом один текущий CMS blocker и записать следующий технический шаг',
            result: 'Один согласованный next action CMS',
            minutes: 20,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Создать один шаблон beta feedback с полями build, scenario, expected, actual',
            result: 'Повторяемая beta feedback форма',
            minutes: 15,
            track: 'validation',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Подготовить launch content, distribution и юридически корректный sales flow',
        doneWhen:
            'К релизу есть готовые страницы/материалы, понятные каналы публикации, актуальные условия лицензирования и рабочий payment/vendor flow.',
        actions: [
          _PathActionSeed(
            text: 'Выписать обязательные launch assets: landing, release note, docs, beta story, email',
            result: 'Launch content checklist',
            minutes: 20,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Назначить один основной канал и два вторичных канала для первого release message',
            result: 'Distribution sequence v1',
            minutes: 15,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Проверить текущий Paddle/vendor-of-record flow для IW17 и выписать отличия от IW16',
            result: 'Список payment/legal gaps нового продукта',
            minutes: 30,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Проверить, какие Terms/license формулировки надо обновить именно для IW17',
            result: 'Legal update checklist',
            minutes: 30,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Собрать один реальный beta кейс в формате проблема → результат → цитата',
            result: 'Один launch-ready proof point',
            minutes: 30,
            track: 'sales',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Проверить, какие каналы реально приводят beta и продажи',
        doneWhen:
            'Для первых лидов/продаж можно назвать источник, а CMS/content решения меняются по фактам, а не по количеству публикаций.',
        actions: [
          _PathActionSeed(
            text: 'Добавить один source label к каждому новому beta lead на тестовый период',
            result: 'Source attribution для новых beta лидов',
            minutes: 15,
            track: 'sales',
          ),
          _PathActionSeed(
            text: 'Выписать первые пять beta лидов и фактический источник каждого',
            result: 'Таблица 5 lead sources',
            minutes: 15,
            track: 'validation',
          ),
          _PathActionSeed(
            text: 'Сравнить один CMS-канал по затратам времени и полученным реакциям/лидам',
            result: 'Одно channel effectiveness observation',
            minutes: 20,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Выбрать одну публикацию/канал, который надо повторить или прекратить',
            result: 'Одно data-based distribution decision',
            minutes: 15,
            track: 'operations',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Сделать мой вклад в IW17 измеримым и обсуждаемым как отдельная ценность',
        doneWhen:
            'Есть конкретные результаты launch/content/sales, которые можно показать и использовать для разговора о роли или мотивации без выдуманного revenue forecast.',
        actions: [
          _PathActionSeed(
            text: 'Выписать пять результатов IW17, которые напрямую связаны с моей работой',
            result: 'Evidence list моей роли',
            minutes: 20,
            track: 'sales',
          ),
          _PathActionSeed(
            text: 'Собрать фактические продажи/лиды, связанные с этими результатами',
            result: 'Evidence of commercial contribution',
            minutes: 20,
            track: 'sales',
          ),
          _PathActionSeed(
            text: 'Сформулировать одну реалистичную модель дополнительной мотивации для обсуждения',
            result: 'Один compensation proposal draft',
            minutes: 20,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Подготовить короткий разговорный outline: результат → ценность → предложение',
            result: 'Готовая структура разговора',
            minutes: 15,
            track: 'operations',
          ),
        ],
      ),
    ],
  ),
  _ProjectPathSeed(
    name: 'Etnika Studio',
    aliases: ['Etnika Studio', 'Etnika', 'ЭТНИКА', 'Этника'],
    goal:
        'Сделать мою часть участия в Etnika прозрачной и системной: понимать реальную экономику, не терять заявки, видеть работающие каналы и сокращать ручное обслуживание.',
    icon: Icons.palette_rounded,
    color: Color(0xFF8E5A4A),
    requiredTracks: [
      'finance',
      'demand',
      'distribution',
      'legal',
      'reliability',
      'operations',
    ],
    stages: [
      _PathStageSeed(
        title: 'Зафиксировать реальную экономику и мою долю',
        doneWhen:
            'Для одного полного месяца известны выручка, расходы, чистая прибыль, 20% пул мне+Егору и фактическая моя доля.',
        actions: [
          _PathActionSeed(
            text: 'Выписать все статьи дохода Etnika за последний закрытый месяц',
            result: 'Список доходов месяца',
            minutes: 20,
            track: 'finance',
          ),
          _PathActionSeed(
            text: 'Выписать все известные операционные расходы того же месяца',
            result: 'Список расходов месяца',
            minutes: 25,
            track: 'finance',
          ),
          _PathActionSeed(
            text: 'Посчитать чистую прибыль по формуле revenue minus expenses',
            result: 'Одна проверяемая цифра net profit',
            minutes: 10,
            track: 'finance',
          ),
          _PathActionSeed(
            text: 'Зафиксировать правило разделения 20% пула между мной и Егором',
            result: 'Письменное правило моей фактической доли',
            minutes: 15,
            track: 'finance',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Довести захват заявок до надёжного и законного контура',
        doneWhen:
            'Тестовые заявки из каждого канала доходят до команды, обязательные поля/согласия понятны, а потеря заявки обнаруживается.',
        actions: [
          _PathActionSeed(
            text: 'Отправить тестовую заявку с сайта и записать, где она появляется у команды',
            result: 'Один end-to-end lead test',
            minutes: 15,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Отправить тестовую заявку через Telegram-контур и записать результат',
            result: 'Второй end-to-end lead test',
            minutes: 15,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Выписать персональные данные, которые собирают формы, и зачем нужно каждое поле',
            result: 'Lead privacy data inventory',
            minutes: 20,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Проверить, где пользователь видит consent/privacy информацию перед отправкой',
            result: 'Список privacy gaps формы',
            minutes: 15,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Добавить способ заметить заявку, которая не дошла в основной канал',
            result: 'Один fallback/alert для потерянной заявки',
            minutes: 30,
            track: 'operations',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Понять, какие каналы действительно приводят продажи',
        doneWhen:
            'Для новых заявок записывается источник и можно связать хотя бы часть заявок с записью/продажей.',
        actions: [
          _PathActionSeed(
            text: 'Определить пять допустимых source labels для текущих каналов',
            result: 'Единый список source labels',
            minutes: 10,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Добавить source к десяти последним известным заявкам вручную',
            result: '10 размеченных лидов для baseline',
            minutes: 20,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Отметить по этим десяти лидам, где была фактическая запись/продажа',
            result: 'Первый lead-to-sale sample',
            minutes: 20,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Выбрать один канал, который нужно усилить или остановить по sample',
            result: 'Одно marketing decision с причиной',
            minutes: 15,
            track: 'distribution',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Снизить ручную нагрузку моей зоны ответственности',
        doneWhen:
            'Повторяющиеся операции сайта/заявок/отчётности имеют SOP или автоматизацию, а мой контроль сводится к исключениям.',
        actions: [
          _PathActionSeed(
            text: 'Выписать пять операций Etnika, которые я повторял минимум три раза',
            result: 'Список automation/SOP кандидатов',
            minutes: 20,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Для самого частого шага записать trigger, input, output и failure case',
            result: 'Automation-ready описание одного процесса',
            minutes: 20,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Решить для этого процесса: SOP, no-code automation или code automation',
            result: 'Один выбранный способ сокращения ручной работы',
            minutes: 10,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Проверить новый процесс на одной реальной заявке или отчёте',
            result: 'Один production-like test',
            minutes: 20,
            track: 'reliability',
          ),
        ],
      ),
    ],
  ),
  _ProjectPathSeed(
    name: 'Russian Culture Club',
    aliases: ['Russian Culture Club', 'RCC', 'Русский культурный клуб'],
    goal:
        'Сделать RCC устойчивым сообществом, где события, люди, контент и при необходимости монетизация не зависят от одного человека и не перегружают Кристину.',
    icon: Icons.groups_rounded,
    color: Color(0xFFC62828),
    requiredTracks: [
      'people',
      'operations',
      'demand',
      'distribution',
      'legal',
      'payments',
    ],
    stages: [
      _PathStageSeed(
        title: 'Пересобрать операционную модель после ухода Алисы',
        doneWhen:
            'По каждому регулярному формату понятно, продолжаем ли его, кто владелец и что сейчас держится только на Кристине.',
        actions: [
          _PathActionSeed(
            text: 'Выписать все форматы RCC, которые проходили за последние четыре недели',
            result: 'Список актуальных event formats',
            minutes: 15,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Отметить у каждого формата текущего фактического организатора',
            result: 'Owner map событий',
            minutes: 15,
            track: 'people',
          ),
          _PathActionSeed(
            text: 'Отметить задачи, которые сейчас делает только Кристина',
            result: 'Single-point-of-failure список',
            minutes: 15,
            track: 'people',
          ),
          _PathActionSeed(
            text: 'Выбрать два формата, которые RCC точно сохраняет ближайший цикл',
            result: 'Два приоритетных event templates',
            minutes: 10,
            track: 'operations',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Сделать два события повторяемыми и безопасными',
        doneWhen:
            'Два формата имеют checklist подготовки/проведения/закрытия, понятные правила поведения/ответственности и могут быть проведены другим ведущим.',
        actions: [
          _PathActionSeed(
            text: 'Записать 30-минутный pre-event checklist для первого формата',
            result: 'Повторяемый checklist №1',
            minutes: 30,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Записать post-event checklist для фото, feedback и следующего анонса',
            result: 'Post-event checklist',
            minutes: 20,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Выписать вопросы безопасности/ответственности, зависящие от площадки и типа события',
            result: 'Legal/safety research list',
            minutes: 20,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Передать checklist другому человеку и попросить отметить непонятные пункты',
            result: 'External readability feedback',
            minutes: 20,
            track: 'people',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Снять зависимость от одного организатора',
        doneWhen:
            'Есть минимум два дополнительных человека, каждый реально провёл или подготовил часть события без ручного ведения каждого шага.',
        actions: [
          _PathActionSeed(
            text: 'Составить список десяти активных участников, которым можно предложить микро-роль',
            result: '10 volunteer candidates',
            minutes: 20,
            track: 'people',
          ),
          _PathActionSeed(
            text: 'Определить три микро-роли по 30–60 минут: host, check-in, content или аналогичные',
            result: 'Три понятные volunteer roles',
            minutes: 20,
            track: 'people',
          ),
          _PathActionSeed(
            text: 'Отправить персональное предложение роли первым трём кандидатам',
            result: '3 отправленных предложения',
            minutes: 15,
            track: 'people',
          ),
          _PathActionSeed(
            text: 'Передать одну роль согласившемуся человеку на ближайшем событии',
            result: 'Одна реально делегированная операция',
            minutes: 15,
            track: 'operations',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Построить повторяемый контент и приток новых людей',
        doneWhen:
            'У каждого события есть простой content loop, а источник новых участников хотя бы частично известен.',
        actions: [
          _PathActionSeed(
            text: 'Создать один шаблон анонса для Telegram/Instagram без переписывания с нуля',
            result: 'Reusable event announcement template',
            minutes: 20,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Создать один post-event шаблон из фото, короткого текста и следующего CTA',
            result: 'Reusable recap template',
            minutes: 20,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Добавить один простой вопрос «откуда узнали» к регистрации или знакомству',
            result: 'Source signal для новых участников',
            minutes: 15,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Разметить источник у десяти новых/недавних участников',
            result: 'Первый sample acquisition sources',
            minutes: 20,
            track: 'demand',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Проверить мягкую монетизацию без разрушения сообщества',
        doneWhen:
            'Один платный/партнёрский формат проверен на реальном событии, правила оплаты/возврата понятны, реакция сообщества записана.',
        actions: [
          _PathActionSeed(
            text: 'Выписать три формата, за которые логично брать деньги отдельно от обычных встреч',
            result: 'Три monetization candidates',
            minutes: 20,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Выбрать один формат и посчитать прямые расходы на одного участника',
            result: 'Минимальная экономика одного paid event',
            minutes: 20,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Выписать обязательные правила оплаты, отмены и ответственности для этого события',
            result: 'Legal/payment checklist теста',
            minutes: 20,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Предложить формат небольшой группе активных участников до публичного запуска',
            result: 'Первичная реакция на цену/формат',
            minutes: 15,
            track: 'demand',
          ),
        ],
      ),
    ],
  ),
  _ProjectPathSeed(
    name: 'FLOW',
    aliases: ['FLOW', 'Flow'],
    goal:
        'Превратить FLOW из обучения в практический навык дистрибуции: регулярно публиковать, измерять переходы/affiliate результат и переносить рабочие механики на реальные проекты.',
    icon: Icons.campaign_rounded,
    color: Color(0xFFEF6C00),
    requiredTracks: [
      'learning',
      'content',
      'distribution',
      'validation',
      'legal',
      'payments',
    ],
    stages: [
      _PathStageSeed(
        title: 'Вытащить из курса только материал для первого реального запуска',
        doneWhen:
            'Определён один acquisition-канал и есть конкретный publish/test цикл; прохождение курса больше не является самоцелью.',
        actions: [
          _PathActionSeed(
            text: 'Открыть оглавление текущего блока FLOW и отметить уроки, нужные для первого publish cycle',
            result: 'Shortlist обязательных уроков',
            minutes: 15,
            track: 'learning',
          ),
          _PathActionSeed(
            text: 'Выбрать один канал для первого цикла и записать причину выбора',
            result: 'Один channel hypothesis',
            minutes: 15,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Записать минимальный результат обучения, после которого надо публиковать, а не учиться дальше',
            result: 'Stop-learning trigger',
            minutes: 10,
            track: 'learning',
          ),
          _PathActionSeed(
            text: 'Составить список из пяти тем, связанных с реальным IW17/КАДР/Игропоиск',
            result: '5 applied content ideas',
            minutes: 20,
            track: 'content',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Запустить первый измеряемый content/referral цикл',
        doneWhen:
            'Опубликовано несколько единиц контента с измеряемыми ссылками/CTA и известно, были ли реальные переходы.',
        actions: [
          _PathActionSeed(
            text: 'Создать один контент-материал по первой выбранной теме',
            result: 'Один готовый draft',
            minutes: 30,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Добавить один измеряемый CTA или referral link с понятной целью',
            result: 'Trackable CTA в материале',
            minutes: 10,
            track: 'validation',
          ),
          _PathActionSeed(
            text: 'Проверить обязательный affiliate disclosure для выбранной площадки/программы',
            result: 'Compliance note для публикации',
            minutes: 20,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Опубликовать материал в выбранном канале и сохранить URL/дату',
            result: 'Одна измеряемая публикация',
            minutes: 15,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Через согласованный интервал записать просмотры, клики и referral события публикации',
            result: 'Первый result snapshot',
            minutes: 15,
            track: 'validation',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Получить первый подтверждённый affiliate результат',
        doneWhen:
            'Есть первая подтверждённая конверсия/доход либо достаточно данных, чтобы изменить канал/offer осознанно.',
        actions: [
          _PathActionSeed(
            text: 'Выписать три публикации с наибольшими кликами или удержанием',
            result: 'Top-3 content evidence',
            minutes: 15,
            track: 'validation',
          ),
          _PathActionSeed(
            text: 'Выбрать одну общую характеристику top-3 и сформулировать следующую гипотезу',
            result: 'Одна content hypothesis',
            minutes: 15,
            track: 'validation',
          ),
          _PathActionSeed(
            text: 'Создать следующий материал как контролируемое повторение этой гипотезы',
            result: 'Один comparable content test',
            minutes: 30,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Проверить dashboard affiliate программы и записать подтверждённый доход/конверсию',
            result: 'Фактический affiliate result без оценки на глаз',
            minutes: 10,
            track: 'payments',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Перенести рабочий acquisition-механизм на собственный проект',
        doneWhen:
            'Один доказанный формат/канал применён к IW17, КАДР или Игропоиск и его результат сравним с исходным.',
        actions: [
          _PathActionSeed(
            text: 'Выбрать один собственный проект, где audience intent совпадает с доказанным форматом',
            result: 'Один target project',
            minutes: 15,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Адаптировать один успешный content pattern под target project без копирования текста',
            result: 'Один project-specific draft',
            minutes: 30,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Опубликовать адаптацию с тем же способом измерения',
            result: 'Comparable acquisition test',
            minutes: 15,
            track: 'distribution',
          ),
          _PathActionSeed(
            text: 'Сравнить исходный и project test по одному выбранному показателю',
            result: 'Решение repeat/change/stop',
            minutes: 15,
            track: 'validation',
          ),
        ],
      ),
    ],
  ),
  _ProjectPathSeed(
    name: 'Price Reporter',
    aliases: ['Price Reporter'],
    goal:
        'Сохранять Price Reporter как надёжную финансовую базу, повышая ценность моей работы и сокращая ручную рутину без риска для GSA/FCP/compliance качества.',
    icon: Icons.work_rounded,
    color: Color(0xFF455A64),
    requiredTracks: [
      'finance',
      'operations',
      'reliability',
      'legal',
      'automation',
      'career',
    ],
    stages: [
      _PathStageSeed(
        title: 'Зафиксировать фактическую ценность дохода и нагрузки',
        doneWhen:
            'Известен фактический средний доход с бонусами и основные типы работы/времени, без приблизительных цифр.',
        actions: [
          _PathActionSeed(
            text: 'Выписать 12 последних фиксированных выплат Price Reporter',
            result: '12-month fixed income list',
            minutes: 15,
            track: 'finance',
          ),
          _PathActionSeed(
            text: 'Выписать все квартальные бонусы за тот же период',
            result: 'Bonus history за 12 месяцев',
            minutes: 15,
            track: 'finance',
          ),
          _PathActionSeed(
            text: 'Посчитать средний месячный total income из этих фактических выплат',
            result: 'Одна реальная monthly average цифра',
            minutes: 10,
            track: 'finance',
          ),
          _PathActionSeed(
            text: 'За один рабочий день отметить крупными блоками, куда ушли часы 16:00–00:00',
            result: 'Один workload sample',
            minutes: 10,
            track: 'operations',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Выделить безопасную автоматизацию повторяющихся операций',
        doneWhen:
            'Есть список повторяющихся процессов, и один низкорисковый процесс автоматизирован с контрольной проверкой результата.',
        actions: [
          _PathActionSeed(
            text: 'Выписать пять операций GSA/FCP/pricing, которые повторялись минимум три раза',
            result: 'Automation candidate list',
            minutes: 20,
            track: 'automation',
          ),
          _PathActionSeed(
            text: 'Для каждого кандидата отметить риск ошибки: low, medium или compliance-critical',
            result: 'Risk label у пяти процессов',
            minutes: 15,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Выбрать один low-risk процесс и записать вход, выход и ручную проверку',
            result: 'Safe automation spec',
            minutes: 20,
            track: 'reliability',
          ),
          _PathActionSeed(
            text: 'Прогнать автоматизированный процесс на одном старом кейсе и сравнить с эталоном',
            result: 'One regression comparison',
            minutes: 25,
            track: 'reliability',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Собрать доказательства ценности роли',
        doneWhen:
            'Есть конкретные кейсы client/compliance/time impact, которые можно показать при разговоре о роли или компенсации.',
        actions: [
          _PathActionSeed(
            text: 'Выписать три сложных кейса, где моя экспертиза предотвратила ошибку или задержку',
            result: '3 value cases',
            minutes: 20,
            track: 'career',
          ),
          _PathActionSeed(
            text: 'Для каждого кейса записать проблему, моё действие и фактический результат',
            result: 'STAR-like evidence для 3 кейсов',
            minutes: 30,
            track: 'career',
          ),
          _PathActionSeed(
            text: 'Выписать один процесс, где автоматизация сократила моё время без потери качества',
            result: 'One efficiency proof',
            minutes: 15,
            track: 'automation',
          ),
          _PathActionSeed(
            text: 'Собрать эти четыре примера в одностраничный outline',
            result: 'Compensation/value discussion brief',
            minutes: 25,
            track: 'career',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Снизить операционную уязвимость без риска текущему доходу',
        doneWhen:
            'Критические процессы документированы, а уменьшение зависимости от Price Reporter происходит только при наличии подтверждённых альтернативных доходов.',
        actions: [
          _PathActionSeed(
            text: 'Выписать три PR-процесса, которые нельзя терять при отпуске или болезни',
            result: 'Critical continuity list',
            minutes: 15,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Создать короткий SOP для самого критичного процесса',
            result: 'One continuity SOP',
            minutes: 30,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Зафиксировать правило, при каком подтверждённом альтернативном доходе можно сокращать зависимость',
            result: 'Письменный financial safety rule',
            minutes: 15,
            track: 'finance',
          ),
          _PathActionSeed(
            text: 'Сверить это правило с фактическим текущим среднемесячным доходом',
            result: 'Текущий gap до safety threshold',
            minutes: 10,
            track: 'finance',
          ),
        ],
      ),
    ],
  ),
  _ProjectPathSeed(
    name: 'Правители России',
    aliases: ['Правители России', 'Rulers of Russia', 'Praviteli Rossii'],
    goal:
        'Создать проверяемый evergreen-сайт о правителях России, где источники и права на контент определены до автоматизации, а масштабирование начинается только после первых признаков реального спроса.',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF6D4C41),
    requiredTracks: [
      'content',
      'legal',
      'product',
      'seo',
      'demand',
      'operations',
      'payments',
    ],
    stages: [
      _PathStageSeed(
        title: 'Зафиксировать концепцию, источники и границы проекта до разработки',
        doneWhen:
            'Есть одна эталонная структура страницы, стандарт источников/фактчекинга и список правовых вопросов по изображениям/цитатам.',
        actions: [
          _PathActionSeed(
            text: 'Выписать пять вопросов, на которые должна отвечать страница любого правителя',
            result: 'Core content schema',
            minutes: 15,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Выбрать три типа авторитетных источников для фактов и дат',
            result: 'Source hierarchy v1',
            minutes: 20,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Выписать правила, когда факт считается спорным и требует нескольких источников',
            result: 'Fact-check rule',
            minutes: 15,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Составить список типов изображений/цитат и вопросов по правам на них',
            result: 'Copyright research checklist',
            minutes: 20,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Записать критерий, при котором проект переходит из incubator в active development',
            result: 'Explicit start gate',
            minutes: 15,
            track: 'operations',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Собрать один production-quality прототип страницы',
        doneWhen:
            'Одна страница правителя проходит источник/факт/UX/SEO проверку и может служить шаблоном, а не разовой статьёй.',
        actions: [
          _PathActionSeed(
            text: 'Выбрать одного правителя для эталонной страницы и записать причину выбора',
            result: 'One prototype subject',
            minutes: 10,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Собрать факты для пяти core sections только из выбранных source types',
            result: 'Source-backed content notes',
            minutes: 30,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Собрать черновой page layout из этих пяти sections',
            result: 'One page prototype',
            minutes: 30,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Проверить title, headings, canonical и schema needs для прототипа',
            result: 'SEO checklist одной страницы',
            minutes: 20,
            track: 'seo',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Запустить небольшой эталонный набор и проверить индексирование',
        doneWhen:
            'Опубликован ограниченный набор качественных страниц, поисковики видят их, а ошибки качества исправляются до масштабирования.',
        actions: [
          _PathActionSeed(
            text: 'Выбрать ещё четыре страницы для первого набора по разным историческим периодам',
            result: '5-page launch set',
            minutes: 15,
            track: 'content',
          ),
          _PathActionSeed(
            text: 'Создать общий индекс/навигацию для этих пяти страниц',
            result: 'One index page',
            minutes: 30,
            track: 'product',
          ),
          _PathActionSeed(
            text: 'Добавить пять URL в sitemap и проверить доступность без авторизации',
            result: '5 crawlable URLs',
            minutes: 20,
            track: 'seo',
          ),
          _PathActionSeed(
            text: 'Проверить первые indexing/impression данные после доступного интервала',
            result: 'Initial search visibility snapshot',
            minutes: 15,
            track: 'demand',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Масштабировать только доказанную структуру и безопасную автоматизацию',
        doneWhen:
            'CMS автоматизирует повторяемые части без снижения источников/качества, а ручная проверка сосредоточена на спорных фактах.',
        actions: [
          _PathActionSeed(
            text: 'Выписать поля страницы, которые можно заполнять строго структурированными данными',
            result: 'Automation-safe field list',
            minutes: 20,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Выписать поля, где обязателен редакторский или source review',
            result: 'Human-review field list',
            minutes: 15,
            track: 'legal',
          ),
          _PathActionSeed(
            text: 'Автоматизировать один safe field на одной тестовой странице',
            result: 'One controlled CMS automation',
            minutes: 30,
            track: 'operations',
          ),
          _PathActionSeed(
            text: 'Сравнить автоматизированную страницу с эталонной по source/SEO checklist',
            result: 'Quality regression result',
            minutes: 20,
            track: 'content',
          ),
        ],
      ),
      _PathStageSeed(
        title: 'Проверить спрос и только потом монетизацию',
        doneWhen:
            'Есть устойчивые organic impressions/clicks или связанная ценность для RCC, после чего одна монетизация тестируется измеримо.',
        actions: [
          _PathActionSeed(
            text: 'Выписать десять страниц/запросов с наибольшими поисковыми показами',
            result: 'Top search demand list',
            minutes: 15,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Выбрать одну страницу с трафиком и записать user intent одним предложением',
            result: 'One monetizable intent hypothesis',
            minutes: 10,
            track: 'demand',
          ),
          _PathActionSeed(
            text: 'Выписать три monetization options, которые не ухудшают доверие к историческому контенту',
            result: 'Three bounded monetization ideas',
            minutes: 20,
            track: 'payments',
          ),
          _PathActionSeed(
            text: 'Проверить legal/disclosure требования одной выбранной монетизации до внедрения',
            result: 'Compliance checklist выбранного теста',
            minutes: 25,
            track: 'legal',
          ),
        ],
      ),
    ],
  ),
];

String _normalizeExecutableProjectName(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^a-zа-я0-9]+'), '');

_ProjectPathSeed? _seedForCategoryName(String name) {
  final normalized = _normalizeExecutableProjectName(name);
  for (final seed in _executablePortfolioSeeds) {
    if (_normalizeExecutableProjectName(seed.name) == normalized) return seed;
    for (final alias in seed.aliases) {
      if (_normalizeExecutableProjectName(alias) == normalized) return seed;
    }
  }
  return null;
}

int? _findExecutableSeedCategoryId(
  DatabaseService db,
  _ProjectPathSeed seed,
) {
  final wanted = <String>{
    _normalizeExecutableProjectName(seed.name),
    for (final alias in seed.aliases) _normalizeExecutableProjectName(alias),
  };
  for (final pair in db.allCategoryIdPathPairs) {
    final rule = db.getCategoryRuleById(pair.id);
    if (rule == null || rule.isArchived) continue;
    if (wanted.contains(_normalizeExecutableProjectName(rule.name))) {
      return pair.id;
    }
  }
  return null;
}

bool _isExecutablePathRoot(PlanningTask task) {
  final marker = (task.notesPlain ?? '').trim();
  return marker == _lifeOsPathMarkerV1 || marker == _lifeOsPathMarkerV2;
}

bool _isGeneratedV1Path(PlanningTask task) {
  if ((task.notesPlain ?? '').trim() != _lifeOsPathMarkerV1) return false;
  if (task.checklist.isEmpty) return false;
  for (final row in task.checklist) {
    final id = (row['id'] ?? '').toString();
    if (!id.startsWith('portfolio-')) return false;
    if (row['isDone'] == true) return false;
    if ((row['definitionOfDone'] ?? '').toString().trim().isNotEmpty) {
      return false;
    }
  }
  return true;
}

List<Map<String, dynamic>> _seedChecklist(_ProjectPathSeed seed) {
  final slug = _normalizeExecutableProjectName(seed.name);
  return [
    for (var si = 0; si < seed.stages.length; si++)
      <String, dynamic>{
        'type': 'stage',
        'id': 'exec-$slug-stage-${si + 1}',
        'text': seed.stages[si].title,
        'definitionOfDone': seed.stages[si].doneWhen,
        'isDone': false,
        'actions': [
          for (var ai = 0; ai < seed.stages[si].actions.length; ai++)
            <String, dynamic>{
              'id': 'exec-$slug-${si + 1}-${ai + 1}',
              'text': seed.stages[si].actions[ai].text,
              'result': seed.stages[si].actions[ai].result,
              'minutes': seed.stages[si].actions[ai].minutes,
              'track': seed.stages[si].actions[ai].track,
              'isDone': false,
            },
        ],
      },
  ];
}

Future<int?> _ensureExecutableCategory(
  DatabaseService db,
  _ProjectPathSeed seed,
) async {
  final existing = _findExecutableSeedCategoryId(db, seed);
  if (existing != null) return existing;

  final status = db.classifyCategoryDisplayNameInput(seed.name);
  if (status.activeLocalId != null) return status.activeLocalId;
  if (status.archivedPbRowId != null) {
    final restored = await db.restoreArchivedCategory(status.archivedPbRowId!);
    if (restored != null) return restored;
  }

  final created = await db.addNestedCategory(
    null,
    CategoryRule(
      id: db.newId(),
      name: seed.name,
      colorValue: seed.color.toARGB32(),
      iconCodePoint: seed.icon.codePoint,
      isSynced: false,
    ),
  );
  if (created != null) return created;
  await db.refreshCategoryRulesFromServer();
  return _findExecutableSeedCategoryId(db, seed);
}

/// Idempotent v2 bootstrap. Existing manually-authored Paths are never replaced.
/// Only the generated flat V1 seed (all IDs `portfolio-*`, nothing completed)
/// is upgraded automatically to the executable structure.
Future<void> bootstrapExecutablePortfolioPaths() async {
  final prefs = await SharedPreferences.getInstance();
  final db = DatabaseService.instance;
  await db.refreshCategoryRulesFromServer();
  final backlog = await db.fetchBacklogPlans(includeCompleted: true);
  final rootsByCategory = <int, PlanningTask>{};
  for (final task in backlog) {
    if (_isExecutablePathRoot(task)) rootsByCategory.putIfAbsent(task.categoryId, () => task);
  }

  var allSucceeded = true;
  for (final seed in _executablePortfolioSeeds) {
    final categoryId = await _ensureExecutableCategory(db, seed);
    if (categoryId == null) {
      allSucceeded = false;
      continue;
    }
    final existing = rootsByCategory[categoryId];
    if (existing == null) {
      final order = await db.nextBacklogPlanningOrder();
      final ok = await db.addPlanningTask(
        PlanningTask(
          id: 0,
          title: seed.goal,
          categoryId: categoryId,
          isDone: true,
          dateKey: '',
          order: order,
          checklist: _seedChecklist(seed),
          notesPlain: _lifeOsPathMarkerV2,
          isSynced: false,
        ),
      );
      if (!ok) {
        allSucceeded = false;
      }
      continue;
    }

    if (_isGeneratedV1Path(existing)) {
      final ok = await db.updatePlanningTask(
        existing.planRowIdForBackend,
        planBusinessId: existing.planRowId,
        title: seed.goal,
        categoryId: categoryId,
        isDone: true,
        notesPlain: _lifeOsPathMarkerV2,
        checklist: _seedChecklist(seed),
        suppressAppSnack: true,
      );
      if (!ok) allSucceeded = false;
    }
  }

  if (allSucceeded) {
    await prefs.setBool(_portfolioExecutableBootstrapPref, true);
  }
}

class _ExecutablePathAction {
  const _ExecutablePathAction({
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

  _ExecutablePathAction copyWith({
    String? text,
    String? result,
    int? minutes,
    String? track,
    bool? done,
  }) => _ExecutablePathAction(
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

class _ExecutablePathStage {
  const _ExecutablePathStage({
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
  final List<_ExecutablePathAction> actions;

  _ExecutablePathStage copyWith({
    String? title,
    String? doneWhen,
    bool? done,
    List<_ExecutablePathAction>? actions,
  }) => _ExecutablePathStage(
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

List<_ExecutablePathStage> _parseExecutableStages(PlanningTask task) {
  final result = <_ExecutablePathStage>[];
  for (var si = 0; si < task.checklist.length; si++) {
    final row = task.checklist[si];
    if ((row['type'] ?? 'stage').toString() != 'stage') continue;
    final title = (row['text'] ?? '').toString().trim();
    if (title.isEmpty) continue;
    final rawActions = row['actions'];
    final actions = <_ExecutablePathAction>[];
    if (rawActions is List) {
      for (var ai = 0; ai < rawActions.length; ai++) {
        final raw = rawActions[ai];
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final text = (map['text'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        final id = (map['id'] ?? '').toString().trim();
        final minutesRaw = map['minutes'];
        final minutes = minutesRaw is int
            ? minutesRaw
            : int.tryParse(minutesRaw?.toString() ?? '') ?? 0;
        actions.add(
          _ExecutablePathAction(
            id: id.isEmpty ? 'legacy-action-$si-$ai-${text.hashCode}' : id,
            text: text,
            result: (map['result'] ?? '').toString().trim(),
            minutes: minutes,
            track: (map['track'] ?? '').toString().trim(),
            done: map['isDone'] == true,
          ),
        );
      }
    }
    final id = (row['id'] ?? '').toString().trim();
    result.add(
      _ExecutablePathStage(
        id: id.isEmpty ? 'legacy-stage-$si-${title.hashCode}' : id,
        title: title,
        doneWhen: (row['definitionOfDone'] ?? '').toString().trim(),
        done: row['isDone'] == true,
        actions: actions,
      ),
    );
  }
  return result;
}

class _PathValidation {
  const _PathValidation({required this.problems, required this.missingTracks});

  final List<String> problems;
  final List<String> missingTracks;

  bool get ready => problems.isEmpty && missingTracks.isEmpty;
}

const List<String> _genericRequiredTracks = [
  'strategy',
  'execution',
  'validation',
  'risks',
];

_PathValidation _validateExecutablePath(
  PlanningTask task,
  List<String> requiredTracks,
) {
  final stages = _parseExecutableStages(task);
  final problems = <String>[];
  final coveredTracks = <String>{};
  if (stages.isEmpty) problems.add('Нет этапов');

  for (var si = 0; si < stages.length; si++) {
    final stage = stages[si];
    if (stage.done) {
      for (final action in stage.actions) {
        if (action.track.isNotEmpty) coveredTracks.add(action.track);
      }
      continue;
    }
    if (stage.doneWhen.trim().isEmpty) {
      problems.add('Этап ${si + 1}: нет критерия завершения');
    }
    if (stage.actions.isEmpty) {
      problems.add('Этап ${si + 1}: нет конкретных действий');
    }
    for (var ai = 0; ai < stage.actions.length; ai++) {
      final action = stage.actions[ai];
      if (action.track.isNotEmpty) coveredTracks.add(action.track);
      if (action.minutes < 1 || action.minutes > 30) {
        problems.add('Этап ${si + 1}, действие ${ai + 1}: нужно разбить до ≤30 минут');
      }
      if (action.result.trim().isEmpty) {
        problems.add('Этап ${si + 1}, действие ${ai + 1}: не указан ожидаемый результат');
      }
      if (action.text.trim().split(RegExp(r'\s+')).length < 4) {
        problems.add('Этап ${si + 1}, действие ${ai + 1}: формулировка слишком общая');
      }
    }
  }
  final missing = [
    for (final track in requiredTracks)
      if (!coveredTracks.contains(track)) track,
  ];
  return _PathValidation(problems: problems, missingTracks: missing);
}

String _trackLabel(String key, bool ru) {
  if (!ru) {
    return switch (key) {
      'product' => 'Product',
      'reliability' => 'Reliability',
      'demand' => 'Demand',
      'distribution' => 'Distribution',
      'payments' => 'Payments',
      'legal' => 'Legal',
      'operations' => 'Operations',
      'content' => 'Content',
      'seo' => 'SEO',
      'privacy' => 'Privacy',
      'validation' => 'Validation',
      'sales' => 'Sales',
      'finance' => 'Finance',
      'people' => 'People',
      'learning' => 'Learning',
      'automation' => 'Automation',
      'career' => 'Career',
      'strategy' => 'Strategy',
      'execution' => 'Execution',
      'risks' => 'Risks',
      _ => key,
    };
  }
  return switch (key) {
    'product' => 'Продукт',
    'reliability' => 'Надёжность',
    'demand' => 'Спрос',
    'distribution' => 'Дистрибуция',
    'payments' => 'Оплата',
    'legal' => 'Юридическое',
    'operations' => 'Операционка',
    'content' => 'Контент',
    'seo' => 'SEO',
    'privacy' => 'Приватность',
    'validation' => 'Валидация',
    'sales' => 'Продажи',
    'finance' => 'Финансы',
    'people' => 'Люди',
    'learning' => 'Обучение',
    'automation' => 'Автоматизация',
    'career' => 'Карьера',
    'strategy' => 'Стратегия',
    'execution' => 'Исполнение',
    'risks' => 'Риски',
    _ => key,
  };
}

class _ExecutablePathCopy {
  const _ExecutablePathCopy(this.ru);
  final bool ru;

  String get title => ru ? 'Пути проектов' : 'Project paths';
  String get subtitle => ru
      ? 'Этапы → критерий завершения → действия ≤30 минут → ожидаемый результат'
      : 'Stages → done criteria → actions ≤30 min → expected output';
  String get ready => ru ? 'План готов к исполнению' : 'Plan is executable';
  String get notReady => ru ? 'План не готов' : 'Plan needs work';
  String get blindSpots => ru ? 'Проверка слепых зон' : 'Blind-spot audit';
  String get missing => ru ? 'Не покрыто' : 'Missing';
  String get issues => ru ? 'Проблемы плана' : 'Plan issues';
  String get current => ru ? 'Сейчас' : 'Current';
  String get doneWhen => ru ? 'Готово, когда' : 'Done when';
  String get actions => ru ? 'Действия' : 'Actions';
  String get expected => ru ? 'Результат' : 'Output';
  String get addStage => ru ? 'Добавить этап' : 'Add stage';
  String get addAction => ru ? 'Добавить действие' : 'Add action';
  String get editGoal => ru ? 'Изменить цель' : 'Edit goal';
  String get goal => ru ? 'Цель' : 'Goal';
  String get noPath => ru ? 'Путь не создан' : 'Path not created';
  String get createPath => ru ? 'Создать путь' : 'Create path';
  String get saveFailed => ru ? 'Не удалось сохранить.' : 'Could not save.';
  String get bootstrapFailed => ru
      ? 'Не удалось обновить часть стартовых путей. Остальные данные не изменены.'
      : 'Some starter paths could not be upgraded. Other data was preserved.';
  String get dailyRule => ru
      ? 'В ежедневный План должны попадать только действия этого нижнего уровня, а не этапы.'
      : 'Only bottom-level actions may become Daily Planner tasks, never stages.';
}

class ExecutableCategoryPathsPage extends StatefulWidget {
  const ExecutableCategoryPathsPage({super.key});

  @override
  State<ExecutableCategoryPathsPage> createState() =>
      _ExecutableCategoryPathsPageState();
}

class _ExecutableCategoryPathsPageState
    extends State<ExecutableCategoryPathsPage> {
  bool _loading = true;
  String? _error;
  Map<int, PlanningTask> _roots = const <int, PlanningTask>{};

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapAndLoad());
  }

  Future<void> _bootstrapAndLoad() async {
    try {
      await bootstrapExecutablePortfolioPaths();
    } catch (e) {
      _error = e.toString();
    }
    await _load();
  }

  Future<void> _load() async {
    final tasks = await DatabaseService.instance.fetchBacklogPlans(
      includeCompleted: true,
    );
    final roots = <int, PlanningTask>{};
    for (final task in tasks) {
      if (_isExecutablePathRoot(task)) roots.putIfAbsent(task.categoryId, () => task);
    }
    if (!mounted) return;
    setState(() {
      _roots = roots;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ru = currentLocale.value.toLowerCase().startsWith('ru');
    final copy = _ExecutablePathCopy(ru);
    final db = DatabaseService.instance;
    final categories = <CategoryRule>[];
    final seen = <int>{};
    for (final pair in db.allCategoryIdPathPairs) {
      if (!seen.add(pair.id)) continue;
      final rule = db.getCategoryRuleById(pair.id);
      if (rule == null || rule.isArchived) continue;
      categories.add(rule);
    }
    categories.sort((a, b) {
      final ah = _roots.containsKey(a.id) ? 0 : 1;
      final bh = _roots.containsKey(b.id) ? 0 : 1;
      if (ah != bh) return ah.compareTo(bh);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(copy.subtitle, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    if (_error != null)
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber_rounded),
                          title: Text(copy.bootstrapFailed),
                          subtitle: Text(_error!),
                        ),
                      ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.rule_rounded),
                        title: Text(copy.dailyRule),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final category in categories)
                      _projectCard(context, category, copy),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _projectCard(
    BuildContext context,
    CategoryRule category,
    _ExecutablePathCopy copy,
  ) {
    final root = _roots[category.id];
    final seed = _seedForCategoryName(category.name);
    final required = seed?.requiredTracks ?? _genericRequiredTracks;
    final validation = root == null
        ? const _PathValidation(problems: ['Нет Path'], missingTracks: [])
        : _validateExecutablePath(root, required);
    final stages = root == null ? const <_ExecutablePathStage>[] : _parseExecutableStages(root);
    _ExecutablePathStage? current;
    for (final stage in stages) {
      if (!stage.done) {
        current = stage;
        break;
      }
    }
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category.colorOrDefault.withValues(alpha: 0.14),
          foregroundColor: category.colorOrDefault,
          child: Icon(category.iconOrDefault),
        ),
        title: Text(category.name),
        subtitle: Text(
          root == null
              ? copy.noPath
              : '${validation.ready ? copy.ready : copy.notReady}${current == null ? '' : ' · ${copy.current}: ${current.title}'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              validation.ready ? Icons.verified_rounded : Icons.warning_amber_rounded,
              color: validation.ready ? scheme.tertiary : scheme.error,
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => _ExecutableCategoryPathPage(category: category),
            ),
          );
          if (mounted) unawaited(_load());
        },
      ),
    );
  }
}

class _StageDraft {
  const _StageDraft(this.title, this.doneWhen);
  final String title;
  final String doneWhen;
}

class _ActionDraft {
  const _ActionDraft(this.text, this.result, this.minutes, this.track);
  final String text;
  final String result;
  final int minutes;
  final String track;
}

class _ExecutableCategoryPathPage extends StatefulWidget {
  const _ExecutableCategoryPathPage({required this.category});
  final CategoryRule category;

  @override
  State<_ExecutableCategoryPathPage> createState() =>
      _ExecutableCategoryPathPageState();
}

class _ExecutableCategoryPathPageState
    extends State<_ExecutableCategoryPathPage> {
  bool _loading = true;
  PlanningTask? _root;

  _ProjectPathSeed? get _seed => _seedForCategoryName(widget.category.name);
  List<String> get _requiredTracks => _seed?.requiredTracks ?? _genericRequiredTracks;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final tasks = await DatabaseService.instance.fetchBacklogPlans(
      categoryId: widget.category.id,
      includeCompleted: true,
    );
    PlanningTask? root;
    for (final task in tasks) {
      if (_isExecutablePathRoot(task)) {
        root = task;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _root = root;
      _loading = false;
    });
  }

  Future<String?> _promptText({
    required String title,
    required String hint,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t(currentLocale.value, 'cancel')),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(ctx).pop(text);
            },
            child: Text(t(currentLocale.value, 'save')),
          ),
        ],
      ),
    );
    controller.dispose();
    return value?.trim();
  }

  Future<_StageDraft?> _stageDialog({_ExecutablePathStage? initial}) async {
    final ru = currentLocale.value.toLowerCase().startsWith('ru');
    final titleController = TextEditingController(text: initial?.title ?? '');
    final doneController = TextEditingController(text: initial?.doneWhen ?? '');
    final value = await showDialog<_StageDraft>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ru ? 'Этап' : 'Stage'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(labelText: ru ? 'Результат этапа' : 'Stage outcome'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doneController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: ru ? 'Готово, когда…' : 'Done when…'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t(currentLocale.value, 'cancel')),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              final doneWhen = doneController.text.trim();
              if (title.isEmpty || doneWhen.isEmpty) return;
              Navigator.of(ctx).pop(_StageDraft(title, doneWhen));
            },
            child: Text(t(currentLocale.value, 'save')),
          ),
        ],
      ),
    );
    titleController.dispose();
    doneController.dispose();
    return value;
  }

  Future<_ActionDraft?> _actionDialog({_ExecutablePathAction? initial}) async {
    final ru = currentLocale.value.toLowerCase().startsWith('ru');
    final textController = TextEditingController(text: initial?.text ?? '');
    final resultController = TextEditingController(text: initial?.result ?? '');
    var minutes = initial?.minutes ?? 20;
    var track = initial?.track ?? _requiredTracks.first;
    if (!_requiredTracks.contains(track)) track = _requiredTracks.first;
    final value = await showDialog<_ActionDraft>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(ru ? 'Конкретное действие' : 'Concrete action'),
          content: SizedBox(
            width: 620,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: ru ? 'Что физически сделать' : 'What to physically do',
                    helperText: ru ? 'Одно действие, максимум 30 минут' : 'One action, 30 minutes maximum',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: resultController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: ru ? 'Какой артефакт/результат останется' : 'Expected artifact/output',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: minutes,
                        decoration: InputDecoration(labelText: ru ? 'Время' : 'Time'),
                        items: const [5, 10, 15, 20, 25, 30]
                            .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                            .toList(growable: false),
                        onChanged: (v) => setLocalState(() => minutes = v ?? 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: track,
                        decoration: InputDecoration(labelText: ru ? 'Область' : 'Track'),
                        items: _requiredTracks
                            .map(
                              (key) => DropdownMenuItem(
                                value: key,
                                child: Text(_trackLabel(key, ru)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (v) => setLocalState(() => track = v ?? track),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t(currentLocale.value, 'cancel')),
            ),
            FilledButton(
              onPressed: () {
                final text = textController.text.trim();
                final result = resultController.text.trim();
                if (text.isEmpty || result.isEmpty) return;
                Navigator.of(ctx).pop(_ActionDraft(text, result, minutes, track));
              },
              child: Text(t(currentLocale.value, 'save')),
            ),
          ],
        ),
      ),
    );
    textController.dispose();
    resultController.dispose();
    return value;
  }

  void _showSaveError() {
    if (!mounted) return;
    final copy = _ExecutablePathCopy(currentLocale.value.toLowerCase().startsWith('ru'));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(copy.saveFailed)));
  }

  Future<void> _createPath() async {
    final ru = currentLocale.value.toLowerCase().startsWith('ru');
    final goal = await _promptText(
      title: ru ? 'Цель проекта' : 'Project goal',
      hint: ru ? 'К какому конечному состоянию ведём проект?' : 'What end state should this project reach?',
    );
    if (goal == null || goal.isEmpty) return;
    final order = await DatabaseService.instance.nextBacklogPlanningOrder();
    final ok = await DatabaseService.instance.addPlanningTask(
      PlanningTask(
        id: 0,
        title: goal,
        categoryId: widget.category.id,
        isDone: true,
        dateKey: '',
        order: order,
        checklist: const <Map<String, dynamic>>[],
        notesPlain: _lifeOsPathMarkerV2,
        isSynced: false,
      ),
    );
    if (!ok) {
      _showSaveError();
      return;
    }
    await _load();
  }

  Future<void> _save({String? goal, List<_ExecutablePathStage>? stages}) async {
    final before = _root;
    if (before == null) return;
    final next = before.copyWith(
      title: goal ?? before.title,
      isDone: true,
      notesPlain: _lifeOsPathMarkerV2,
      checklist: stages?.map((e) => e.toJson()).toList(growable: false),
    );
    setState(() => _root = next);
    final ok = await DatabaseService.instance.updatePlanningTask(
      before.planRowIdForBackend,
      planBusinessId: before.planRowId,
      title: next.title,
      categoryId: widget.category.id,
      isDone: true,
      notesPlain: _lifeOsPathMarkerV2,
      checklist: next.checklist,
      suppressAppSnack: true,
    );
    if (!ok && mounted) {
      setState(() => _root = before);
      _showSaveError();
    }
  }

  Future<void> _editGoal() async {
    final root = _root;
    if (root == null) return;
    final ru = currentLocale.value.toLowerCase().startsWith('ru');
    final value = await _promptText(
      title: ru ? 'Цель проекта' : 'Project goal',
      hint: ru ? 'К какому состоянию ведём проект?' : 'What end state are we building toward?',
      initial: root.title,
    );
    if (value != null && value.isNotEmpty && value != root.title) {
      await _save(goal: value);
    }
  }

  Future<void> _addStage() async {
    final root = _root;
    if (root == null) return;
    final draft = await _stageDialog();
    if (draft == null) return;
    final stages = _parseExecutableStages(root)
      ..add(
        _ExecutablePathStage(
          id: 'stage-${DateTime.now().microsecondsSinceEpoch}',
          title: draft.title,
          doneWhen: draft.doneWhen,
          done: false,
          actions: const [],
        ),
      );
    await _save(stages: stages);
  }

  Future<void> _editStage(int index) async {
    final root = _root;
    if (root == null) return;
    final stages = _parseExecutableStages(root);
    if (index < 0 || index >= stages.length) return;
    final draft = await _stageDialog(initial: stages[index]);
    if (draft == null) return;
    stages[index] = stages[index].copyWith(
      title: draft.title,
      doneWhen: draft.doneWhen,
    );
    await _save(stages: stages);
  }

  Future<void> _toggleStage(int index, bool done) async {
    final root = _root;
    if (root == null) return;
    final stages = _parseExecutableStages(root);
    if (index < 0 || index >= stages.length) return;
    stages[index] = stages[index].copyWith(done: done);
    await _save(stages: stages);
  }

  Future<void> _deleteStage(int index) async {
    final root = _root;
    if (root == null) return;
    final stages = _parseExecutableStages(root);
    if (index < 0 || index >= stages.length) return;
    stages.removeAt(index);
    await _save(stages: stages);
  }

  Future<void> _addAction(int stageIndex) async {
    final root = _root;
    if (root == null) return;
    final stages = _parseExecutableStages(root);
    if (stageIndex < 0 || stageIndex >= stages.length) return;
    final draft = await _actionDialog();
    if (draft == null) return;
    final actions = List<_ExecutablePathAction>.from(stages[stageIndex].actions)
      ..add(
        _ExecutablePathAction(
          id: 'action-${DateTime.now().microsecondsSinceEpoch}',
          text: draft.text,
          result: draft.result,
          minutes: draft.minutes,
          track: draft.track,
          done: false,
        ),
      );
    stages[stageIndex] = stages[stageIndex].copyWith(actions: actions);
    await _save(stages: stages);
  }

  Future<void> _editAction(int stageIndex, int actionIndex) async {
    final root = _root;
    if (root == null) return;
    final stages = _parseExecutableStages(root);
    if (stageIndex < 0 || stageIndex >= stages.length) return;
    final actions = List<_ExecutablePathAction>.from(stages[stageIndex].actions);
    if (actionIndex < 0 || actionIndex >= actions.length) return;
    final draft = await _actionDialog(initial: actions[actionIndex]);
    if (draft == null) return;
    actions[actionIndex] = actions[actionIndex].copyWith(
      text: draft.text,
      result: draft.result,
      minutes: draft.minutes,
      track: draft.track,
    );
    stages[stageIndex] = stages[stageIndex].copyWith(actions: actions);
    await _save(stages: stages);
  }

  Future<void> _toggleAction(int stageIndex, int actionIndex, bool done) async {
    final root = _root;
    if (root == null) return;
    final stages = _parseExecutableStages(root);
    if (stageIndex < 0 || stageIndex >= stages.length) return;
    final actions = List<_ExecutablePathAction>.from(stages[stageIndex].actions);
    if (actionIndex < 0 || actionIndex >= actions.length) return;
    actions[actionIndex] = actions[actionIndex].copyWith(done: done);
    stages[stageIndex] = stages[stageIndex].copyWith(actions: actions);
    await _save(stages: stages);
  }

  Future<void> _deleteAction(int stageIndex, int actionIndex) async {
    final root = _root;
    if (root == null) return;
    final stages = _parseExecutableStages(root);
    if (stageIndex < 0 || stageIndex >= stages.length) return;
    final actions = List<_ExecutablePathAction>.from(stages[stageIndex].actions);
    if (actionIndex < 0 || actionIndex >= actions.length) return;
    actions.removeAt(actionIndex);
    stages[stageIndex] = stages[stageIndex].copyWith(actions: actions);
    await _save(stages: stages);
  }

  @override
  Widget build(BuildContext context) {
    final ru = currentLocale.value.toLowerCase().startsWith('ru');
    final copy = _ExecutablePathCopy(ru);
    final root = _root;
    return Scaffold(
      appBar: AppBar(title: Text('${copy.title}: ${widget.category.name}')),
      body: _loading && root == null
          ? const Center(child: CircularProgressIndicator())
          : root == null
          ? _empty(copy)
          : _body(root, copy, ru),
    );
  }

  Widget _empty(_ExecutablePathCopy copy) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.alt_route_rounded, size: 56),
          const SizedBox(height: 12),
          Text(copy.noPath, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => unawaited(_createPath()),
            icon: const Icon(Icons.add_road_rounded),
            label: Text(copy.createPath),
          ),
        ],
      ),
    );
  }

  Widget _body(PlanningTask root, _ExecutablePathCopy copy, bool ru) {
    final stages = _parseExecutableStages(root);
    final validation = _validateExecutablePath(root, _requiredTracks);
    var currentIndex = -1;
    for (var i = 0; i < stages.length; i++) {
      if (!stages[i].done) {
        currentIndex = i;
        break;
      }
    }
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Card(
              child: ListTile(
                title: Text(copy.goal),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(root.title, style: Theme.of(context).textTheme.titleMedium),
                ),
                trailing: IconButton(
                  onPressed: () => unawaited(_editGoal()),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: copy.editGoal,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: validation.ready
                  ? scheme.tertiaryContainer.withValues(alpha: 0.45)
                  : scheme.errorContainer.withValues(alpha: 0.55),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(validation.ready ? Icons.verified_rounded : Icons.warning_amber_rounded),
                        const SizedBox(width: 8),
                        Text(
                          validation.ready ? copy.ready : copy.notReady,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    if (validation.problems.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(copy.issues, style: Theme.of(context).textTheme.labelLarge),
                      for (final problem in validation.problems.take(8))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('• $problem'),
                        ),
                    ],
                    const SizedBox(height: 12),
                    Text(copy.blindSpots, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final track in _requiredTracks)
                          Chip(
                            avatar: Icon(
                              validation.missingTracks.contains(track)
                                  ? Icons.error_outline_rounded
                                  : Icons.check_rounded,
                              size: 16,
                            ),
                            label: Text(_trackLabel(track, ru)),
                            side: validation.missingTracks.contains(track)
                                ? BorderSide(color: scheme.error)
                                : null,
                          ),
                      ],
                    ),
                    if (validation.missingTracks.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${copy.missing}: ${validation.missingTracks.map((e) => _trackLabel(e, ru)).join(', ')}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (currentIndex >= 0) ...[
              const SizedBox(height: 8),
              Card(
                color: scheme.primaryContainer.withValues(alpha: 0.35),
                child: ListTile(
                  leading: const Icon(Icons.my_location_rounded),
                  title: Text(copy.current),
                  subtitle: Text(stages[currentIndex].title),
                ),
              ),
            ],
            const SizedBox(height: 12),
            for (var i = 0; i < stages.length; i++)
              _stageCard(stages[i], i, i == currentIndex, copy, ru),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => unawaited(_addStage()),
              icon: const Icon(Icons.add_rounded),
              label: Text(copy.addStage),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageCard(
    _ExecutablePathStage stage,
    int stageIndex,
    bool current,
    _ExecutablePathCopy copy,
    bool ru,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final stageProblems = <String>[];
    if (!stage.done) {
      if (stage.doneWhen.isEmpty) stageProblems.add(ru ? 'Нет критерия завершения' : 'No done criterion');
      if (stage.actions.isEmpty) stageProblems.add(ru ? 'Нет действий' : 'No actions');
      if (stage.actions.any((a) => a.minutes < 1 || a.minutes > 30)) {
        stageProblems.add(ru ? 'Есть действие длиннее 30 минут' : 'An action exceeds 30 minutes');
      }
      if (stage.actions.any((a) => a.result.isEmpty)) {
        stageProblems.add(ru ? 'Есть действие без результата' : 'An action has no output');
      }
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: current ? scheme.primaryContainer.withValues(alpha: 0.18) : null,
      child: ExpansionTile(
        initiallyExpanded: current,
        leading: Checkbox(
          value: stage.done,
          onChanged: (v) => unawaited(_toggleStage(stageIndex, v ?? false)),
        ),
        title: Text(
          '${stageIndex + 1}. ${stage.title}',
          style: TextStyle(decoration: stage.done ? TextDecoration.lineThrough : null),
        ),
        subtitle: stageProblems.isEmpty
            ? Text('${stage.actions.where((a) => a.done).length}/${stage.actions.length} ${copy.actions.toLowerCase()}')
            : Text(stageProblems.join(' · '), style: TextStyle(color: scheme.error)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => unawaited(_editStage(stageIndex)),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: () => unawaited(_deleteStage(stageIndex)),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(copy.doneWhen, style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(stage.doneWhen.isEmpty ? '—' : stage.doneWhen),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                for (var ai = 0; ai < stage.actions.length; ai++)
                  _actionRow(stage.actions[ai], stageIndex, ai, copy, ru),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => unawaited(_addAction(stageIndex)),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(copy.addAction),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(
    _ExecutablePathAction action,
    int stageIndex,
    int actionIndex,
    _ExecutablePathCopy copy,
    bool ru,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final invalid = action.minutes < 1 || action.minutes > 30 || action.result.isEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: invalid ? scheme.error : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: action.done,
            onChanged: (v) => unawaited(_toggleAction(stageIndex, actionIndex, v ?? false)),
          ),
          Expanded(
            child: InkWell(
              onTap: () => unawaited(_editAction(stageIndex, actionIndex)),
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.text,
                      style: TextStyle(decoration: action.done ? TextDecoration.lineThrough : null),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${copy.expected}: ${action.result.isEmpty ? '—' : action.result}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('${action.minutes} min'),
                        ),
                        if (action.track.isNotEmpty)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(_trackLabel(action.track, ru)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => unawaited(_deleteAction(stageIndex, actionIndex)),
            icon: const Icon(Icons.close_rounded),
            tooltip: t(currentLocale.value, 'delete'),
          ),
        ],
      ),
    );
  }
}
