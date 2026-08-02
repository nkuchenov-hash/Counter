import fs from 'node:fs/promises';
import path from 'node:path';
import { XMLParser } from 'fast-xml-parser';

const ROOT = path.resolve('igropoisk');
const DATA = path.join(ROOT, 'data');
const parser = new XMLParser({ ignoreAttributes: false });
const delay = ms => new Promise(r => setTimeout(r, ms));
const clean = s => String(s || '').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
const to10 = (positive, negative) => {
  const total = Number(positive || 0) + Number(negative || 0);
  return total ? Math.round((Number(positive || 0) / total) * 100) / 10 : null;
};

async function getJson(url) {
  const r = await fetch(url, { headers: { 'user-agent': 'IgropoiskAggregator/0.1' } });
  if (!r.ok) throw new Error(`${r.status} ${url}`);
  return r.json();
}

async function getText(url) {
  const r = await fetch(url, { headers: { 'user-agent': 'IgropoiskAggregator/0.1' } });
  if (!r.ok) throw new Error(`${r.status} ${url}`);
  return r.text();
}

async function collectSteamSpy(limit = 500) {
  const raw = await getJson('https://steamspy.com/api.php?request=top100in2weeks');
  let rows = Object.values(raw);
  for (let page = 1; rows.length < limit && page < 6; page++) {
    try {
      const more = await getJson(`https://steamspy.com/api.php?request=all&page=${page}`);
      rows.push(...Object.values(more));
    } catch (e) {
      console.warn('SteamSpy page failed', page, e.message);
    }
  }
  const uniq = new Map();
  for (const x of rows) {
    const appid = Number(x.appid);
    if (!appid || !x.name) continue;
    uniq.set(appid, {
      appid,
      title: x.name,
      developer: x.developer || '',
      publisher: x.publisher || '',
      genres: String(x.genre || '').split(',').map(s => s.trim()).filter(Boolean),
      tags: Object.keys(x.tags || {}).slice(0, 12),
      steamUserRating: to10(x.positive, x.negative),
      owners: x.owners || '',
      peakConcurrent: Number(x.ccu || 0),
      sourceUpdatedAt: new Date().toISOString()
    });
  }
  return [...uniq.values()].slice(0, limit);
}

async function enrichSteam(game) {
  try {
    const all = await getJson(`https://store.steampowered.com/api/appdetails?appids=${game.appid}&l=russian&cc=ru`);
    const d = all?.[game.appid]?.data;
    if (!d || d.type !== 'game') return null;
    return {
      ...game,
      title: d.name || game.title,
      description: clean(d.short_description),
      about: clean(d.about_the_game),
      releaseDate: d.release_date?.date || '',
      comingSoon: Boolean(d.release_date?.coming_soon),
      developers: d.developers || (game.developer ? [game.developer] : []),
      publishers: d.publishers || (game.publisher ? [game.publisher] : []),
      genres: d.genres?.map(x => x.description) || game.genres,
      categories: d.categories?.map(x => x.description) || [],
      platforms: Object.entries(d.platforms || {}).filter(([,v]) => v).map(([k]) => k),
      headerImage: d.header_image,
      capsuleImage: `https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_600x900.jpg`,
      heroImage: `https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_hero.jpg`,
      screenshots: (d.screenshots || []).slice(0, 12).map(x => x.path_full),
      movies: (d.movies || []).slice(0, 3).map(x => ({ name: x.name, thumbnail: x.thumbnail, webm: x.webm?.max })),
      website: d.website || '',
      metacriticRaw: d.metacritic?.score || null,
      criticRating: d.metacritic?.score ? Math.round(d.metacritic.score) / 10 : null,
      recommendations: d.recommendations?.total || 0,
      sourceLinks: {
        steam: `https://store.steampowered.com/app/${game.appid}/`,
        metacritic: d.metacritic?.url || '',
        steamSpy: `https://steamspy.com/app/${game.appid}`
      }
    };
  } catch (e) {
    console.warn('Steam details failed', game.appid, e.message);
    return game;
  }
}

const feeds = [
  { name: 'IGN', lang: 'en', url: 'https://feeds.feedburner.com/ign/all' },
  { name: 'PC Gamer', lang: 'en', url: 'https://www.pcgamer.com/rss/' },
  { name: 'Rock Paper Shotgun', lang: 'en', url: 'https://www.rockpapershotgun.com/feed' },
  { name: 'GameSpot', lang: 'en', url: 'https://www.gamespot.com/feeds/mashup/' },
  { name: 'StopGame', lang: 'ru', url: 'https://rss.stopgame.ru/rss_all.xml' },
  { name: 'Игромания', lang: 'ru', url: 'https://www.igromania.ru/rss/news/' }
];

function rssItems(doc) {
  const channel = doc?.rss?.channel;
  if (channel) return Array.isArray(channel.item) ? channel.item : [channel.item].filter(Boolean);
  const feed = doc?.feed;
  if (feed) return Array.isArray(feed.entry) ? feed.entry : [feed.entry].filter(Boolean);
  return [];
}

async function collectArticles() {
  const out = [];
  for (const src of feeds) {
    try {
      const xml = await getText(src.url);
      const doc = parser.parse(xml);
      for (const item of rssItems(doc).slice(0, 100)) {
        const link = typeof item.link === 'string' ? item.link : item.link?.['@_href'] || item.guid || '';
        const title = clean(item.title);
        if (!title || !link) continue;
        out.push({
          source: src.name,
          language: src.lang,
          title,
          url: String(link),
          summary: clean(item.description || item.summary || item['content:encoded']).slice(0, 420),
          publishedAt: item.pubDate || item.published || item.updated || null
        });
      }
    } catch (e) {
      console.warn('Feed failed', src.name, e.message);
    }
  }
  return out;
}

function attachArticles(games, articles) {
  return games.map(game => {
    const terms = [game.title, ...game.title.split(/[:\-–—]/)].map(s => s.trim().toLowerCase()).filter(s => s.length > 3);
    const related = articles.filter(a => terms.some(t => a.title.toLowerCase().includes(t))).slice(0, 30);
    return { ...game, articles: related };
  });
}

function igropoiskRating(game) {
  const values = [game.criticRating, game.steamUserRating].filter(Number.isFinite);
  if (!values.length) return null;
  const critic = Number.isFinite(game.criticRating) ? game.criticRating * 0.65 : 0;
  const users = Number.isFinite(game.steamUserRating) ? game.steamUserRating * (Number.isFinite(game.criticRating) ? 0.35 : 1) : 0;
  return Math.round((critic + users) * 10) / 10;
}

await fs.mkdir(DATA, { recursive: true });
const base = await collectSteamSpy(500);
const enriched = [];
for (let i = 0; i < base.length; i++) {
  const game = await enrichSteam(base[i]);
  if (game) enriched.push(game);
  if (i % 20 === 19) console.log(`enriched ${i + 1}/${base.length}`);
  await delay(120);
}
const articles = await collectArticles();
const linked = attachArticles(enriched, articles).map(g => ({ ...g, igropoiskRating: igropoiskRating(g) }));
linked.sort((a,b) => (b.igropoiskRating || 0) - (a.igropoiskRating || 0));
await fs.writeFile(path.join(DATA, 'catalog.json'), JSON.stringify({ updatedAt: new Date().toISOString(), count: linked.length, games: linked }, null, 2));
await fs.writeFile(path.join(DATA, 'articles.json'), JSON.stringify({ updatedAt: new Date().toISOString(), count: articles.length, articles }, null, 2));
console.log(`saved ${linked.length} games and ${articles.length} articles`);
