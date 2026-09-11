const taskText = document.getElementById('taskText');
const target = document.getElementById('target');
const addTask = document.getElementById('addTask');
const openApp = document.getElementById('openApp');
const status = document.getElementById('status');

function setStatus(message, isError = false) {
  status.textContent = message;
  status.classList.toggle('error', isError);
}

async function restoreDraft() {
  const saved = await chrome.storage.local.get(['lifeOsDraft', 'lifeOsTarget']);
  if (typeof saved.lifeOsDraft === 'string') {
    taskText.value = saved.lifeOsDraft;
  }
  if (saved.lifeOsTarget === 'list' || saved.lifeOsTarget === 'plan') {
    target.value = saved.lifeOsTarget;
  }
}

async function saveDraft() {
  await chrome.storage.local.set({
    lifeOsDraft: taskText.value,
    lifeOsTarget: target.value,
  });
}

async function submit() {
  const text = taskText.value.trim();
  if (!text) {
    setStatus('Enter a task first.', true);
    taskText.focus();
    return;
  }

  addTask.disabled = true;
  setStatus('Opening LIFE OS…');
  const response = await chrome.runtime.sendMessage({
    type: 'quickAdd',
    text,
    target: target.value,
  });

  if (!response?.ok) {
    addTask.disabled = false;
    setStatus(response?.error ?? 'Could not open LIFE OS.', true);
    return;
  }

  await chrome.storage.local.set({ lifeOsDraft: '' });
  taskText.value = '';
  window.close();
}

taskText.addEventListener('input', () => {
  void saveDraft();
});

target.addEventListener('change', () => {
  void saveDraft();
});

addTask.addEventListener('click', () => {
  void submit();
});

openApp.addEventListener('click', async () => {
  const response = await chrome.runtime.sendMessage({ type: 'openLifeOs' });
  if (!response?.ok) {
    setStatus(response?.error ?? 'Could not open LIFE OS.', true);
    return;
  }
  window.close();
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'Enter' && (event.ctrlKey || event.metaKey)) {
    event.preventDefault();
    void submit();
  }
});

void restoreDraft().then(() => taskText.focus());
