(function(){
  const hasText=(v,min=1)=>typeof v==='string'&&v.trim().length>=min;
  const list=v=>Array.isArray(v)?v:[];
  const sourcesOf=g=>list(g.sources||g.sourceEvidence||g.editorialSources);
  const videosOf=g=>list(g.videos||g.movies||g.media?.videos);
  const screenshotsOf=g=>list(g.screenshots||g.media?.screenshots).filter(Boolean);
  const featuresOf=g=>list(g.features||g.editorial?.features).filter(Boolean);
  const materialsOf=g=>g.materials&&typeof g.materials==='object'?g.materials:{};

  window.IGROPOISK_PUBLISH_GATE=function(g){
    if(!g||typeof g!=='object')return false;
    const publication=g.publication||{};
    const explicitPublished=publication.status==='published'||g.status==='published';
    const gatePassed=publication.gate_passed===true||g.gate_passed===true;
    const sources=sourcesOf(g);
    const screenshots=screenshotsOf(g);
    const videos=videosOf(g);
    const features=featuresOf(g);
    const mats=materialsOf(g);
    const publicTabs=Object.values(mats).filter(Array.isArray);
    const tabsValid=publicTabs.every(x=>x.length>0);
    const identityConfirmed=Boolean(g.appid||g.igdb_id||g.rawg_id||g.identity?.steam_appid||g.identity?.igdb_id||g.identity?.rawg_id);
    const metadata=hasText(g.title,2)&&hasText(g.release||g.releaseDate||String(g.year||''),2)&&list(g.genres).length>0&&list(g.platforms).length>0&&hasText(g.developer||list(g.developers)[0]||'',2)&&hasText(g.publisher||list(g.publishers)[0]||'',2);
    const editorial=hasText(g.description||g.editorial?.short_description||'',80)&&hasText(g.about||g.editorial?.full_overview||'',250)&&hasText(g.story||g.editorial?.story||'',80)&&features.length>=4;
    const media=hasText(g.hero||g.heroImage||g.media?.hero_images?.[0]||'',8)&&hasText(g.poster||g.capsuleImage||'',8)&&screenshots.length>=6&&videos.length>=1;
    const sourceQuality=sources.length>=10&&sources.length<=20&&sources.every(s=>hasText(s.url||'',8)&&hasText(s.source_name||s.name||s.source||'',2));
    const ratingReady=Number(g.rating||g.igropoiskRating||g.ratings?.igropoisk_rating||0)>0||g.rating_status==='insufficient_data';
    return explicitPublished&&gatePassed&&identityConfirmed&&metadata&&editorial&&media&&sourceQuality&&ratingReady&&tabsValid;
  };

  const guard=()=>{
    if(typeof state==='undefined'||!state||!Array.isArray(state.games))return;
    const qualified=state.games.filter(window.IGROPOISK_PUBLISH_GATE);
    if(qualified.length===state.games.length)return;
    state.games=qualified;
    if(Array.isArray(state.filtered))state.filtered=state.filtered.filter(window.IGROPOISK_PUBLISH_GATE);
    if(state.route==='game'&&!state.games.some(g=>String(g.id)===String(state.id))){
      state.route='catalog';state.id=null;state.tab='about';
      if(location.hash.startsWith('#game/'))history.replaceState(null,'','#catalog');
    }
  };

  const originalRender=typeof render==='function'?render:null;
  if(originalRender){
    render=function(){
      guard();
      const app=document.querySelector('#app');
      if(!state.games.length){
        app.innerHTML='<section class="section"><div class="empty"><h2>Публичный каталог готовится</h2><p>Игры не публикуются до прохождения полной проверки: 10–20 источников, интегрированное описание, сюжет, особенности, минимум 6 скриншотов, официальное видео и проверка качества.</p></div></section>';
        return;
      }
      return originalRender();
    };
  }

  const timer=setInterval(()=>{
    if(typeof state!=='undefined'&&state&&Array.isArray(state.games)&&state.games.length){guard();if(typeof render==='function')render();clearInterval(timer)}
  },50);
  setTimeout(()=>clearInterval(timer),10000);
})();