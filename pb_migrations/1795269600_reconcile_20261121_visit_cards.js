/// <reference path="../pb_data/types.d.ts" />
// Narrow, idempotent repair of the already scheduled 2026-11-21 driving day.
// Never change user-selected visit times or any other user's tasks.
// This release synchronizes the reviewed repair with the deployment gate.
migrate((app) => {
  const day = "2026-11-21";
  const all = app.findRecordsByFilter(
    "plans", "initial_date_key = {:day}", "", 1000, 0, {day}
  );
  const spec = [
    {key:"mil", match:"особняк милютина", title:"Особняк Милютина",
      address:"Садовая улица, 4, Санкт-Петербург, Россия", kind:"Осмотр свадебной площадки"},
    {key:"santa", match:"санта глория", title:"Санта Глория",
      address:"Мытнинская набережная, 6, Санкт-Петербург, Россия", kind:"Осмотр свадебной площадки"},
    {key:"roof", match:"крыша 18", title:"Крыша 18",
      address:"Петроградская набережная, 18, Санкт-Петербург, Россия",
      kind:"Осмотр свадебной площадки. Важно увидеть панораму до заката"},
    {key:"chad", match:"боткинская", title:"Чад — костюмы",
      address:"Боткинская улица, Санкт-Петербург, Россия",
      kind:"Передать костюмы до 17:00. Номер дома пока не установлен"},
    {key:"glukh", match:"особняк глуховского", title:"Особняк Глуховского",
      address:"Набережная Адмирала Лазарева, 10/18, Санкт-Петербург, Россия",
      kind:"Осмотр свадебной площадки"},
    {key:"mars", match:"марсала", title:"Марсала",
      address:"Большой проспект Петроградской стороны, 84, Санкт-Петербург, Россия",
      kind:"Осмотр свадебной площадки; 6-й этаж"},
    {key:"tara", match:"tara brooch", title:"Tara Brooch",
      address:"2-я Советская улица, 18, Санкт-Петербург, Россия",
      kind:"Встреча RCC, 19:00–22:00/23:00. Филиал необходимо подтвердить"}
  ];
  const normalize = (s) => String(s || "").toLowerCase().trim();
  const ownerGroups = {};
  for (const row of all) {
    const owner = row.getString("user_id");
    if (!owner) continue;
    if (!ownerGroups[owner]) ownerGroups[owner] = [];
    ownerGroups[owner].push(row);
  }
  const candidates = [];
  for (const owner of Object.keys(ownerGroups)) {
    const rows = ownerGroups[owner];
    const found = {};
    for (const item of spec) {
      const matches = rows.filter(r =>
        normalize(r.getString("title")).includes(item.match));
      if (matches.length === 1) found[item.key] = matches[0];
    }
    if (spec.every(item => found[item.key])) {
      candidates.push({owner, rows, found});
    }
  }
  // Do not guess user identity or modify partially matching itineraries.
  if (candidates.length !== 1) return;
  const target = candidates[0];
  const categories = app.findRecordsByFilter(
    "categories", "user_id = {:owner}", "", 500, 0,
    {owner:target.owner}
  );
  const wedding = categories.find(c =>
    !c.getBool("is_archived") &&
    (/свадьба|wedding/.test(normalize(c.getString("name")))));
  const rcc = categories.find(c =>
    !c.getBool("is_archived") &&
    (/\brcc\b|russian culture club/.test(normalize(c.getString("name")))));
  if (!wedding || !rcc) return;
  const roadCategory = categories.find(c =>
    !c.getBool("is_archived") &&
    (/дорога|транспорт|driving|travel/.test(normalize(c.getString("name"))))) ||
    target.found.mil;
  const travelCategoryId = roadCategory.id === target.found.mil.id
    ? target.found.mil.getString("category_id") : roadCategory.id;
  const noteWithDetails = (oldNote, item) => {
    const existing = String(oldNote || "").trim();
    const parts = [];
    if (existing) parts.push(existing);
    if (!existing.includes(item.kind)) parts.push(item.kind);
    if (!existing.includes(item.address)) parts.push("Адрес: " + item.address);
    if (item.key !== "chad") {
      const yandex = "https://yandex.ru/maps/?text=" +
        encodeURIComponent(item.address);
      const google = "https://www.google.com/maps/search/?api=1&query=" +
        encodeURIComponent(item.address);
      if (!existing.includes("yandex.ru/maps")) parts.push(yandex);
      if (!existing.includes("google.com/maps")) parts.push(google);
    }
    return parts.join("\n");
  };
  for (const item of spec) {
    const row = target.found[item.key];
    if (row.getString("title") !== item.title) row.set("title", item.title);
    const updatedNote = noteWithDetails(row.getString("notes_plain"), item);
    if (row.getString("notes_plain") !== updatedNote)
      row.set("notes_plain", updatedNote);
    if (item.key !== "chad" && item.key !== "tara" &&
        row.getString("category_id") !== wedding.id) {
      row.set("category_id", wedding.id);
    } else if (item.key === "tara" &&
        row.getString("category_id") !== rcc.id) {
      row.set("category_id", rcc.id);
    }
    app.save(row);
  }
  // Keep the already scheduled Baltiyskaya departure; merely shorten it.
  const departure = target.rows.find(r =>
    normalize(r.getString("title")).includes("выезд от метро балтийская"));
  if (departure) {
    departure.set("title", "Дорога: Балтийская → Милютин");
    const destination = spec[0].address;
    departure.set("notes_plain", noteWithDetails(
      departure.getString("notes_plain"),
      {key:"departure",address:destination,
       kind:"Выезд на автомобиле от метро Балтийская"}
    ));
    app.save(departure);
  }
  // Insert only genuinely uncovered driving intervals; never overlap a plan.
  const legs = [
    ["mil","santa"], ["santa","roof"], ["roof","chad"],
    ["chad","glukh"], ["glukh","mars"], ["mars","tara"]
  ];
  const ids = [
    "c5a89f19-54a0-4e33-9a5d-216f91560011",
    "c5a89f19-54a0-4e33-9a5d-216f91560012",
    "c5a89f19-54a0-4e33-9a5d-216f91560013",
    "c5a89f19-54a0-4e33-9a5d-216f91560014",
    "c5a89f19-54a0-4e33-9a5d-216f91560015",
    "c5a89f19-54a0-4e33-9a5d-216f91560016"
  ];
  const ms = (val) => Date.parse(String(val).replace(" ", "T"));
  const collection = app.findCollectionByNameOrId("plans");
  let order = Math.max(0, ...target.rows.map(r => r.getInt("order"))) + 1;
  let created = 0;
  for (let i = 0; i < legs.length; i++) {
    const [fromKey, toKey] = legs[i];
    const from = target.found[fromKey];
    const to = target.found[toKey];
    const startStr = from.getString("end_time");
    const endStr = to.getString("start_time");
    const start = ms(startStr), end = ms(endStr);
    if (!Number.isFinite(start) || !Number.isFinite(end) ||
        end <= start || end - start > 120 * 60000) continue;
    const occupied = target.rows.some(r => {
      if (r.id === from.id || r.id === to.id) return false;
      const a = ms(r.getString("start_time"));
      const b = ms(r.getString("end_time"));
      return Number.isFinite(a) && Number.isFinite(b) &&
        a < end && b > start;
    });
    if (occupied) continue;
    const fromSpec = spec.find(x => x.key === fromKey);
    const toSpec = spec.find(x => x.key === toKey);
    const title = "Дорога: " + fromSpec.title + " → " + toSpec.title;
    if (target.rows.some(r => r.getString("title") === title)) continue;
    const row = new Record(collection);
    row.set("plan_id", ids[i]);
    row.set("user_id", target.owner);
    row.set("category_id",
      (fromKey === "chad" || toKey === "chad" || toKey === "tara")
        ? travelCategoryId : wedding.id);
    row.set("title", title);
    row.set("notes_plain",
      "Переезд на машине; длительность ориентировочная.\n" +
      "Откуда: " + fromSpec.address + "\n" +
      "Куда: " + toSpec.address + "\n" +
      (toKey === "chad"
        ? "Номер дома на Боткинской уточнить"
        : "https://yandex.ru/maps/?text=" +
          encodeURIComponent(toSpec.address)));
    row.set("is_done", false);
    row.set("checklist", []);
    row.set("order", order++);
    row.set("start_time", startStr);
    row.set("end_time", endStr);
    row.set("initial_date_key", day);
    row.set("is_postponed", false);
    app.save(row);
    target.rows.push(row);
    created++;
  }
  if (typeof console !== "undefined" && console.log) {
    console.log("lifeos_visit_repair: matched=1 updated=" +
      spec.length + " driving_cards=" + created);
  }
}, (app) => {
  // A rollback must never delete a user's real activity/schedule.
});
