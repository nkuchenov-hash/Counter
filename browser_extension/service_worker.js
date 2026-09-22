const LIFE_OS_BASE = 'https://nkuchenov-hash.github.io/Counter/';
const LIFE_OS_MATCH = 'https://nkuchenov-hash.github.io/Counter/*';
const POCKETBASE_BASE = 'https://217-114-0-201.sslip.io';
const BRIDGE_VERSION = 3;
const MAX_TEXT_LENGTH = 1600;
const BRIDGE_TIMEOUT_MS = 12000;
const LIVE_COMMAND_ACK_TIMEOUT_MS = 6000;
const BRIDGE_SETTLE_TIMEOUT_MS = 90000;
const BRIDGE_POLL_MS = 250;
const OPEN_TAB_SNAPSHOT_WAIT_MS = 2200;

let refreshPromise = null;
let mutationPromise = null;
let realtimeAuthSnapshot = null;

function requestId() {
  if (globalThis.crypto?.randomUUID) return globalThis.crypto.randomUUID();
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
  if (cleaned) url.searchParams.set('life_text', cleaned);
  return url.toString();
}

function normalizeRealtimeAuth(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const token = String(raw.token ?? '').trim();
  const model = raw.model && typeof raw.model === 'object' ? raw.model : null;
  const ownerId = String(model?.id ?? '').trim();
  if (!token || !ownerId) return null;
  return { token, ownerId };
}

function rememberRealtimeAuth(raw) {
  const normalized = normalizeRealtimeAuth(raw);
  if (normalized) realtimeAuthSnapshot = normalized;
  return normalized;
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
        auth: readBySuffix('pb_auth'),
      };
    },
  });

  const data = results?.[0]?.result ?? {
    snapshot: null,
    response: null,
    auth: null,
  };
  rememberRealtimeAuth(data.auth);
  return data;
}

function snapshotFromBridgeData(data) {
  const responseSnapshot = data?.response?.snapshot;
  if (responseSnapshot && typeof responseSnapshot === 'object') {
    return responseSnapshot;
  }
  return data?.snapshot && typeof data.snapshot === 'object'
    ? data.snapshot
    : null;
}

function supportsLiveUrlBridge(data) {
  const snapshot = snapshotFromBridgeData(data);
  return Number(snapshot?.bridgeVersion ?? 0) >= BRIDGE_VERSION;
}

async function putUrlCommandOnTab(tabId, action, id, text = '') {
  const results = await chrome.scripting.executeScript({
    target: { tabId },
    world: 'MAIN',
    args: [action, id, cleanText(text)],
    func: (commandAction, requestIdValue, commandText) => {
      try {
        const url = new URL(location.href);
        url.searchParams.set('life_source', 'browser_extension');
        url.searchParams.set('life_action', commandAction);
        url.searchParams.set('life_request', requestIdValue);
        url.searchParams.set('life_bridge', '1');
        if (commandText) url.searchParams.set('life_text', commandText);
        else url.searchParams.delete('life_text');
        history.replaceState(history.state, '', url.toString());
        return true;
      } catch (_) {
        return false;
      }
    },
  });
  return results?.[0]?.result === true;
}

async function clearUrlCommandFromTab(tabId, id) {
  try {
    await chrome.scripting.executeScript({
      target: { tabId },
      world: 'MAIN',
      args: [id],
      func: (requestIdValue) => {
        try {
          const url = new URL(location.href);
          if (url.searchParams.get('life_request') !== requestIdValue) return;
          for (const key of [
            'life_source',
            'life_action',
            'life_request',
            'life_bridge',
            'life_text',
            'life_target',
          ]) {
            url.searchParams.delete(key);
          }
          history.replaceState(history.state, '', url.toString());
        } catch (_) {}
      },
    });
  } catch (_) {}
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
    await chrome.runtime.sendMessage({ type: 'lifeOsStateUpdated', snapshot });
  } catch (_) {}
}

async function broadcastCommandFailure(response, snapshot) {
  try {
    await chrome.runtime.sendMessage({
      type: 'lifeOsCommandFailed',
      action: String(response?.action ?? ''),
      requestId: String(response?.requestId ?? ''),
      error: response?.error ? String(response.error) : 'command_not_confirmed',
      snapshot,
    });
  } catch (_) {}
}

