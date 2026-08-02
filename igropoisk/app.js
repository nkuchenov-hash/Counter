const state={games:[],articles:[],filtered:[],route:'home',id:null,tab:'about',page:1,pageSize:30,filters:{query:'',genre:'',platform:'',year:'',rating:'',sort:'popular'}};
const $=s=>document.querySelector(s);
const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
const fmt=n=>Number.isFinite(+n)&&+n>0?(+n).toFixed(1).replace('.',','):'—';
const asArray=v=>Array.isArray(v)?v:(v?[v]:[]);

function normalize(raw){
  const release=raw.releaseDate||raw.release||'';
  const materials=raw.materials||{};
  return {...raw,
    id:String(raw.id||raw.appid||raw.slug||raw.title),
    appid:Number(raw.appid||0),
    title:raw.title||raw.name||'Без названия',
    year:Number(raw.year||String(release).match(/(?:19|20)\d{2}/)?.[0]||0),
    release,
    genres:asArray(raw.genres).length?asArray(raw.genres):String(raw.genre||'').split(',').map(x=>x.trim()).filter(Boolean),
    platforms:asArray(raw.platforms),
    developer:asArray(raw.developers)[0]||raw.developer||'',
    publisher:asArray(raw.publishers)[0]||raw.publisher||'',
    description:raw.description||raw.about||'',
    about:raw.about||raw.description||'',
    story:raw.story||raw.description||'',
    features:asArray(raw.features).length?asArray(raw.features):asArray(raw.categories).slice(0,12),
    poster:raw.poster||raw.capsuleImage||raw.headerImage||'',
    hero:raw.hero||raw.heroImage||raw.headerImage||'',
    screenshots:asArray(raw.screenshots).map(x=>typeof x==='string'?x:x?.url).filter(Boolean),
    rating:Number(raw.rating||raw.igropoiskRating||0),
    critics:Number(raw.critics||raw.criticRating||0),
    users:Number(raw.users||raw.userRating||raw.steamUserRating||0),
    popularity:Number(raw.popularityScore||raw.recommendations||raw.peakConcurrent||0),
    materials:{
      articles:asArray(materials.articles).length?asArray(materials.articles):asArray(raw.articles),
      reviews:asArray(materials.reviews),
      guides:asArray(materials.guides),
      tips:asArray(materials.tips),
      news:asArray(materials.news)
    }
  };
}

function readRoute(){
  const parts=location.hash.slice(1).split('/');
  state.route=parts[0]||'home';
  state.id=parts[1]||null;
  state.tab=parts[2]||'about';
  render();
}

function score(game){
  if(game.rating)return game.rating;
  if(game.critics&&game.users)return Math.round((game.critics*.65+game.users*.35)*10)/10;
  return game.critics||game.users||0;
}

function card(game){
  return `<article class="game-card" data-game="${esc(game.id)}">
    <div class="poster"><img loading="lazy" src="${esc(game.poster)}" alt="${esc(game.title)}"><b>${fmt(score(game))}</b></div>
    <h3>${esc(game.title)}</h3>
    <p>${esc(game.genres.slice(0,2).join(' · '))}${game.year?' · '+game.year:''}</p>
    <div class="mini-ratings"><span>Критики <b>${fmt(game.critics)}</b></span><span>Игроки <b>${fmt(game.users)}</b></span></div>
  </article>`;
}

function articleCard(item){
  return `<article class="article-card"><small>${esc(item.source||'Источник')}</small><h3>${esc(item.title)}</h3><p>${esc(item.summary||'')}</p><a href="${esc(item.url||'#')}" target="_blank" rel="noopener">Открыть источник ↗</a></article>`;
}

function section(title,subtitle,games){
  if(!games.length)return'';
  return `<section class="section"><div class="section-title"><div><h2>${title}</h2><p>${subtitle}</p></div><button data-nav="catalog">Весь каталог</button></div><div class="grid">${games.slice(0,10).map(card).join('')}</div></section>`;
}

