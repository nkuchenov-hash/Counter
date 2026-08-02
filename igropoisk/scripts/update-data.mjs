import fs from 'node:fs/promises';
import path from 'node:path';
import { XMLParser } from 'fast-xml-parser';

const ROOT = path.resolve('igropoisk');
const DATA = path.join(ROOT, 'data');
const TARGET_SIZE = 140;
const MAX_ENRICH = 240;
const parser = new XMLParser({ ignoreAttributes: false, attributeNamePrefix: '@_' });
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const clean = value => String(value || '').replace(/<[^>]+>/g, ' ').replace(/&nbsp;/g, ' ').replace(/\s+/g, ' ').trim();
const normalizeTitle = value => clean(value).toLowerCase().replace(/[™®©]/g, '').replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
const to10 = (positive, negative) => {
  const p = Number(positive || 0);
  const n = Number(negative || 0);
  return p + n ? Math.round((p / (p + n)) * 100) / 10 : null;
};
const yearOf = value => Number(String(value || '').match(/(?:19|20)\d{2}/)?.[0] || 0);

async function request(url, type = 'json') {
  const response = await fetch(url, {
    headers: {
      'user-agent': 'IgropoiskAggregator/1.0 (+https://nkuchenov-hash.github.io/Counter/igropoisk/)',
      accept: type === 'json' ? 'application/json,text/plain,*/*' : 'application/rss+xml,application/xml,text/xml,*/*'
    },
    signal: AbortSignal.timeout(30000)
  });
  if (!response.ok) throw new Error(`${response.status} ${url}`);
  return type === 'json' ? response.json() : response.text();
}

async function steamSpyList(requestName) {
  try {
    const data = await request(`https://steamspy.com/api.php?request=${requestName}`);
    return Object.values(data || {});
  } catch (error) {
    console.warn(`SteamSpy ${requestName} failed:`, error.message);
    return [];
  }
}

async function collectCandidates() {
  const groups = await Promise.all([
    steamSpyList('top100in2weeks'),
    steamSpyList('top100forever'),
    steamSpyList('top100owned')
  ]);
  const candidates = new Map();
  for (const [groupIndex, rows] of groups.entries()) {
    for (const row of rows) {
      const appid = Number(row.appid);
      if (!appid || !row.name) continue;
      const previous = candidates.get(appid) || {};
      const positive = Number(row.positive || previous.positive || 0);
      const negative = Number(row.negative || previous.negative || 0);
      const evidence = new Set(previous.sourceEvidence || []);
      evidence.add('SteamSpy');
      candidates.set(appid, {
        ...previous,
        appid,
        title: row.name,
        developer: row.developer || previous.developer || '',
        publisher: row.publisher || previous.publisher || '',
        genres: String(row.genre || previous.genre || '').split(',').map(x => x.trim()).filter(Boolean),
        tags: Object.keys(row.tags || previous.tags || {}).slice(0, 20),
        positive,
        negative,
        steamUserRating: to10(positive, negative),
        recommendations: Number(row.recommendations || previous.recommendations || 0),
        owners: row.owners || previous.owners || '',
        peakConcurrent: Math.max(Number(row.ccu || 0), Number(previous.peakConcurrent || 0)),
        sourceEvidence: [...evidence],
        discoveryWeight: Math.max(Number(previous.discoveryWeight || 0), 3 - groupIndex)
      });
    }
  }
  return [...candidates.values()]
    .sort((a, b) => popularitySeed(b) - popularitySeed(a))
    .slice(0, MAX_ENRICH);
}

function ownerMidpoint(value) {
  const numbers = String(value || '').match(/[\d,]+/g)?.map(x => Number(x.replace(/,/g, ''))) || [];
  return numbers.length ? numbers.reduce((a, b) => a + b, 0) / numbers.length : 0;
}

function popularitySeed(game) {
  const reviews = Number(game.positive || 0) + Number(game.negative || 0);
  return Math.log10(ownerMidpoint(game.owners) + 1) * 20 + Math.log10(reviews + 1) * 16 + Math.log10(Number(game.peakConcurrent || 0) + 1) * 12 + Number(game.discoveryWeight || 0) * 8;
}

