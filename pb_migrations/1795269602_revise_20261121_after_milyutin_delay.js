/// <reference path="../pb_data/types.d.ts" />
// Adjust ONLY the established wedding-venue route for 21 Nov 2026.
// Preserve existing plan records and all actual-time records. Do not create duplicates.
// The user reported at 14:55 local that the Milyutin viewing had not started.
// Provisional revised timetable: Milyutin 15-16, Chad 16:25-16:35,
// Santa Gloria 17-18, Tara Brooch from 19:00.
migrate((app) => {
  const day = "2026-11-21";
  const norm = value => String(value || "").toLowerCase().trim();
  const rows = app.findRecordsByFilter(
    "plans", "initial_date_key = {:day}", "", 1000, 0, {day}
  );

  const names = {
    mil: "Особняк Милютина",
    santa: "Санта Глория",
    roof: "Крыша 18",
    chad: "Чад — костюмы",
    glukh: "Особняк Глуховского",
    mars: "Марсала",
    tara: "Tara Brooch"
  };
  const addresses = {
    mil: "Садовая улица, 4, Санкт-Петербург, Россия",
    chad: "Боткинская улица, Санкт-Петербург, Россия",
    santa: "Мытнинская набережная, 6, Санкт-Петербург, Россия",
    tara: "2-я Советская улица, 18, Санкт-Петербург, Россия"
  };
  const grouped = {};
  for (const row of rows) {
    const owner = row.getString("user_id");
    if (!owner) continue;
    if (!grouped[owner]) grouped[owner] = [];
    grouped[owner].push(row);
  }
  const foundOwners = [];
  for (const owner of Object.keys(grouped)) {
    const ownerRows = grouped[owner];
    const found = {};
    for (const key of Object.keys(names)) {
      // Strict equality avoids matching travel-card titles containing a venue.
      const exact = ownerRows.filter(row => norm(row.getString("title")) === norm(names[key]));
      if (exact.length === 1) found[key] = exact[0];
    }
    if (Object.keys(found).length === 7) {
      foundOwners.push({owner, rows: ownerRows, found});
    }
  }
  // Do not guess the account if more than one itinerary matches.
  if (foundOwners.length !== 1) {
    if (typeof console !== "undefined" && console.log)
      console.log("lifeos_route_revision_20261121: skipped, matched owners=" + foundOwners.length);
    return;
  }
  const {rows: ownerRows, found} = foundOwners[0];
  const parse = value => Date.parse(String(value || "").replace(" ", "T"));
  const base = parse(found.tara.getString("start_time"));
  if (!Number.isFinite(base)) return;
  // The already booked 19:00 Tara Brooch card anchors every time. This avoids
  // misinterpreting PocketBase UTC storage as Europe/Moscow local wall time.
  const at = (hours, minutes) =>
    new Date(base + ((hours - 19) * 60 + minutes) * 60000).toISOString();
  const addNote = (row, text) => {
    const old = row.getString("notes_plain") || "";
    if (!old.includes(text)) row.set("notes_plain", (old.trim() ? old.trim() + "\n\n" : "") + text);
  };
  const schedule = (row, sh, sm, eh, em, note) => {
    if (row.getBool("is_done")) return;
    row.set("start_time", at(sh, sm));
    row.set("end_time", at(eh, em));
    row.set("is_postponed", false);
    addNote(row, note);
    app.save(row);
  };
  const defer = (row, note) => {
    if (row.getBool("is_done")) return;
    row.set("start_time", "");
    row.set("end_time", "");
    row.set("is_postponed", true);
    addNote(row, note);
    app.save(row);
  };

  const note = "21.11: время изменено после задержки начала первого осмотра; на осмотр свадебной площадки отведён 1 час. Время может сдвигаться по факту.";
  schedule(found.mil, 15, 0, 16, 0, note);
  schedule(found.chad, 16, 25, 16, 35,
    "21.11: передача костюмов. Важно успеть до 17:00. Боткинская улица, точный дом уточнить.");
  schedule(found.santa, 17, 0, 18, 0, note);
  for (const key of ["roof", "glukh", "mars"]) {
    defer(found[key],
      "21.11: осмотр перенесён без новой даты. В исходном маршруте было недостаточно времени; при новой записи выделить 45–60 минут. Сохранена исходная карточка.");
  }
  // Keep Tara Brooch at its existing 19:00 start and preserve its end time.
  addNote(found.tara, "21.11: вечерняя встреча сохранена с 19:00 до 22:00–23:00. Это личный досуг, не RCC.");
  app.save(found.tara);

  // Reuse existing six generated road cards. Four become the new itinerary
  // including buffer, and two are unscheduled; no plans are deleted or created.
  const prior = [
    ["mil","santa"], ["santa","roof"], ["roof","chad"],
    ["chad","glukh"], ["glukh","mars"], ["mars","tara"]
  ];
  const roadRows = prior.map(([a,b]) => {
    const title = "Дорога: " + names[a] + " → " + names[b];
    const matches = ownerRows.filter(row => norm(row.getString("title")) === norm(title));
    return matches.length === 1 ? matches[0] : null;
  });
  const routeNotes = (a,b) =>
    "21.11: переезд на автомобиле. Откуда: " + addresses[a] +
    ". Куда: " + addresses[b] + ". Время ориентировочное.\n" +
    "Яндекс Карты: https://yandex.ru/maps/?text=" + encodeURIComponent(addresses[b]) +
    "\nGoogle Maps: https://www.google.com/maps/search/?api=1&query=" + encodeURIComponent(addresses[b]);
  const trips = [
    {index:0, a:"mil", b:"chad", start:[16,0], end:[16,25]},
    {index:1, a:"chad", b:"santa", start:[16,35], end:[17,0]},
    {index:2, a:"santa", b:"tara", start:[18,0], end:[18,30]}
  ];
  let roadChanged = 0;
  for (const trip of trips) {
    const row = roadRows[trip.index];
    if (!row || row.getBool("is_done")) continue;
    row.set("title", "Дорога: " + names[trip.a] + " → " + names[trip.b]);
    row.set("notes_plain", routeNotes(trip.a, trip.b));
    row.set("start_time", at(trip.start[0],trip.start[1]));
    row.set("end_time", at(trip.end[0],trip.end[1]));
    row.set("is_postponed", false);
    app.save(row);
    roadChanged++;
  }
  const buffer = roadRows[3];
  if (buffer && !buffer.getBool("is_done")) {
    buffer.set("title", "Резерв перед Tara Brooch");
    buffer.set("notes_plain", "21.11: запас 30 минут на пробки, парковку и задержку осмотра. Встреча с 19:00.");
    buffer.set("start_time", at(18,30));
    buffer.set("end_time", at(19,0));
    buffer.set("is_postponed", false);
    app.save(buffer);
    roadChanged++;
  }
  for (const index of [4,5]) {
    const row = roadRows[index];
    if (!row) continue;
    defer(row, "21.11: этот переезд больше не нужен из-за сокращения маршрута. Сохранён без запланированного времени.");
    roadChanged++;
  }

  if (typeof console !== "undefined" && console.log) {
    console.log("lifeos_route_revision_20261121: updated venue cards=7, existing travel cards=" + roadChanged);
  }
}, (app) => {
  // Do not undo user itinerary or delete their real records on rollback.
});
