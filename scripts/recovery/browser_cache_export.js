/**
 * LIFE OS browser emergency recovery export (read-only).
 * Run only in DevTools on https://nkuchenov-hash.github.io/Counter/ in
 * the exact browser profile that was used before the backend outage.
 * Collects known local caches and IndexedDB journal without network traffic.
 * Deliberately excludes the PocketBase auth token and secret-related keys.
 */
(async () => {
  'use strict';
  const expectedOrigin = 'https://nkuchenov-hash.github.io';
  if (location.origin !== expectedOrigin || !location.pathname.startsWith('/Counter')) {
    throw new Error('Recovery exporter must be run on the original LIFE OS GitHub Pages website.');
  }
  const exported = {
    format: 'lifeos-browser-recovery-v1',
    createdUtc: new Date().toISOString(),
    origin: location.origin,
    originPath: '/Counter/',
    notice: 'Contains PRIVATE user data. Keep offline and never upload publicly.',
    identity: {},
    localStorage: {},
    indexedDB: {},
    errors: [],
  };

  const candidateKey = /^(?:flutter\.)?(?:cache_records_flat_v1|cache_categories_raw_v1|cache_plans_day_v1|warm_plans_snapshots_v1|warm_timeline_snapshots_v1|record_mutation_outbox_v1|plan_mutation_outbox_v1|plan_create_outbox_v1|category_mutation_outbox_v1_)/i;
  const forbiddenKey = /(?:auth|token|secret|password|api[_-]?key|oauth|credential|session|private[_-]?key)/i;

  function parseMaybeJson(v) {
    try {
      const one = JSON.parse(v);
      if (typeof one === 'string') {
        try { return JSON.parse(one); } catch (_) { return one; }
      }
      return one;
    } catch (_) { return null; }
  }

  for (let i = 0; i < localStorage.length; i += 1) {
    const key = localStorage.key(i);
    if (!key) continue;
    if (/(^|\.)pb_auth$/i.test(key)) {
      const auth = parseMaybeJson(localStorage.getItem(key));
      if (auth && typeof auth === 'object') {
        const record = auth.record || auth.model || {};
        if (typeof record.id === 'string') exported.identity.pocketBaseId = record.id;
        if (typeof record.user_id === 'string') exported.identity.businessUserId = record.user_id;
        if (typeof record.email === 'string') exported.identity.email = record.email;
      }
      continue; // NEVER export the auth JWT or the raw auth object.
    }
    if (!candidateKey.test(key) || forbiddenKey.test(key)) continue;
    exported.localStorage[key] = localStorage.getItem(key);
  }

  function openExistingDb(name) {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open(name);
      req.onupgradeneeded = () => {
        req.transaction.abort();
        reject(new Error('Refused to create a missing IndexedDB database'));
      };
      req.onerror = () => reject(req.error || new Error('Could not open IndexedDB database'));
      req.onsuccess = () => resolve(req.result);
    });
  }

  function readStore(db, storeName) {
    return new Promise((resolve, reject) => {
      const rows = [];
      const txn = db.transaction(storeName, 'readonly');
      const request = txn.objectStore(storeName).openCursor();
      request.onsuccess = () => {
        const cursor = request.result;
        if (!cursor) return;
        rows.push({ key: cursor.key, value: cursor.value });
        cursor.continue();
      };
      request.onerror = () => reject(request.error || new Error('Cursor error'));
      txn.onerror = () => reject(txn.error || new Error('Transaction error'));
      txn.onabort = () => reject(txn.error || new Error('Transaction aborted'));
      txn.oncomplete = () => resolve(rows);
    });
  }

  if (typeof indexedDB.databases === 'function') {
    try {
      const dbs = await indexedDB.databases();
      const targets = dbs.map((d) => d.name).filter((n) =>
        typeof n === 'string' && n.toLowerCase().includes('lifeos_record_journal_v1'));
      for (const name of targets) {
        const db = await openExistingDb(name);
        try {
          const names = Array.from(db.objectStoreNames);
          exported.indexedDB[name] = {};
          for (const storeName of names) {
            exported.indexedDB[name][storeName] = await readStore(db, storeName);
          }
        } finally {
          db.close();
        }
      }
    } catch (e) {
      exported.errors.push('IndexedDB read failed: ' + String(e));
    }
  } else {
    exported.errors.push('indexedDB.databases() unavailable: IndexedDB journal not exported.');
  }

  const keyCount = Object.keys(exported.localStorage).length;
  const dbCount = Object.keys(exported.indexedDB).length;
  const rowCount = Object.values(exported.indexedDB)
    .reduce((sum, stores) => sum + Object.values(stores).reduce((n, items) => n + items.length, 0), 0);
  if (keyCount === 0 && rowCount === 0) {
    throw new Error('No LIFE OS local cache found in this browser profile. Nothing exported.');
  }
  const blob = new Blob([JSON.stringify(exported, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  try {
    const a = document.createElement('a');
    a.href = url;
    a.download = 'LIFEOS-BROWSER-RECOVERY-' + new Date().toISOString().slice(0, 10) + '.json';
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    a.remove();
  } finally {
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  console.info('LIFE OS recovery file saved. localStorage keys:', keyCount,
    'IndexedDB databases:', dbCount, 'IndexedDB rows:', rowCount,
    'warnings:', exported.errors);
})();