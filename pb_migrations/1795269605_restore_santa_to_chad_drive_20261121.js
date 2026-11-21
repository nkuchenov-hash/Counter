/// <reference path="../pb_data/types.d.ts" />
// Restore the ONE missing 21 Nov drive interval after production read-only proof.
// All venue appointments and actual time records stay unchanged. Idempotent.
// Deployment gate: release this migration only with the 1036-file exact architecture manifest.
migrate((app) => {
  const day="2026-11-21";
  const normalized=s=>String(s||"").toLowerCase().trim().replace(/\s+/g," ");
  const rows=app.findRecordsByFilter("plans","initial_date_key = {:day}","",1000,0,{day});
  const byOwner={};
  for(const row of rows) {
    const owner=row.getString("user_id");
    if(owner) (byOwner[owner] ||= []).push(row);
  }
  const names=["Особняк Милютина","Санта Глория","Чад — костюмы","Особняк Глуховского","Tara Brooch"];
  const candidates=[];
  for(const owner of Object.keys(byOwner)) {
    const own=byOwner[owner], found={};
    for(const name of names) {
      const hits=own.filter(r=>normalized(r.getString("title"))===normalized(name));
      if(hits.length===1) found[name]=hits[0];
    }
    if(Object.keys(found).length===names.length) candidates.push({owner,own,found});
  }
  if(candidates.length!==1) {
    console.log("lifeos_20261121_santa_chad_drive: skipped; matching_itineraries="+candidates.length);
    return;
  }
  const {owner,own,found}=candidates[0];
  const title="Дорога: Санта Глория → Чад — костюмы";
  const exact=own.filter(r=>normalized(r.getString("title"))===normalized(title));
  if(exact.length===1) {
    console.log("lifeos_20261121_santa_chad_drive: existing card already present");
    return;
  }
  if(exact.length>1) {
    console.log("lifeos_20261121_santa_chad_drive: ambiguous duplicate cards; no write");
    return;
  }
  const alternatives=own.filter(r=>{
    const t=normalized(r.getString("title"));
    return t.startsWith("дорога:") && t.includes("санта глория") && t.includes("чад");
  });
  if(alternatives.length>1) {
    console.log("lifeos_20261121_santa_chad_drive: multiple probable cards; no write");
    return;
  }
  const tara=Date.parse(String(found["Tara Brooch"].getString("start_time")).replace(" ","T"));
  if(!Number.isFinite(tara)) return;
  const at=(h,m)=>new Date(tara+((h-19)*60+m)*60000).toISOString();
  let row=alternatives.length===1 ? alternatives[0] : null;
  if(!row) {
    row=new Record(app.findCollectionByNameOrId("plans"));
    row.set("plan_id","c5a89f19-54a0-4e33-9a5d-216f91560117");
    row.set("user_id",owner);
    row.set("category_id",found["Санта Глория"].getString("category_id"));
    row.set("initial_date_key",day);
    row.set("is_done",false);
    row.set("checklist",[]);
    row.set("order",Math.max(0,...own.map(r=>r.getInt("order")))+1);
  }
  row.set("title",title);
  if(!row.getBool("is_done")) {
    row.set("start_time",at(16,20));
    row.set("end_time",at(16,35));
    row.set("is_postponed",false);
  }
  const from="Мытнинская набережная, 6, Санкт-Петербург, Россия";
  const to="Боткинская улица, Санкт-Петербург, Россия";
  row.set("notes_plain","21.11: переезд на автомобиле после завершения осмотра Санта Глория к Чаду на Боткинской. Указанные минуты — плановая оценка, не проверенный хронометраж.\nОткуда: "+from+"\nКуда: "+to+"\nЯндекс Карты: https://yandex.ru/maps/?text="+encodeURIComponent(to)+"\nGoogle Maps: https://www.google.com/maps/search/?api=1&query="+encodeURIComponent(to));
  app.save(row);
  console.log("lifeos_20261121_santa_chad_drive: restored=1");
}, (app) => {
  // A user itinerary must not be rolled back by deleting this card.
});
