import fs from 'node:fs/promises';
import path from 'node:path';
import { XMLParser } from 'fast-xml-parser';

const ROOT=path.resolve('igropoisk');
const DATA=path.join(ROOT,'data');
const parser=new XMLParser({ignoreAttributes:false});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const clean=s=>String(s||'').replace(/<[^>]+>/g,' ').replace(/\s+/g,' ').trim();
const to10=(p,n)=>{const t=Number(p||0)+Number(n||0);return t?Math.round((Number(p||0)/t)*100)/10:null};

async function getJson(url){const r=await fetch(url,{headers:{'user-agent':'IgropoiskAggregator/1.0'}});if(!r.ok)throw new Error(`${r.status} ${url}`);return r.json()}
async function getText(url){const r=await fetch(url,{headers:{'user-agent':'IgropoiskAggregator/1.0'}});if(!r.ok)throw new Error(`${r.status} ${url}`);return r.text()}

async function collectCandidates(){
  const requests=['top100forever','top100owned','top100in2weeks'];
  const map=new Map();
  for(const request of requests){
    const raw=await getJson(`https://steamspy.com/api.php?request=${request}`);
    for(const x of Object.values(raw)){
      const appid=Number(x.appid); if(!appid||!x.name)continue;
      const row={appid,title:x.name,developer:x.developer||'',publisher:x.publisher||'',genres:String(x.genre||'').split(',').map(v=>v.trim()).filter(Boolean),tags:Object.keys(x.tags||{}).slice(0,12),steamUserRating:to10(x.positive,x.negative),owners:x.owners||'',peakConcurrent:Number(x.ccu||0),positive:Number(x.positive||0),negative:Number(x.negative||0)};
      const prev=map.get(appid); if(!prev||row.peakConcurrent>prev.peakConcurrent)map.set(appid,row);
    }
  }
  return [...map.values()].sort((a,b)=>(b.peakConcurrent-a.peakConcurrent)||((b.positive+b.negative)-(a.positive+a.negative))).slice(0,260);
}

async function enrich(game){
  try{
    const all=await getJson(`https://store.steampowered.com/api/appdetails?appids=${game.appid}&l=russian&cc=ru`);
    const d=all?.[game.appid]?.data;
    if(!d||d.type!=='game'||!d.name||!d.short_description||!d.header_image||!(d.screenshots||[]).length)return null;
    const critics=d.metacritic?.score?Math.round(d.metacritic.score)/10:null;
    const users=game.steamUserRating;
    const rating=critics&&users?Math.round((critics*.65+users*.35)*10)/10:(critics||users||null);
    return {id:String(game.appid),appid:game.appid,title:d.name,year:Number(String(d.release_date?.date||'').match(/(?:19|20)\d{2}/)?.[0]||0),releaseDate:d.release_date?.date||'',comingSoon:Boolean(d.release_date?.coming_soon),genres:(d.genres||[]).map(x=>x.description),platforms:Object.entries(d.platforms||{}).filter(([,v])=>v).map(([k])=>k),developers:d.developers||[],publishers:d.publishers||[],description:clean(d.short_description),about:clean(d.about_the_game),story:clean(d.about_the_game),features:(d.categories||[]).map(x=>x.description).slice(0,12),poster:`https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_600x900.jpg`,hero:`https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_hero.jpg`,capsuleImage:`https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_600x900.jpg`,heroImage:`https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_hero.jpg`,headerImage:d.header_image,screenshots:(d.screenshots||[]).slice(0,12).map(x=>x.path_full),movies:(d.movies||[]).slice(0,3).map(x=>({name:x.name,thumbnail:x.thumbnail,webm:x.webm?.max||''})),rating,criticRating:critics,userRating:users,steamUserRating:users,popularityScore:game.peakConcurrent+(d.recommendations?.total||0),recommendations:d.recommendations?.total||0,sourceLinks:{steam:`https://store.steampowered.com/app/${game.appid}/`,steamSpy:`https://steamspy.com/app/${game.appid}`,metacritic:d.metacritic?.url||''},materials:{articles:[],reviews:[],guides:[],tips:[],news:[]}};
  }catch(e){console.warn('Steam details failed',game.appid,e.message);return null}
}

const feeds=[
{name:'IGN',lang:'en',url:'https://feeds.feedburner.com/ign/all'},
{name:'PC Gamer',lang:'en',url:'https://www.pcgamer.com/rss/'},
{name:'Rock Paper Shotgun',lang:'en',url:'https://www.rockpapershotgun.com/feed'},
{name:'GameSpot',lang:'en',url:'https://www.gamespot.com/feeds/mashup/'},
{name:'StopGame',lang:'ru',url:'https://rss.stopgame.ru/rss_all.xml'},
{name:'Игромания',lang:'ru',url:'https://www.igromania.ru/rss/news/'}
];
function rssItems(doc){const c=doc?.rss?.channel;if(c)return Array.isArray(c.item)?c.item:[c.item].filter(Boolean);const f=doc?.feed;if(f)return Array.isArray(f.entry)?f.entry:[f.entry].filter(Boolean);return []}
async function collectArticles(){const out=[];for(const src of feeds){try{const doc=parser.parse(await getText(src.url));for(const item of rssItems(doc).slice(0,120)){const link=typeof item.link==='string'?item.link:item.link?.['@_href']||item.guid||'';const title=clean(item.title);if(!title||!link)continue;out.push({source:src.name,language:src.lang,title,url:String(link),summary:clean(item.description||item.summary||item['content:encoded']).slice(0,420),publishedAt:item.pubDate||item.published||item.updated||null})}}catch(e){console.warn('Feed failed',src.name,e.message)}}return out}
function classify(title){const s=title.toLowerCase();if(/review|обзор|рецензи/.test(s))return'reviews';if(/guide|гайд|walkthrough|прохожд/.test(s))return'guides';if(/tips|совет|best build|лучшие билд/.test(s))return'tips';if(/news|анонс|вышел|релиз|update|patch|обновлен/.test(s))return'news';return'articles'}
function attach(games,articles){return games.map(g=>{const terms=[g.title,...g.title.split(/[:\-–—]/)].map(x=>x.trim().toLowerCase()).filter(x=>x.length>3);const m={articles:[],reviews:[],guides:[],tips:[],news:[]};for(const a of articles){if(terms.some(t=>a.title.toLowerCase().includes(t)))m[classify(a.title)].push(a)}for(const k of Object.keys(m))m[k]=m[k].slice(0,20);return{...g,materials:m,articles:Object.values(m).flat()}})}

await fs.mkdir(DATA,{recursive:true});
const candidates=await collectCandidates();
const games=[];
for(let i=0;i<candidates.length&&games.length<200;i++){
  const g=await enrich(candidates[i]); if(g)games.push(g);
  if(i%20===19)console.log(`processed ${i+1}/${candidates.length}; accepted ${games.length}`);
  await sleep(120);
}
const articles=await collectArticles();
const linked=attach(games,articles).sort((a,b)=>(b.popularityScore-a.popularityScore)||((b.rating||0)-(a.rating||0))).slice(0,200);
await fs.writeFile(path.join(DATA,'catalog.json'),JSON.stringify({updatedAt:new Date().toISOString(),count:linked.length,games:linked},null,2));
await fs.writeFile(path.join(DATA,'articles.json'),JSON.stringify({updatedAt:new Date().toISOString(),count:articles.length,articles},null,2));
console.log(`saved ${linked.length} games and ${articles.length} materials`);