async function readSnapshotFromOpenTab() {
  const tabs = await findLifeOsTabs();
  for (const tab of tabs) {
    try {
      const data = await readBridgeData(tab.id);
      const snapshot = snapshotFromBridgeData(data);
      if (snapshot) {
        await cacheSnapshot(snapshot);
        return snapshot;
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
      const snapshot = snapshotFromBridgeData(data);
      if (snapshot) {
        await cacheSnapshot(snapshot);
        return snapshot;
      }
    } catch (_) {}
    await sleep(BRIDGE_POLL_MS);
  }
  return null;
}

async function waitForBridgeResponse(
  tabId,
  id,
  { requireSettled = false, timeoutMs = BRIDGE_TIMEOUT_MS } = {},
) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    try {
      const data = await readBridgeData(tabId);
      const response = data?.response;
      const matches =
        response &&
        typeof response === 'object' &&
        response.requestId === id;
      const settled = response?.settled !== false;
      if (matches && (!requireSettled || settled)) {
        const snapshot = snapshotFromBridgeData(data);
        if (snapshot) {
          await cacheSnapshot(snapshot);
          data.snapshot = snapshot;
        }
        return data;
      }
    } catch (_) {}
    await sleep(BRIDGE_POLL_MS);
  }
  throw new Error(
    requireSettled
      ? 'LIFE OS bridge settlement timed out.'
      : 'LIFE OS bridge timed out.',
  );
}

async function closeBridgeTab(tabId) {
  try {
    await chrome.tabs.remove(tabId);
  } catch (_) {}
}

function bridgeResult(data) {
  const response = data?.response ?? {};
  return {
    ok: response.ok === true,
    pending: response.settled === false,
    error: response.error ? String(response.error) : null,
    snapshot: snapshotFromBridgeData(data),
  };
}

async function settleBridgePage(tabId, id, { closeWhenDone = false } = {}) {
  try {
    const data = await waitForBridgeResponse(tabId, id, {
      requireSettled: true,
      timeoutMs: BRIDGE_SETTLE_TIMEOUT_MS,
    });
    const snapshot = snapshotFromBridgeData(data);
    if (snapshot) {
      await cacheSnapshot(snapshot);
      await broadcastSnapshot(snapshot);
    }
    if (data?.response?.ok !== true) {
      await broadcastCommandFailure(data?.response, snapshot);
    }
  } catch (_) {
    // Early local acceptance has already been returned. A timed-out settlement
    // is reconciled the next time current state is refreshed.
  } finally {
    if (closeWhenDone) await closeBridgeTab(tabId);
  }
}

async function tryLiveMutation(action, id, text = '') {
  const tabs = await findLifeOsTabs();
  for (const tab of tabs) {
    try {
      const before = await readBridgeData(tab.id);
      if (!supportsLiveUrlBridge(before)) continue;
      const installed = await putUrlCommandOnTab(tab.id, action, id, text);
      if (!installed) continue;

      try {
        const data = await waitForBridgeResponse(tab.id, id, {
          timeoutMs: LIVE_COMMAND_ACK_TIMEOUT_MS,
        });
        const result = bridgeResult(data);
        await clearUrlCommandFromTab(tab.id, id);
        if (result.pending && result.ok) {
          void settleBridgePage(tab.id, id, { closeWhenDone: false });
        }
        return result;
      } catch (_) {
        await clearUrlCommandFromTab(tab.id, id);
        // The fallback uses the same request id. If this tab accepted the
        // command late, shared request dedupe prevents a duplicate mutation.
      }
    } catch (_) {}
  }
  return null;
}

async function runHiddenBridgeAction(action, id, text = '') {
  const tab = await chrome.tabs.create({
    url: bridgeUrl(action, id, text),
    active: false,
  });
  if (!Number.isInteger(tab.id)) {
    throw new Error('Could not create LIFE OS bridge tab.');
  }

  try {
    const data = await waitForBridgeResponse(tab.id, id);
    rememberRealtimeAuth(data.auth);
    const result = bridgeResult(data);
    if (result.pending && result.ok) {
      void settleBridgePage(tab.id, id, { closeWhenDone: true });
    } else {
      await closeBridgeTab(tab.id);
    }
    return result;
  } catch (error) {
    await closeBridgeTab(tab.id);
    throw error;
  }
}

async function runMutationBridgeAction(action, text = '') {
  if (mutationPromise) {
    return { ok: false, error: 'record_mutation_busy', snapshot: null };
  }

  mutationPromise = (async () => {
    const id = requestId();
    const liveResult = await tryLiveMutation(action, id, text);
    if (liveResult) return liveResult;
    return runHiddenBridgeAction(action, id, text);
  })();

  try {
    return await mutationPromise;
  } finally {
    mutationPromise = null;
  }
}

