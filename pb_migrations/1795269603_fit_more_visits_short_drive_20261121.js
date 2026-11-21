/// <reference path="../pb_data/types.d.ts" />
// Revise the 21 Nov 2026 visit route after user feedback that nearby car
// transfers were significantly over-allocated. This is a planning estimate,
// NOT a claim of live traffic data. Preserve actual records and other days.
migrate((app) => {
  const day = "2026-11-21";
  const rows = app.findRecordsByFilter(
    "plans", "initial_date_key = {:day}", "", 1000, 0, {day}
  );
  const lower = x => String(x || "").toLowerCase().trim();
  const names = {
    mil: "Особняк Милютина", santa: "Санта Глория",
    roof: "Крыша 18", chad: "Чад — костюмы",
    glukh: "Особняк Глуховского", mars: "Марсала", tara: "Tara Brooch"
  };
  const addrs = {
    mil: "Садовая улица, 4, Санкт-Петербург, Россия",
    roof: "Петроградская набережная, 18, Санкт-Петербург, Россия",
    chad: "Боткинская улица, Санкт-Петербург, Россия (номер дома уточнить)",
    glukh: "Набережная Адмирала Лазарева, 10/18, Санкт-Петербург, Россия",
    mars: "Большой проспект Петроградской стороны, 84, Санкт-Петербург, Россия",
    tara: "2-я Советская улица, 18, Санкт-Петербург, Россия"
  };
  const grouped = {};
  for (const r of rows) {
    const owner = r.getString("user_id");
    if (!owner) continue;
    (grouped[owner] ||= []).push(r);
  }
  const candidates = [];
  for (const owner of Object.keys(grouped)) {
    const ownerRows = grouped[owner], found = {};
    for (const key of Object.keys(names)) {
      const matches = ownerRows.filter(r => lower(r.getString("title")) === lower(names[key]));
      if (matches.length === 1) found[key] = matches[0];
    }
    if (Object.keys(found).length === 7)
      candidates.push({owner, rows: ownerRows, found});
  }
  if (candidates.length !== 1) {
    console.log("lifeos_route_20261121_optimized: no unique matching itinerary (" +
      candidates.length + ")");
    return;
  }
  const target = candidates[0], found = target.found;
  const taraStart = Date.parse(found.tara.getString("start_time").replace(" ", "T"));
  if (!Number.isFinite(taraStart)) return;
  // Anchor to user's already scheduled 19:00 Tara Brooch. Avoid server
  // UTC offset ambiguities and never change Tara Brooch's meeting time.
  const at = (hh,mm) => new Date(taraStart + ((hh-19)*60+mm)*60000).toISOString();
  const addNote = (r, message) => {
    const old = r.getString("notes_plain") || "";
    if (!old.includes(message))
      r.set("notes_plain", old.trim() ? old.trim()+"\n\n"+message : message);
  };
  const setTime = (r, start, end, detail) => {
    if (r.getBool("is_done")) return;
    r.set("start_time", at(...start));
    r.set("end_time", at(...end));
    r.set("is_postponed", false);
    addNote(r, detail);
    app.save(r);
  };
  const label = "21.11, уточнённый маршрут: длительность осмотров и переездов ориентировочная. Пробки и доступность менеджера не подтверждены; по факту время может сдвигаться.";
  setTime(found.mil, [15,0], [15,50], label);
  setTime(found.chad, [16,0], [16,5],
    "21.11: быстро передать костюмы на Боткинской до 17:00; точный номер дома уточнить.");
  setTime(found.roof, [16,20], [16,55], label);
  setTime(found.glukh, [17,5], [17,45], label);
  setTime(found.mars, [17,55], [18,30], label);
  // Keep Santa Gloria as an unscheduled option, not an overlapping card.
  if (!found.santa.getBool("is_done")) {
    found.santa.set("start_time", "");
    found.santa.set("end_time", "");
    found.santa.set("is_postponed", true);
    addNote(found.santa,
      "21.11: перенесено без новой даты, чтобы успеть более близкие осмотры на Петроградской стороне. Не отменяет договорённости с менеджером; при наличии записи согласовать.");
    app.save(found.santa);
  }
  const roadIds = [
    "c5a89f19-54a0-4e33-9a5d-216f91560011",
    "c5a89f19-54a0-4e33-9a5d-216f91560012",
    "c5a89f19-54a0-4e33-9a5d-216f91560013",
    "c5a89f19-54a0-4e33-9a5d-216f91560014",
    "c5a89f19-54a0-4e33-9a5d-216f91560015",
    "c5a89f19-54a0-4e33-9a5d-216f91560016"
  ];
  const legs = [
    {a:"mil", b:"chad", start:[15,50], end:[16,0]},
    {a:"chad", b:"roof", start:[16,5], end:[16,20]},
    {a:"roof", b:"glukh", start:[16,55], end:[17,5]},
    {a:"glukh", b:"mars", start:[17,45], end:[17,55]},
    {a:"mars", b:"tara", start:[18,30], end:[18,55]},
    {buffer:true, start:[18,55], end:[19,0]}
  ];
  const collection = app.findCollectionByNameOrId("plans");
  let order = Math.max(0, ...target.rows.map(r=>r.getInt("order"))) + 1;
  const oldTitles = [
    "Дорога: Особняк Милютина → Санта Глория",
    "Дорога: Санта Глория → Крыша 18",
    "Дорога: Крыша 18 → Чад — костюмы",
    "Дорога: Чад — костюмы → Особняк Глуховского",
    "Дорога: Особняк Глуховского → Марсала",
    "Дорога: Марсала → Tara Brooch"
  ];
  for (let i=0;i<legs.length;i++) {
    const leg = legs[i];
    let match = target.rows.filter(r=>r.getString("plan_id") === roadIds[i]);
    if (match.length !== 1) {
      const possible = [
        oldTitles[i],
        i===0 ? "Дорога: Особняк Милютина → Чад — костюмы" : "",
        i===1 ? "Дорога: Чад — костюмы → Крыша 18" : "",
        i===2 ? "Дорога: Крыша 18 → Особняк Глуховского" : "",
        i===3 ? "Резерв перед Tara Brooch" : ""
      ].filter(Boolean);
      match = target.rows.filter(r=>possible.some(t=>r.getString("title")===t));
    }
    let r;
    if (match.length===1) r=match[0];
    else if (match.length===0) {
      r=new Record(collection);
      r.set("plan_id",roadIds[i]);
      r.set("user_id",target.owner);
      r.set("category_id",found.mil.getString("category_id"));
      r.set("is_done",false);
      r.set("checklist",[]);
      r.set("order",order++);
      r.set("initial_date_key",day);
      target.rows.push(r);
    } else continue;
    if (r.getBool("is_done")) continue;
    const title = leg.buffer ? "Резерв перед Tara Brooch"
      : "Дорога: "+names[leg.a]+" → "+names[leg.b];
    const detail = leg.buffer
      ? "Запас на парковку и непредвиденные задержки. К Tara Brooch необходимо приехать к 19:00."
      : "Переезд на машине (оценка, не live ETA).\nОткуда: "+addrs[leg.a]+
        "\nКуда: "+addrs[leg.b]+
        "\nЯндекс Карты: https://yandex.ru/maps/?text="+encodeURIComponent(addrs[leg.b])+
        "\nGoogle Maps: https://www.google.com/maps/search/?api=1&query="+encodeURIComponent(addrs[leg.b]);
    r.set("title",title);
    r.set("notes_plain",detail);
    r.set("start_time",at(...leg.start));
    r.set("end_time",at(...leg.end));
    r.set("is_postponed",false);
    app.save(r);
  }
  console.log("lifeos_route_20261121_optimized: reallocated 5 venue visits and 6 drive/buffer cards");
}, (app) => {
  // Do not delete or revert real user activity data on rollback.
});
