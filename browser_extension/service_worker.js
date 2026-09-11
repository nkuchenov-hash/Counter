const LIFE_OS_BASE = 'https://nkuchenov-hash.github.io/Counter/';
const LIFE_OS_MATCH = 'https://nkuchenov-hash.github.io/Counter/*';
const MAX_TEXT_LENGTH = 1600;

function requestId() {
  if (globalThis.crypto?.randomUUID) {
    return globalThis.crypto.randomUUID();
  }
  return `life-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function cleanText(value) {
  return String(value ?? '').trim().slice(0, MAX_TEXT_LENGTH);
}

function quickAddUrl(text, target = 'plan') {
  const url = new URL(LIFE_OS_BASE);
  url.searchParams.set('life_source', 'browser_extension');
  url.searchParams.set('life_action', 'quick_add');
  url.searchParams.set('life_target', target === 'list' ? 'list' : 'plan');
  url.searchParams.set('life_request', requestId());
  url.searchParams.set('life_text', cleanText(text));
  return url.toString();
}

async function findLifeOsTab() {
  const tabs = await chrome.tabs.query({ url: LIFE_OS_MATCH });
  return tabs.find((tab) => Number.isInteger(tab.id)) ?? null;
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

async function submitQuickAdd(text, target = 'plan') {
  const cleaned = cleanText(text);
  if (!cleaned) {
    throw new Error('Task text is empty.');
  }
  const url = quickAddUrl(cleaned, target);
  const tab = await findLifeOsTab();
  if (tab) {
    await chrome.tabs.update(tab.id, { url, active: true });
    if (Number.isInteger(tab.windowId)) {
      await chrome.windows.update(tab.windowId, { focused: true });
    }
    return;
  }
  await chrome.tabs.create({ url, active: true });
}

chrome.runtime.onInstalled.addListener(async () => {
  await chrome.contextMenus.removeAll();
  chrome.contextMenus.create({
    id: 'life-os-add-selection',
    title: 'Add selection to LIFE OS',
    contexts: ['selection'],
  });
  chrome.contextMenus.create({
    id: 'life-os-add-page',
    title: 'Add page to LIFE OS',
    contexts: ['page'],
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === 'life-os-add-selection') {
    const selected = cleanText(info.selectionText);
    const pageUrl = cleanText(info.pageUrl);
    const text = [selected, pageUrl].filter(Boolean).join('\n');
    if (text) {
      void submitQuickAdd(text, 'plan');
    }
    return;
  }

  if (info.menuItemId === 'life-os-add-page') {
    const title = cleanText(tab?.title);
    const pageUrl = cleanText(info.pageUrl ?? tab?.url);
    const text = [title, pageUrl].filter(Boolean).join('\n');
    if (text) {
      void submitQuickAdd(text, 'plan');
    }
  }
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

  if (message.type === 'quickAdd') {
    void submitQuickAdd(message.text, message.target)
      .then(() => sendResponse({ ok: true }))
      .catch((error) => sendResponse({ ok: false, error: String(error) }));
    return true;
  }

  return false;
});
