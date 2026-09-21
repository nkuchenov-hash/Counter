const currentCard = document.getElementById('currentCard');
const currentLabel = document.getElementById('currentLabel');
const recordTitle = document.getElementById('recordTitle');
const recordCategory = document.getElementById('recordCategory');
const recordTimer = document.getElementById('recordTimer');
const stopRecord = document.getElementById('stopRecord');
const stopLabel = document.getElementById('stopLabel');
const newRecordLabel = document.getElementById('newRecordLabel');
const recordText = document.getElementById('recordText');
const startRecord = document.getElementById('startRecord');
const startLabel = document.getElementById('startLabel');
const openApp = document.getElementById('openApp');
const openAppIcon = document.getElementById('openAppIcon');
const openLabel = document.getElementById('openLabel');
const status = document.getElementById('status');

const REQUEST_TIMEOUT_MS = 15000;
const RECORDS_REALTIME_TOPIC = 'records/*';

const ru = (navigator.language || '').toLowerCase().startsWith('ru');
const copy = ru
  ? {
      current: 'Текущая запись',
      noActive: 'Нет активной записи',
      noActiveSub: 'Начни новую запись ниже',
      newRecord: 'Новая запись',
      placeholder: 'Что ты сейчас делаешь?',
      start: 'Начать запись',
      stop: 'Стоп',
      open: 'Открыть LIFE OS',
      checking: 'Проверяю текущую запись…',
      starting: 'Запускаю…',
      stopping: 'Останавливаю…',
      enterTitle: 'Введите название записи.',
      auth: 'Откройте LIFE OS и войдите в аккаунт.',
      failed: 'Не удалось связаться с LIFE OS.',
    }
  : {
      current: 'Current record',
      noActive: 'No active record',
      noActiveSub: 'Start a new record below',
      newRecord: 'New record',
      placeholder: 'What are you doing now?',
      start: 'Start record',
      stop: 'Stop',
      open: 'Open LIFE OS',
      checking: 'Checking current record…',
      starting: 'Starting…',
      stopping: 'Stopping…',
      enterTitle: 'Enter a record title.',
      auth: 'Open LIFE OS and sign in first.',
      failed: 'Could not connect to LIFE OS.',
    };

let snapshot = null;
let timerHandle = null;
let hasRenderedSnapshot = false;
let realtimeSource = null;
let realtimeHasConnected = false;
let realtimeCanonicalRefreshPromise = null;

currentLabel.textContent = copy.current;
newRecordLabel.textContent = copy.newRecord;
recordText.placeholder = copy.placeholder;
startLabel.textContent = copy.start;
stopLabel.textContent = copy.stop;
openLabel.textContent = copy.open;

function setStatus(message = '', isError = false) {
  status.textContent = message;
  status.classList.toggle('error', isError);
}

async function sendRuntimeMessage(message, timeoutMs = REQUEST_TIMEOUT_MS) {
  let timeoutHandle = null;
  try {
    return await Promise.race([
      chrome.runtime.sendMessage(message),
      new Promise((_, reject) => {
        timeoutHandle = setTimeout(
          () => reject(new Error('LIFE OS request timed out.')),
          timeoutMs,
        );
      }),
    ]);
  } finally {
    if (timeoutHandle !== null) clearTimeout(timeoutHandle);
  }
}

