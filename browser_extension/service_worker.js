const LIFE_OS_BASE = 'https://nkuchenov-hash.github.io/Counter/';
const LIFE_OS_MATCH = 'https://nkuchenov-hash.github.io/Counter/*';
const MAX_TEXT_LENGTH = 1600;
const BRIDGE_TIMEOUT_MS = 12000;
const BRIDGE_POLL_MS = 250;
const OPEN_TAB_SNAPSHOT_WAIT_MS = 2200;

function requestId() {
  if (globalThis.crypto?.randomUUID) {
    return globalThis.crypto.randomUUID();
  }
  return `life-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function cleanText(value) {
  return String(value ?? '').trim().slice(0, MAX_TEXT_LENGTH);
}

function bridgeUrl(action, id, text = '') {
  const url = new URL(LIFE_OS_BASE);
  url.searchParams.set('life_source', 'browser_extension');
  url.searchParams.set('life_action', action);
  url.searchParams.set('life_request', id);
  url.searchParams.set('life_bridge', '1');
  const cleaned = cleanText(text);
  if (cleaned) {
    url.searchParams.set('life_text', cleaned);
  }
  return url.toString();
}

async function findLifeOsTabs() {
  return (await chrome.tabs.query({ url: LIFE_OS_MATCH }))
    .filter((tab) => Number.isInteger(tab.id));
}

async function findLifeOsTab() {
  const tabs = await findLifeOsTabs();
  return tabs[0] ?? null;
}

async function focusTab(tab) {
  if (Number.isInteger(tab.windowId)) {
    await chrome.windows.update(tab.windowId, { focused: true });
  }
  await chrome.tabs.update(tab.id, { active: true });
}

async function openLifeOs() {
  const tab = await findLifeOsTab();
  if (tab) {
    await focusTab(tab);
    return;
  }
  await chrome.tabs.create({ url: LIFE_OS_BASE, active: true });
}

async function readBridgeData(tabId) {
  const results = await chrome.scripting.executeScript({
    target: { tabId },
    world: 'MAIN',
    func: () => {
      function decode(raw) {
        let value = raw;
        for (let i = 0; i < 3 && typeof value === 'string'; i += 1) {
          try {
            value = JSON.parse(value);
          } catch (_) {
            break;
          }
        }
        return value;
      }

      function readBySuffix(suffix) {
        try {
          for (let i = 0; i < localStorage.length; i += 1) {
            const key = localStorage.key(i);
            if (!key) continue;
            if (key === suffix || key.endsWith(suffix)) {
              return decode(localStorage.getItem(key));
            }
          }
        } catch (_) {}
        return null;
      }

      return {
        snapshot: readBySuffix('browser_extension_record_snapshot_v2'),
        response: readBySuffix('browser_extension_response_v2'),
      };
    },
  });

  return results?.[0]?.result ?? { snapshot: null, response: null };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function cacheSnapshot(snapshot) {
  if (!snapshot || typeof snapshot !== 'object') return;
  await chrome.storage.local.set({ lifeOsLastSnapshot: snapshot });
}

async function readCachedSnapshot() {
  const saved = await chrome.storage.local.get('lifeOsLastSnapshot');
  return saved.lifeOsLastSnapshot && typeof saved.lifeOsLastSnapshot === 'object'
    ? saved.lifeOsLastSnapshot
    : null;
}

async function broadcastSnapshot(snapshot) {
  if (!snapshot || typeof snapshot !== 'object') return;
  try {
    await chrome.runtime.sendMessage({
      type: 'lifeOsStateUpdated',
      snapshot,
    });
  } catch (_) {}
}

async function readSnapshotFromOpenTab() {
  const tabs = await findLifeOsTabs();
  for (const tab of tabs) {
    try {
      const data = await readBridgeData(tab.id);
      if (data?.snapshot && typeof data.snapshot === 'object') {
        await cacheSnapshot(data.snapshot);
        return data.snapshot;
      }
    } catch (_) {}
  }
  return null;
}

async function waitForSnapshotFromTab(tabId, timeoutMs = OPEN_TAB_SNAPSHOT_WAIT_MS) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    try {
      const data = await readBridgeData(tabId);
      if (data?.snapshot && typeof data.snapshot === 'object') {
        await cacheSnapshot(data.snapshot);
        return data.snapshot;
      }
    } catch (_) {}
    await sleep(BRIDGE_POLL_MS);
  }
  return null;
}

async function waitForBridgeResponse(tabId, id) {
  const started = Date.now();
  while (Date.now() - started < BRIDGE_TIMEOUT_MS) {
    try {
      const data = await readBridgeData(tabId);
      if (
        data?.response &&
        typeof data.response === 'object' &&
        data.response.requestId === id
      ) {
        if (data.snapshot && typeof data.snapshot === 'object') {
          await cacheSnapshot(data.snapshot);
        }
        return data;
      }
    } catch (_) {}
    await sleep(BRIDGE_POLL_MS);
  }
  throw new Error('LIFE OS bridge timed out.');
}

async function runBridgeAction(action, text = '') {
  const id = requestId();
  const tab = await chrome.tabs.create({
    url: bridgeUrl(action, id, text),
    active: false,
  });

  if (!Number.isInteger(tab.id)) {
    throw new Error('Could not create LIFE OS bridge tab.');
  }

  try {
    const data = await waitForBridgeResponse(tab.id, id);
    const response = data.response ?? {};
    return {
      ok: response.ok === true,
      error: response.error ? String(response.error) : null,
      snapshot:
        data.snapshot && typeof data.snapshot === 'object'
          ? data.snapshot
          : null,
    };
  } finally {
    try {
      await chrome.tabs.remove(tab.id);
    } catch (_) {}
  }
}

async function refreshLifeOsStateInBackground() {
  try {
    const tabs = await findLifeOsTabs();
    for (const tab of tabs) {
      const snapshot = await waitForSnapshotFromTab(tab.id);
      if (snapshot) {
        await broadcastSnapshot(snapshot);
        return snapshot;
      }
    }

    const result = await runBridgeAction('bridge_sync');
    if (result.ok && result.snapshot) {
      await cacheSnapshot(result.snapshot);
      await broadcastSnapshot(result.snapshot);
      return result.snapshot;
    }
  } catch (_) {}
  return null;
}

async function getLifeOsState() {
  const openSnapshot = await readSnapshotFromOpenTab();
  if (openSnapshot) {
    return { ok: true, snapshot: openSnapshot, refreshing: false };
  }

  const cached = await readCachedSnapshot();
  if (cached) {
    refreshLifeOsStateInBackground().catch(() => {});
    return { ok: true, snapshot: cached, refreshing: true };
  }

  const tabs = await findLifeOsTabs();
  for (const tab of tabs) {
    const snapshot = await waitForSnapshotFromTab(tab.id);
    if (snapshot) {
      return { ok: true, snapshot, refreshing: false };
    }
  }

  try {
    const result = await runBridgeAction('bridge_sync');
    if (result.ok && result.snapshot) {
      return { ok: true, snapshot: result.snapshot, refreshing: false };
    }
    return {
      ok: false,
      authRequired: true,
      error: result.error ?? 'LIFE OS is not ready.',
    };
  } catch (error) {
    return {
      ok: false,
      authRequired: true,
      error: String(error),
    };
  }
}

async function warmSnapshotFromTab(tabId) {
  if (!Number.isInteger(tabId)) return;
  try {
    const snapshot = await waitForSnapshotFromTab(tabId, 3000);
    if (snapshot) {
      await broadcastSnapshot(snapshot);
    }
  } catch (_) {}
}

async function startRecord(text) {
  const cleaned = cleanText(text);
  if (!cleaned) {
    return { ok: false, error: 'Record title is empty.' };
  }
  try {
    const result = await runBridgeAction('start_record', cleaned);
    if (result.ok && result.snapshot) {
      await broadcastSnapshot(result.snapshot);
    }
    return result.ok
      ? { ok: true, snapshot: result.snapshot }
      : { ok: false, error: result.error ?? 'Could not start record.' };
  } catch (error) {
    return { ok: false, authRequired: true, error: String(error) };
  }
}

async function stopRecord() {
  try {
    const result = await runBridgeAction('stop_record');
    if (result.ok && result.snapshot) {
      await broadcastSnapshot(result.snapshot);
    }
    return result.ok
      ? { ok: true, snapshot: result.snapshot }
      : { ok: false, error: result.error ?? 'Could not stop record.' };
  } catch (error) {
    return { ok: false, authRequired: true, error: String(error) };
  }
}

chrome.runtime.onInstalled.addListener(async () => {
  await chrome.contextMenus.removeAll();
  chrome.contextMenus.create({
    id: 'life-os-start-selection',
    title: 'Start selection in LIFE OS',
    contexts: ['selection'],
  });
  chrome.contextMenus.create({
    id: 'life-os-start-page',
    title: 'Start page in LIFE OS',
    contexts: ['page'],
  });

  const tabs = await findLifeOsTabs();
  for (const tab of tabs) {
    warmSnapshotFromTab(tab.id).catch(() => {});
  }
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === 'life-os-start-selection') {
    const selected = cleanText(info.selectionText);
    if (selected) {
      void startRecord(selected);
    }
    return;
  }

  if (info.menuItemId === 'life-os-start-page') {
    const title = cleanText(tab?.title);
    if (title) {
      void startRecord(title);
    }
  }
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status !== 'complete') return;
  if (!tab?.url?.startsWith(LIFE_OS_BASE)) return;
  warmSnapshotFromTab(tabId).catch(() => {});
});

chrome.tabs.onActivated.addListener(({ tabId }) => {
  warmSnapshotFromTab(tabId).catch(() => {});
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (!message || typeof message !== 'object') {
    return false;
  }

  if (message.type === 'openLifeOs') {
    void openLifeOs()
      .then(() => sendResponse({ ok: true }))
      .catch((error) => sendResponse({ ok: false, error: String(error) }));
    return true;
  }

  if (message.type === 'getLifeOsState') {
    void getLifeOsState().then(sendResponse);
    return true;
  }

  if (message.type === 'startRecord') {
    void startRecord(message.text).then(sendResponse);
    return true;
  }

  if (message.type === 'stopRecord') {
    void stopRecord().then(sendResponse);
    return true;
  }

  return false;
});
