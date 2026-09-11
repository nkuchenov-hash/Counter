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
      starting: 'Запускаю запись…',
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
      starting: 'Starting record…',
      stopping: 'Stopping…',
      enterTitle: 'Enter a record title.',
      auth: 'Open LIFE OS and sign in first.',
      failed: 'Could not connect to LIFE OS.',
    };

let snapshot = null;
let timerHandle = null;
let refreshHandle = null;
let hasRenderedSnapshot = false;

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
  const response = await chrome.runtime.sendMessage({ type: 'getLifeOsState' });
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
  setStatus(copy.starting);

  const response = await chrome.runtime.sendMessage({
    type: 'startRecord',
    text,
  });

  startRecord.disabled = false;
  stopRecord.disabled = false;

  if (!response?.ok) {
    setStatus(response?.authRequired ? copy.auth : copy.failed, true);
    return;
  }

  await chrome.storage.local.set({ lifeOsRecordDraft: '' });
  recordText.value = '';
  renderSnapshot(response.snapshot);
  setStatus('');
}

async function handleStop() {
  stopRecord.disabled = true;
  startRecord.disabled = true;
  setStatus(copy.stopping);

  const response = await chrome.runtime.sendMessage({ type: 'stopRecord' });

  stopRecord.disabled = false;
  startRecord.disabled = false;

  if (!response?.ok) {
    setStatus(response?.authRequired ? copy.auth : copy.failed, true);
    return;
  }

  renderSnapshot(response.snapshot);
  setStatus('');
}

async function handleOpenApp() {
  const response = await chrome.runtime.sendMessage({ type: 'openLifeOs' });
  if (!response?.ok) {
    setStatus(copy.failed, true);
    return;
  }
  window.close();
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
refreshHandle = setInterval(() => {
  void chrome.runtime.sendMessage({ type: 'refreshLifeOsState' });
}, 15000);

window.addEventListener('unload', () => {
  clearInterval(timerHandle);
  clearInterval(refreshHandle);
});

void restoreCachedState().then(() => {
  void refreshState();
  recordText.focus();
});