function applyTheme(themeMode) {
  if (themeMode === 'dark' || themeMode === 'light') {
    document.documentElement.dataset.theme = themeMode;
    return;
  }
  document.documentElement.dataset.theme =
    matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function normalizeSnapshot(value) {
  if (!value || typeof value !== 'object') return null;
  return value;
}

function formatElapsed(startTimeUtc) {
  const start = Date.parse(startTimeUtc || '');
  if (!Number.isFinite(start)) return '00:00:00';
  const total = Math.max(0, Math.floor((Date.now() - start) / 1000));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const seconds = total % 60;
  return [hours, minutes, seconds]
    .map((part) => String(part).padStart(2, '0'))
    .join(':');
}

function renderTimer() {
  if (!snapshot?.active || !snapshot.startTimeUtc) return;
  recordTimer.textContent = formatElapsed(snapshot.startTimeUtc);
}

function renderSnapshot(next) {
  snapshot = normalizeSnapshot(next);
  hasRenderedSnapshot = snapshot != null;
  applyTheme(snapshot?.themeMode);

  const active = snapshot?.active === true;
  currentCard.classList.toggle('active', active);

  if (active) {
    recordTitle.textContent = snapshot.title || copy.current;
    recordCategory.textContent = snapshot.categoryPath || '';
    recordCategory.hidden = !recordCategory.textContent;
    recordTimer.hidden = false;
    stopRecord.hidden = false;
    currentCard.style.setProperty(
      '--record-accent',
      /^#[0-9A-Fa-f]{6}$/.test(snapshot.categoryColor || '')
        ? snapshot.categoryColor
        : 'var(--primary)',
    );
    renderTimer();
  } else {
    recordTitle.textContent = copy.noActive;
    recordCategory.textContent = copy.noActiveSub;
    recordCategory.hidden = false;
    recordTimer.hidden = true;
    stopRecord.hidden = true;
    currentCard.style.setProperty('--record-accent', 'var(--border)');
  }
}

async function restoreCachedState() {
  const saved = await chrome.storage.local.get([
    'lifeOsRecordDraft',
    'lifeOsLastSnapshot',
  ]);
  if (typeof saved.lifeOsRecordDraft === 'string') {
    recordText.value = saved.lifeOsRecordDraft;
  }
  if (saved.lifeOsLastSnapshot) {
    renderSnapshot(saved.lifeOsLastSnapshot);
    return true;
  }

  currentCard.classList.remove('active');
  stopRecord.hidden = true;
  recordTimer.hidden = true;
  recordTitle.textContent = copy.checking;
  recordCategory.textContent = '';
  recordCategory.hidden = true;
  currentCard.style.setProperty('--record-accent', 'var(--border)');
  return false;
}

async function refreshState() {
  try {
    const response = await sendRuntimeMessage({ type: 'getLifeOsState' });
    if (!response?.ok) {
      if (!hasRenderedSnapshot) {
        recordTitle.textContent = copy.noActive;
        recordCategory.textContent = copy.noActiveSub;
        recordCategory.hidden = false;
        stopRecord.hidden = true;
        recordTimer.hidden = true;
      }
      setStatus(response?.authRequired ? copy.auth : copy.failed, true);
      return false;
    }

    renderSnapshot(response.snapshot);
    setStatus('');
    return true;
  } catch (_) {
    if (!hasRenderedSnapshot) {
      recordTitle.textContent = copy.noActive;
      recordCategory.textContent = copy.noActiveSub;
      recordCategory.hidden = false;
      stopRecord.hidden = true;
      recordTimer.hidden = true;
    }
    setStatus(copy.failed, true);
    return false;
  }
}

function refreshCanonicalStateFromRealtime() {
  if (realtimeCanonicalRefreshPromise) return realtimeCanonicalRefreshPromise;
  realtimeCanonicalRefreshPromise = (async () => {
    try {
      const response = await sendRuntimeMessage({ type: 'refreshLifeOsState' });
      if (response?.ok && response.snapshot) {
        renderSnapshot(response.snapshot);
        setStatus('');
      }
    } catch (_) {
      // Keep the instant event projection. EventSource will reconnect itself,
      // and PB_CONNECT will request another authoritative reconciliation.
    } finally {
      realtimeCanonicalRefreshPromise = null;
    }
  })();
  return realtimeCanonicalRefreshPromise;
}

function applyRecordRealtimeEvent(messageEvent) {
  let payload = null;
  try {
    payload = JSON.parse(messageEvent.data || '{}');
  } catch (_) {
    return;
  }
  if (!payload || typeof payload !== 'object') return;
  const record = payload.record && typeof payload.record === 'object'
    ? payload.record
    : null;
  if (!record) {
    void refreshCanonicalStateFromRealtime();
    return;
  }

  const action = String(payload.action ?? '').toLowerCase();
  const recordId = String(record.record_id ?? record.id ?? '').trim();
  const statusValue = String(record.status ?? '').toLowerCase();
  const endTime = String(record.end_time ?? '').trim();
  const running = action !== 'delete' && !endTime && statusValue === 'running';

  if (running) {
    const sameRecord = snapshot?.recordId && snapshot.recordId === recordId;
    renderSnapshot({
      ...(snapshot ?? {}),
      active: true,
      title: String(record.title ?? '').trim(),
      startTimeUtc: String(record.start_time ?? '').trim(),
      recordId,
      categoryPath: sameRecord ? snapshot.categoryPath : '',
      categoryColor: sameRecord ? snapshot.categoryColor : '',
      updatedAtUtc: new Date().toISOString(),
    });
  } else if (
    snapshot?.active &&
    recordId &&
    snapshot.recordId === recordId
  ) {
    renderSnapshot({
      ...(snapshot ?? {}),
      active: false,
      title: '',
      categoryPath: '',
      startTimeUtc: null,
      recordId: '',
      categoryColor: '',
      updatedAtUtc: new Date().toISOString(),
    });
  }

  // The raw event makes start/stop/title state visible immediately. The
  // canonical bridge follows in the background to resolve category metadata
  // and server-side Highlander/overlap cleanup exactly like the main apps.
  void refreshCanonicalStateFromRealtime();
}

async function postRealtimeSubscription(baseUrl, clientId, token) {
  const response = await fetch(`${baseUrl}/api/realtime`, {
    method: 'POST',
    headers: {
      Authorization: token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      clientId,
      subscriptions: [RECORDS_REALTIME_TOPIC],
    }),
  });
  if (!response.ok) {
    throw new Error(`PocketBase realtime subscription failed: ${response.status}`);
  }
}