function renderHome(){
  const sorted=[...state.games].sort((a,b)=>b.popularity-a.popularity||score(b)-score(a));
  const featured=sorted[Math.floor(Date.now()/86400000)%Math.min(sorted.length,25)]||sorted[0];
  const latest=[...state.games].filter(g=>g.year).sort((a,b)=>b.year-a.year||b.popularity-a.popularity);
  const topRated=[...state.games].sort((a,b)=>score(b)-score(a));
  const materials=(state.articles.length?state.articles:state.games.flatMap(g=>Object.values(g.materials).flat())).slice(0,8);
  return `<section class="hero" style="background-image:linear-gradient(90deg,rgba(0,0,0,.94),rgba(0,0,0,.18)),url('${esc(featured.hero)}')"><div><span>Игра дня</span><h1>${esc(featured.title)}</h1><p>${esc(featured.description)}</p><div class="hero-scores"><b>Игропоиск ${fmt(score(featured))}</b><b>Критики ${fmt(featured.critics)}</b><b>Игроки ${fmt(featured.users)}</b></div><button data-game="${esc(featured.id)}">Всё об игре</button></div></section>
  ${materials.length?`<section class="section"><div class="section-title"><div><h2>Свежие материалы</h2><p>Новости, обзоры и гайды из крупных игровых изданий</p></div></div><div class="article-grid">${materials.map(articleCard).join('')}</div></section>`:''}
  ${section('Популярное сейчас','Самые заметные игры в каталоге',sorted)}
  ${section('Новые релизы','Популярные игры последних лет',latest)}
  ${section('Высокие оценки','Лучшие результаты критиков и игроков',topRated)}`;
}

function unique(values){return [...new Set(values.filter(Boolean))].sort((a,b)=>String(a).localeCompare(String(b),'ru'));}

function filterPanel(){
  const genres=unique(state.games.flatMap(g=>g.genres));
  const platforms=unique(state.games.flatMap(g=>g.platforms));
  const years=unique(state.games.map(g=>g.year).filter(Boolean)).sort((a,b)=>b-a);
  const opt=(value,label,current)=>`<option value="${esc(value)}" ${String(current)===String(value)?'selected':''}>${esc(label)}</option>`;
  return `<div class="filterbar">
    <input id="filter-query" value="${esc(state.filters.query)}" placeholder="Название или студия">
    <select id="filter-genre"><option value="">Все жанры</option>${genres.map(x=>opt(x,x,state.filters.genre)).join('')}</select>
    <select id="filter-platform"><option value="">Все платформы</option>${platforms.map(x=>opt(x,x,state.filters.platform)).join('')}</select>
    <select id="filter-year"><option value="">Все годы</option>${years.map(x=>opt(x,x,state.filters.year)).join('')}</select>
    <select id="filter-rating"><option value="">Любой рейтинг</option>${[7,7.5,8,8.5,9].map(x=>opt(x,'От '+String(x).replace('.',','),state.filters.rating)).join('')}</select>
    <select id="filter-sort"><option value="popular">Популярные</option><option value="rating" ${state.filters.sort==='rating'?'selected':''}>По рейтингу</option><option value="year" ${state.filters.sort==='year'?'selected':''}>По году</option><option value="title" ${state.filters.sort==='title'?'selected':''}>По названию</option></select>
    <button id="apply-filters">Найти</button><button class="reset" id="reset-filters">Сбросить</button>
  </div>`;
}

function applyFilters(){
  const f=state.filters;
  let list=state.games.filter(g=>{
    const haystack=`${g.title} ${g.developer} ${g.publisher} ${g.genres.join(' ')}`.toLowerCase();
    if(f.query&&!haystack.includes(f.query.toLowerCase()))return false;
    if(f.genre&&!g.genres.includes(f.genre))return false;
    if(f.platform&&!g.platforms.includes(f.platform))return false;
    if(f.year&&String(g.year)!==String(f.year))return false;
    if(f.rating&&score(g)<Number(f.rating))return false;
    return true;
  });
  list.sort((a,b)=>f.sort==='rating'?score(b)-score(a):f.sort==='year'?b.year-a.year:f.sort==='title'?a.title.localeCompare(b.title,'ru'):b.popularity-a.popularity||score(b)-score(a));
  state.filtered=list;
  state.page=1;
}

function renderCatalog(){
  const shown=state.filtered.slice(0,state.page*state.pageSize);
  return `<section class="section catalog"><div class="catalog-heading"><div><h1>Каталог игр</h1><p>${state.filtered.length} игр после проверки качества</p></div></div>${filterPanel()}<div class="grid" id="catalog-grid">${shown.map(card).join('')}</div>${shown.length<state.filtered.length?'<button class="load-more" id="load-more">Показать ещё</button>':''}</section>`;
}

const tabLabels={about:'Всё об игре',screens:'Медиа',articles:'Статьи',reviews:'Обзоры',guides:'Гайды',tips:'Советы',news:'Новости'};

function materialList(items,label){
  return items?.length?`<div class="article-grid">${items.map(articleCard).join('')}</div>`:`<div class="empty">В разделе «${label}» пока нет найденных материалов.</div>`;
}

