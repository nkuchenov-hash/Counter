/// <reference path="../pb_data/types.d.ts" />
// The user clarified the actual order at 16:21 Europe/Moscow, 2026-11-21:
// Milyutin and Santa Gloria have already been viewed; they are driving to
// Chad on Botkinskaya and have a firm Glukhovsky viewing at 17:00.
// Only update a unique matching owner's existing itinerary for this date.
// Past visit times are RECONSTRUCTED planning placeholders, not actual tracking.
migrate((app) => {
  const day = "2026-11-21";
  const norm = s => String(s || "").toLowerCase().trim();
  const rows = app.findRecordsByFilter("plans",
    "initial_date_key = {:day}", "", 1000, 0, {day});
  const names = {
    mil: "Особняк Милютина",
    santa: "Санта Глория",
    chad: "Чад — костюмы",
    glukh: "Особняк Глуховского",
    mars: "Марсала",
    roof: "Крыша 18",
    tara: "Tara Brooch"
  };
  const addr = {
    mil: "Садовая улица, 4, Санкт-Петербург, Россия",
    santa: "Мытнинская набережная, 6, Санкт-Петербург, Россия",
    chad: "Боткинская улица, Санкт-Петербург, Россия",
    glukh: "Набережная Адмирала Лазарева, 10/18, Санкт-Петербург, Россия",
    mars: "Большой проспект Петроградской стороны, 84, Санкт-Петербург, Россия",
    tara: "2-я Советская улица, 18, Санкт-Петербург, Россия"
  };
  const byOwner = {};
  for (const row of rows) {
    const owner = row.getString("user_id");
    if (owner) (byOwner[owner] ||= []).push(row);
  }
  const matches = [];
  for (const owner of Object.keys(byOwner)) {
    const own = byOwner[owner], found = {};
    for (const [key, name] of Object.entries(names)) {
      const candidate = own.filter(r => norm(r.getString("title")) === norm(name));
      if (candidate.length === 1) found[key] = candidate[0];
    }
    if (Object.keys(found).length === Object.keys(names).length)
      matches.push({owner, own, found});
  }
  if (matches.length !== 1) {
    console.log("lifeos_actual_route_20261121: skipped, matching itineraries=" + matches.length);
    return;
  }
  const {owner, own, found} = matches[0];
  const base = Date.parse(String(found.tara.getString("start_time")).replace(" ", "T"));
  if (!Number.isFinite(base)) return;
  const at = (h, m) => new Date(base + ((h-19)*60+m)*60000).toISOString();
  const current = "Обновлено по сообщению в 16:21 21.11.2026.";
  function setPlan(key, start, end, message, markDone = false) {
    const row = found[key];
    if (!markDone && row.getBool("is_done")) return;
    row.set("start_time", at(...start));
    row.set("end_time", at(...end));
    row.set("is_postponed", false);
    if (markDone) row.set("is_done", true);
    const old = String(row.getString("notes_plain") || "");
    // Remove obsolete schedule advice, keeping addresses and venue notes.
    const clean = old.split("\n").filter(s =>
      !/21\.11.*(перенес|уточнённый маршрут|время изменено|ускоренный маршрут)/i.test(s)
    ).join("\n").trim();
    row.set("notes_plain", [clean, current + " " + message].filter(Boolean).join("\n\n"));
    app.save(row);
  }
  // The exact historical start/end was not provided. These two planned
  // slots are explicitly labelled APPROXIMATE and do not touch time records.
  setPlan("mil", [15,0], [15,35],
    "Осмотр ЗАВЕРШЁН. 15:00–15:35 — приблизительное размещение в плане, не фактический хронометраж.", true);
  setPlan("santa", [15,50], [16,20],
    "Осмотр ЗАВЕРШЁН после Милютина. 15:50–16:20 — приблизительное размещение в плане, не фактический хронометраж.", true);
  setPlan("chad", [16,35], [16,45],
    "После Санта Глория передать костюмы на Боткинской до 17:00. Время прибытия приблизительное, точный дом неизвестен.");
  setPlan("glukh", [17,0], [17,45],
    "СОГЛАСОВАННЫЙ осмотр в 17:00; время начала фиксированное. 45 минут на встречу.");
  setPlan("mars", [17,55], [18,25],
    "Дополнительный осмотр, если менеджер может принять. Предварительное время, не подтверждено.");
  // The roof is intentionally left for another visit; the user reported
  // Glukhovsky at 17:00, so don't add overlapping viewings.
  if (!found.roof.getBool("is_done")) {
    found.roof.set("start_time", "");
    found.roof.set("end_time", "");
    found.roof.set("is_postponed", true);
    found.roof.set("notes_plain",
      "Осмотр Крыши 18 перенесён без даты, чтобы успеть к Глуховскому в 17:00. Адрес: Петроградская набережная, 18, Санкт-Петербург, Россия. " +
      "https://yandex.ru/maps/?text=" + encodeURIComponent("Петроградская набережная, 18, Санкт-Петербург"));
    app.save(found.roof);
  }
  // Keep evening event exactly at its previously agreed start and end.
  const roadIds = [
    "c5a89f19-54a0-4e33-9a5d-216f91560011",
    "c5a89f19-54a0-4e33-9a5d-216f91560012",
    "c5a89f19-54a0-4e33-9a5d-216f91560013",
    "c5a89f19-54a0-4e33-9a5d-216f91560014",
    "c5a89f19-54a0-4e33-9a5d-216f91560015",
    "c5a89f19-54a0-4e33-9a5d-216f91560016"
  ];
  const legs = [
    {a:"mil", b:"santa", start:[15,35], end:[15,50], label:"Примерное время завершённого переезда"},
    {a:"santa", b:"chad", start:[16,20], end:[16,35], label:"Едете сейчас. Примерное прибытие, не live ETA"},
    {a:"chad", b:"glukh", start:[16,45], end:[17,0], label:"Успеть к назначенному осмотру в 17:00"},
    {a:"glukh", b:"mars", start:[17,45], end:[17,55], label:"Поездка только если осмотр Марсалы состоится"},
    {a:"mars", b:"tara", start:[18,25], end:[18,55], label:"Ориентировочный переезд; до Tara Brooch не позже 19:00"},
    {buffer:true, start:[18,55], end:[19,0], label:"Резерв перед Tara Brooch"}
  ];
  const coll = app.findCollectionByNameOrId("plans");
  let order = Math.max(0, ...own.map(r => r.getInt("order"))) + 1;
  for (let i=0; i<legs.length; i++) {
    const leg = legs[i];
    let candidates = own.filter(r => r.getString("plan_id") === roadIds[i]);
    // If prior migrations were never deployed, do not fabricate duplicates
    // with a conflicting id when matching is ambiguous.
    if (candidates.length > 1) continue;
    let row = candidates[0];
    if (!row) {
      row = new Record(coll);
      row.set("plan_id", roadIds[i]);
      row.set("user_id", owner);
      row.set("category_id", found.mil.getString("category_id"));
      row.set("initial_date_key", day);
      row.set("order", order++);
      row.set("is_done", false);
      row.set("checklist", []);
      own.push(row);
    } else if (row.getBool("is_done")) {
      // A completed road card is historical; preserve it as-is.
      continue;
    }
    row.set("title", leg.buffer ? "Резерв перед Tara Brooch"
      : "Дорога: " + names[leg.a] + " → " + names[leg.b]);
    row.set("start_time", at(...leg.start));
    row.set("end_time", at(...leg.end));
    row.set("is_postponed", false);
    row.set("notes_plain", leg.buffer ? leg.label :
      "Переезд на машине. " + leg.label +
      "\nОткуда: " + addr[leg.a] +
      "\nКуда: " + addr[leg.b] +
      "\nЯндекс Карты: https://yandex.ru/maps/?text=" + encodeURIComponent(addr[leg.b]) +
      "\nGoogle Maps: https://www.google.com/maps/search/?api=1&query=" + encodeURIComponent(addr[leg.b]));
    app.save(row);
  }
  console.log("lifeos_actual_route_20261121: visits corrected and road cards reconciled for owner=" + owner);
}, (app) => {
  // Never overwrite the user's actual time ledger on rollback.
});