async function connectRealtime() {
  try {
    const config = await sendRuntimeMessage({
      type: 'getLifeOsRealtimeConfig',
    });
    if (!config?.ok || !config.baseUrl || !config.token) return;

    realtimeSource?.close();
    realtimeHasConnected = false;
    const source = new EventSource(`${config.baseUrl}/api/realtime`);
    realtimeSource = source;

    source.addEventListener('PB_CONNECT', (event) => {
      const clientId = String(event.lastEventId ?? '').trim();
      if (!clientId) return;
      const reconnect = realtimeHasConnected;
      realtimeHasConnected = true;
      void postRealtimeSubscription(
        config.baseUrl,
        clientId,
        config.token,
      ).then(() => {
        if (reconnect) {
          void refreshCanonicalStateFromRealtime();
        }
      }).catch(() => {
        // A stale/revoked token is handled by the normal authenticated bridge;
        // do not replace a usable cached card with a connection error.
      });
    });

    source.addEventListener(RECORDS_REALTIME_TOPIC, applyRecordRealtimeEvent);
  } catch (_) {
    // The authenticated bridge remains the fallback on popup open. Realtime is
    // opportunistic only when a valid web session is available.
  }
}

async function handleStart() {
  const text = recordText.value.trim();
  if (!text) {
    setStatus(copy.enterTitle, true);
    recordText.focus();
    return;
  }

  startRecord.disabled = true;
  stopRecord.disabled = true;
  startLabel.textContent = copy.starting;
  setStatus('');

  try {
    const response = await sendRuntimeMessage({
      type: 'startRecord',
      text,
    });

    if (!response?.ok) {
      setStatus(response?.authRequired ? copy.auth : copy.failed, true);
      return;
    }

    await chrome.storage.local.set({ lifeOsRecordDraft: '' });
    recordText.value = '';
    if (response.snapshot && typeof response.snapshot === 'object') {
      renderSnapshot(response.snapshot);
    } else {
      void refreshState();
    }
    setStatus('');
  } catch (_) {
    setStatus(copy.failed, true);
  } finally {
    startRecord.disabled = false;
    stopRecord.disabled = false;
    startLabel.textContent = copy.start;
  }
}

async function handleStop() {
  stopRecord.disabled = true;
  startRecord.disabled = true;
  stopLabel.textContent = copy.stopping;
  setStatus('');

  try {
    const response = await sendRuntimeMessage({ type: 'stopRecord' });
    if (!response?.ok) {
      setStatus(response?.authRequired ? copy.auth : copy.failed, true);
      return;
    }

    if (response.snapshot && typeof response.snapshot === 'object') {
      renderSnapshot(response.snapshot);
    } else {
      void refreshState();
    }
    setStatus('');
  } catch (_) {
    setStatus(copy.failed, true);
  } finally {
    stopRecord.disabled = false;
    startRecord.disabled = false;
    stopLabel.textContent = copy.stop;
  }
}

async function handleOpenApp() {
  try {
    const response = await sendRuntimeMessage({ type: 'openLifeOs' });
    if (!response?.ok) {
      setStatus(copy.failed, true);
      return;
    }
    window.close();
  } catch (_) {
    setStatus(copy.failed, true);
  }
}

recordText.addEventListener('input', () => {
  void chrome.storage.local.set({ lifeOsRecordDraft: recordText.value });
});

recordText.addEventListener('keydown', (event) => {
  if (event.key === 'Enter' && (event.ctrlKey || event.metaKey)) {
    event.preventDefault();
    void handleStart();
  }
});

startRecord.addEventListener('click', () => void handleStart());
stopRecord.addEventListener('click', () => void handleStop());
openApp.addEventListener('click', () => void handleOpenApp());
openAppIcon.addEventListener('click', () => void handleOpenApp());

chrome.runtime.onMessage.addListener((message) => {
  if (message?.type !== 'lifeOsStateUpdated') return;
  if (!message.snapshot || typeof message.snapshot !== 'object') return;
  renderSnapshot(message.snapshot);
  setStatus('');
});

timerHandle = setInterval(renderTimer, 1000);

window.addEventListener('unload', () => {
  clearInterval(timerHandle);
  realtimeSource?.close();
  realtimeSource = null;
});

void restoreCachedState().then(async () => {
  await refreshState();
  void connectRealtime();
  recordText.focus();
});