function about(game){
  return `<div class="game-layout"><main>
    <section><h2>Описание</h2><p>${esc(game.about||game.description)}</p></section>
    <section><h2>Сюжет</h2><p>${esc(game.story||game.description)}</p></section>
    <section><h2>Особенности</h2><div class="features">${game.features.length?game.features.map(x=>`<div>${esc(x)}</div>`).join(''):'<div>Особенности уточняются источниками</div>'}</div></section>
    <section><h2>Скриншоты</h2><div class="screens">${game.screenshots.slice(0,10).map(x=>`<img loading="lazy" src="${esc(x)}" alt="${esc(game.title)}">`).join('')}</div></section>
    <section><h2>Последние материалы</h2>${materialList(Object.values(game.materials).flat().slice(0,8),'материалы')}</section>
  </main><aside>
    <div class="facts"><h3>Информация</h3><dl><dt>Дата выхода</dt><dd>${esc(game.release||'—')}</dd><dt>Жанры</dt><dd>${esc(game.genres.join(', ')||'—')}</dd><dt>Платформы</dt><dd>${esc(game.platforms.join(', ')||'—')}</dd><dt>Разработчик</dt><dd>${esc(game.developer||'—')}</dd><dt>Издатель</dt><dd>${esc(game.publisher||'—')}</dd></dl></div>
    <div class="facts"><h3>Рейтинг</h3><div class="rating-list"><span>Игропоиск <b>${fmt(score(game))}</b></span><span>Критики <b>${fmt(game.critics)}</b></span><span>Игроки <b>${fmt(game.users)}</b></span></div><p>Все оценки приведены к шкале 0–10.</p></div>
  </aside></div>`;
}

function renderGame(){
  const game=state.games.find(g=>g.id===String(state.id))||state.games[0];
  const tabs=Object.entries(tabLabels).map(([key,label])=>`<button class="${state.tab===key?'active':''}" data-tab="${key}">${label}</button>`).join('');
  let body;
  if(state.tab==='about')body=about(game);
  else if(state.tab==='screens')body=`<div class="screens large">${game.screenshots.map(x=>`<img loading="lazy" src="${esc(x)}" alt="${esc(game.title)}">`).join('')}</div>`;
  else body=materialList(game.materials[state.tab],tabLabels[state.tab]);
  return `<section class="game-hero" style="background-image:linear-gradient(90deg,rgba(0,0,0,.95),rgba(0,0,0,.16)),url('${esc(game.hero)}')"><div><span>${esc(game.genres.join(' · '))}</span><h1>${esc(game.title)}</h1><p>${esc(game.description)}</p><div class="hero-scores"><b>Игропоиск ${fmt(score(game))}</b><b>Критики ${fmt(game.critics)}</b><b>Игроки ${fmt(game.users)}</b></div></div></section><nav class="tabs">${tabs}</nav><section class="section game-content">${body}</section>`;
}

function bind(){
  document.querySelectorAll('[data-game]').forEach(el=>el.onclick=()=>location.hash=`game/${el.dataset.game}/about`);
  document.querySelectorAll('[data-tab]').forEach(el=>el.onclick=()=>location.hash=`game/${state.id}/${el.dataset.tab}`);
  document.querySelectorAll('[data-nav]').forEach(el=>el.onclick=()=>location.hash=el.dataset.nav);
  const apply=$('#apply-filters');
  if(apply)apply.onclick=()=>{
    state.filters={query:$('#filter-query').value,genre:$('#filter-genre').value,platform:$('#filter-platform').value,year:$('#filter-year').value,rating:$('#filter-rating').value,sort:$('#filter-sort').value};
    applyFilters();render();
  };
  const reset=$('#reset-filters');if(reset)reset.onclick=()=>{state.filters={query:'',genre:'',platform:'',year:'',rating:'',sort:'popular'};applyFilters();render();};
  const more=$('#load-more');if(more)more.onclick=()=>{state.page+=1;render();};
}

function render(){
  const app=$('#app');
  if(!state.games.length){app.innerHTML='<div class="empty">Каталог загружается…</div>';return;}
  app.innerHTML=state.route==='catalog'?renderCatalog():state.route==='game'?renderGame():renderHome();
  bind();
}

window.addEventListener('hashchange',readRoute);
Promise.all([
  fetch('./data/catalog.json',{cache:'no-store'}).then(r=>{if(!r.ok)throw new Error('catalog');return r.json();}),
  fetch('./data/articles.json',{cache:'no-store'}).then(r=>r.ok?r.json():{articles:[]}).catch(()=>({articles:[]}))
]).then(([catalog,articles])=>{
  state.games=asArray(catalog.games||catalog).map(normalize).filter(g=>g.title&&g.poster&&g.hero);
  state.articles=asArray(articles.articles);
  applyFilters();
  readRoute();
}).catch(()=>{$('#app').innerHTML='<div class="empty">Не удалось загрузить каталог.</div>';});