async function enrichSteam(game) {
  try {
    const payload = await request(`https://store.steampowered.com/api/appdetails?appids=${game.appid}&l=russian&cc=ru`);
    const data = payload?.[game.appid]?.data;
    if (!data || data.type !== 'game') return null;
    const evidence = new Set(game.sourceEvidence || []);
    evidence.add('Steam');
    if (data.metacritic?.score) evidence.add('Metacritic');
    const description = clean(data.short_description);
    const about = clean(data.about_the_game);
    return {
      ...game,
      id: String(game.appid),
      title: data.name || game.title,
      normalizedTitle: normalizeTitle(data.name || game.title),
      description,
      about,
      story: description,
      releaseDate: data.release_date?.date || '',
      year: yearOf(data.release_date?.date),
      comingSoon: Boolean(data.release_date?.coming_soon),
      developers: data.developers || (game.developer ? [game.developer] : []),
      publishers: data.publishers || (game.publisher ? [game.publisher] : []),
      genres: data.genres?.map(item => item.description).filter(Boolean) || game.genres,
      categories: data.categories?.map(item => item.description).filter(Boolean) || [],
      platforms: Object.entries(data.platforms || {}).filter(([, enabled]) => enabled).map(([platform]) => platform),
      headerImage: data.header_image || '',
      capsuleImage: `https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_600x900.jpg`,
      heroImage: `https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_hero.jpg`,
      screenshots: (data.screenshots || []).slice(0, 12).map(item => item.path_full).filter(Boolean),
      movies: (data.movies || []).slice(0, 3).map(item => ({ name: item.name, thumbnail: item.thumbnail, webm: item.webm?.max })).filter(item => item.webm),
      website: data.website || '',
      criticRating: data.metacritic?.score ? Math.round(data.metacritic.score) / 10 : null,
      metacriticUrl: data.metacritic?.url || '',
      recommendations: Math.max(Number(game.recommendations || 0), Number(data.recommendations?.total || 0)),
      sourceEvidence: [...evidence],
      sourceLinks: {
        steam: `https://store.steampowered.com/app/${game.appid}/`,
        steamSpy: `https://steamspy.com/app/${game.appid}`,
        metacritic: data.metacritic?.url || ''
      }
    };
  } catch (error) {
    console.warn(`Steam ${game.appid} failed:`, error.message);
    return null;
  }
}

const feeds = [
  { name: 'IGN', language: 'en', url: 'https://feeds.feedburner.com/ign/all' },
  { name: 'GameSpot', language: 'en', url: 'https://www.gamespot.com/feeds/mashup/' },
  { name: 'PC Gamer', language: 'en', url: 'https://www.pcgamer.com/rss/' },
  { name: 'Rock Paper Shotgun', language: 'en', url: 'https://www.rockpapershotgun.com/feed' },
  { name: 'Eurogamer', language: 'en', url: 'https://www.eurogamer.net/feed' },
  { name: 'Polygon', language: 'en', url: 'https://www.polygon.com/rss/index.xml' },
  { name: 'GamesRadar+', language: 'en', url: 'https://www.gamesradar.com/rss/' },
  { name: 'VG247', language: 'en', url: 'https://www.vg247.com/feed' },
  { name: 'StopGame', language: 'ru', url: 'https://rss.stopgame.ru/rss_all.xml' },
  { name: 'Игромания', language: 'ru', url: 'https://www.igromania.ru/rss/news/' }
];

function feedEntries(document) {
  const items = document?.rss?.channel?.item;
  if (items) return Array.isArray(items) ? items : [items];
  const entries = document?.feed?.entry;
  return entries ? (Array.isArray(entries) ? entries : [entries]) : [];
}

async function collectArticles() {
  const all = [];
  for (const source of feeds) {
    try {
      const xml = await request(source.url, 'text');
      const document = parser.parse(xml);
      for (const item of feedEntries(document).slice(0, 150)) {
        const rawLink = item.link;
        const link = typeof rawLink === 'string' ? rawLink : rawLink?.['@_href'] || item.guid || '';
        const title = clean(item.title);
        if (!title || !link) continue;
        all.push({
          source: source.name,
          language: source.language,
          title,
          normalizedTitle: normalizeTitle(title),
          url: String(link),
          summary: clean(item.description || item.summary || item['content:encoded']).slice(0, 600),
          publishedAt: item.pubDate || item.published || item.updated || null
        });
      }
    } catch (error) {
      console.warn(`${source.name} feed failed:`, error.message);
    }
  }
  const unique = new Map();
  for (const article of all) unique.set(article.url, article);
  return [...unique.values()].sort((a, b) => new Date(b.publishedAt || 0) - new Date(a.publishedAt || 0));
}

function relatedArticles(game, articles) {
  const aliases = new Set([
    game.normalizedTitle,
    ...String(game.title).split(/[:\-–—]/).map(normalizeTitle)
  ].filter(alias => alias.length >= 4));
  return articles.filter(article => [...aliases].some(alias => article.normalizedTitle.includes(alias))).slice(0, 40);
}