async function refreshLifeOsStateInBackground() {
  if (refreshPromise) return refreshPromise;
  refreshPromise = (async () => {
    try {
      // State reconciliation uses its own temporary tab so it can never
      // overwrite a live start/stop command in the user's open LIFE OS tab.
      const result = await runHiddenBridgeAction('bridge_sync', requestId());
      if (result.ok && result.snapshot) {
        await cacheSnapshot(result.snapshot);
        await broadcastSnapshot(result.snapshot);
        return result.snapshot;
      }
    } catch (_) {
      // Retain last known state when network/auth reconciliation is unavailable.
    } finally {
      refreshPromise = null;
    }
    return null;
  })();
  return refreshPromise;
}

async function getLifeOsState() {
  const openSnapshot = await readSnapshotFromOpenTab();
  const cached = openSnapshot ?? await readCachedSnapshot();
  if (cached) {
    refreshLifeOsStateInBackground().catch(() => {});
    return { ok: true, snapshot: cached, refreshing: true };
  }

  try {
    const fresh = await refreshLifeOsStateInBackground();
    if (fresh) return { ok: true, snapshot: fresh, refreshing: false };
    return { ok: false, authRequired: true, error: 'LIFE OS is not ready.' };
  } catch (error) {
    return { ok: false, authRequired: true, error: String(error) };
  }
}

async function getLifeOsRealtimeConfig() {
  const tabs = await findLifeOsTabs();
  for (const tab of tabs) {
    try {
      const data = await readBridgeData(tab.id);
      const auth = rememberRealtimeAuth(data?.auth);
      if (auth) return { ok: true, baseUrl: POCKETBASE_BASE, ...auth };
    } catch (_) {}
  }

  if (realtimeAuthSnapshot) {
    return { ok: true, baseUrl: POCKETBASE_BASE, ...realtimeAuthSnapshot };
  }

  try {
    await runHiddenBridgeAction('bridge_sync', requestId());
  } catch (_) {}
  if (realtimeAuthSnapshot) {
    return { ok: true, baseUrl: POCKETBASE_BASE, ...realtimeAuthSnapshot };
  }
  return {
    ok: false,
    authRequired: true,
    error: 'LIFE OS realtime session is not ready.',
  };
}

async function warmSnapshotFromTab(tabId) {
  if (!Number.isInteger(tabId)) return;
  try {
    const snapshot = await waitForSnapshotFromTab(tabId, 3000);
    if (snapshot) await broadcastSnapshot(snapshot);
  } catch (_) {}
}

async function startRecord(text) {
  const cleaned = cleanText(text);
  if (!cleaned) return { ok: false, error: 'Record title is empty.' };
  try {
    const result = await runMutationBridgeAction('start_record', cleaned);
    if (result.ok && result.snapshot) {
      await cacheSnapshot(result.snapshot);
      await broadcastSnapshot(result.snapshot);
    }
    return result.ok
      ? {
          ok: true,
          pending: result.pending === true,
          snapshot: result.snapshot,
        }
      : { ok: false, error: result.error ?? 'Could not start record.' };
  } catch (error) {
    return { ok: false, authRequired: true, error: String(error) };
  }
}

async function stopRecord() {
  try {
    const result = await runMutationBridgeAction('stop_record');
    if (result.ok && result.snapshot) {
      await cacheSnapshot(result.snapshot);
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
  for (const tab of tabs) warmSnapshotFromTab(tab.id).catch(() => {});
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === 'life-os-start-selection') {
    const selected = cleanText(info.selectionText);
    if (selected) void startRecord(selected);
    return;
  }
  if (info.menuItemId === 'life-os-start-page') {
    const title = cleanText(tab?.title);
    if (title) void startRecord(title);
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
  if (!message || typeof message !== 'object') return false;

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
  if (message.type === 'getLifeOsRealtimeConfig') {
    void getLifeOsRealtimeConfig().then(sendResponse);
    return true;
  }
  if (message.type === 'refreshLifeOsState') {
    void refreshLifeOsStateInBackground()
      .then((snapshot) => sendResponse({ ok: snapshot != null, snapshot }))
      .catch((error) => sendResponse({ ok: false, error: String(error) }));
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