function classifyArticles(items) {
  const result = { articles: [], reviews: [], guides: [], tips: [], news: [] };
  for (const item of items) {
    const text = `${item.title} ${item.summary}`.toLowerCase();
    if (/review|обзор|реценз/.test(text)) result.reviews.push(item);
    else if (/guide|гайд|walkthrough|прохожд/.test(text)) result.guides.push(item);
    else if (/tip|совет|build|билд|best weapon|лучшие/.test(text)) result.tips.push(item);
    else if (/news|анонс|релиз|вышел|update|обновлен|трейлер|дата выхода/.test(text)) result.news.push(item);
    else result.articles.push(item);
  }
  return result;
}

function qualityGate(game) {
  if (!game.appid || !game.title || game.title.length < 2) return false;
  if (!game.description || game.description.length < 35) return false;
  if (!game.releaseDate || !game.year) return false;
  if (!game.developers?.length || !game.publishers?.length || !game.genres?.length) return false;
  if (!game.platforms?.length || !game.headerImage || !game.capsuleImage || !game.heroImage) return false;
  if (!game.screenshots?.length || game.screenshots.length < 2) return false;
  if (/soundtrack|demo|dedicated server|test server|benchmark|editor|sdk/i.test(game.title)) return false;
  const reviewCount = Number(game.positive || 0) + Number(game.negative || 0);
  const known = Number(game.criticRating || 0) >= 7 || Number(game.recommendations || 0) >= 1000 || reviewCount >= 5000 || ownerMidpoint(game.owners) >= 100000;
  return known;
}

function finalPopularity(game) {
  const reviewCount = Number(game.positive || 0) + Number(game.negative || 0);
  return popularitySeed(game) + Math.log10(Number(game.recommendations || 0) + 1) * 18 + Math.log10(reviewCount + 1) * 12 + Number(game.criticRating || 0) * 6;
}

function selectAcrossYears(games, target) {
  const sorted = [...games].sort((a, b) => finalPopularity(b) - finalPopularity(a));
  const selected = [];
  const perYear = new Map();
  for (const game of sorted) {
    const year = game.year || 0;
    const cap = year >= new Date().getFullYear() - 2 ? 18 : 10;
    if ((perYear.get(year) || 0) >= cap) continue;
    selected.push(game);
    perYear.set(year, (perYear.get(year) || 0) + 1);
    if (selected.length >= target) break;
  }
  if (selected.length < target) {
    const ids = new Set(selected.map(game => game.appid));
    for (const game of sorted) {
      if (ids.has(game.appid)) continue;
      selected.push(game);
      ids.add(game.appid);
      if (selected.length >= target) break;
    }
  }
  return selected;
}

function igropoiskRating(game) {
  const critic = Number.isFinite(game.criticRating) ? game.criticRating : null;
  const users = Number.isFinite(game.steamUserRating) ? game.steamUserRating : null;
  if (critic != null && users != null) return Math.round((critic * 0.65 + users * 0.35) * 10) / 10;
  return critic ?? users ?? null;
}

await fs.mkdir(DATA, { recursive: true });
console.log('Collecting candidates…');
const candidates = await collectCandidates();
console.log(`Candidates: ${candidates.length}`);

const enriched = [];
for (let index = 0; index < candidates.length; index += 1) {
  const game = await enrichSteam(candidates[index]);
  if (game && qualityGate(game)) enriched.push(game);
  if ((index + 1) % 20 === 0) console.log(`Enriched ${index + 1}/${candidates.length}; accepted ${enriched.length}`);
  await sleep(160);
}

console.log('Collecting editorial feeds…');
const articles = await collectArticles();
const selected = selectAcrossYears(enriched, TARGET_SIZE).map(game => {
  const related = relatedArticles(game, articles);
  const editorialSources = [...new Set(related.map(article => article.source))];
  const sourceEvidence = [...new Set([...(game.sourceEvidence || []), ...editorialSources])];
  return {
    ...game,
    popularityScore: Math.round(finalPopularity(game) * 100) / 100,
    igropoiskRating: igropoiskRating(game),
    editorialSources,
    sourceEvidence,
    materials: classifyArticles(related),
    articles: related
  };
});

selected.sort((a, b) => b.popularityScore - a.popularityScore);
const now = new Date().toISOString();
await fs.writeFile(path.join(DATA, 'catalog.json'), JSON.stringify({ updatedAt: now, count: selected.length, sourcePool: ['Steam', 'SteamSpy', 'Metacritic', ...feeds.map(feed => feed.name)], games: selected }, null, 2));
await fs.writeFile(path.join(DATA, 'articles.json'), JSON.stringify({ updatedAt: now, count: articles.length, sources: feeds.map(feed => feed.name), articles }, null, 2));
console.log(`Saved ${selected.length} games and ${articles.length} editorial materials.`);
