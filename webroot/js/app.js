// BuildChain WebUI

let currentTab = 'dash';
let toastTimer = null;

async function api(path) {
  try { return await (await fetch(path)).json(); } catch(e) { showToast('Connection error','error'); return null; }
}
async function post(path, body) {
  try { return await (await fetch(path, {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)})).json(); } catch(e) { return null; }
}

function showToast(msg, type='success') {
  const el = document.getElementById('toast');
  el.textContent = msg; el.className = 'toast ' + type + ' show';
  clearTimeout(toastTimer); toastTimer = setTimeout(() => el.className = 'toast', 2500);
}

function switchTab(tab) {
  currentTab = tab;
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.tab-item').forEach(t => t.classList.remove('active'));
  document.getElementById('page-' + tab).classList.add('active');
  document.querySelector(`[data-tab="${tab}"]`).classList.add('active');
  switch(tab) {
    case 'dash': loadDash(); break;
    case 'tools': loadTools(); break;
    case 'test': break;
    case 'paths': loadPaths(); break;
  }
}

function esc(s) { return (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }

// ---- Dashboard ----
async function loadDash() {
  const env = await api('/api/status');
  if (env) {
    document.getElementById('device-info').textContent = `${env.device || '?'} — Android ${env.api_level || '?'} — ${env.arch || '?'}`;
    document.getElementById('env-device').textContent = env.device || '-';
    document.getElementById('env-api').textContent = `API ${env.api_level || '?'}`;
    document.getElementById('env-arch').textContent = env.arch || '-';
  }

  // Tool status grid
  const tools = await api('/api/tools');
  const grid = document.getElementById('status-grid');
  if (tools) {
    grid.innerHTML = tools.map(t => `
      <div class="tool-chip">
        <span class="dot ${t.exists ? 'ok' : 'miss'}"></span>
        ${t.name}
      </div>
    `).join('');
  }

  // Setup status
  const setup = await api('/api/setup');
  const statusEl = document.getElementById('setup-status');
  const badgeEl = document.getElementById('setup-badge');
  if (setup) {
    if (setup.complete) {
      statusEl.textContent = 'All packages installed';
      badgeEl.textContent = 'Ready';
      badgeEl.className = 'badge badge-ok';
    } else {
      statusEl.textContent = 'Missing: ' + setup.missing.join(', ');
      badgeEl.textContent = 'Incomplete';
      badgeEl.className = 'badge badge-miss';
    }
  }
}

async function redetect() {
  showToast('Re-detecting environment...');
  await post('/api/redetect', {});
  setTimeout(loadDash, 3000);
}

// ---- Tools ----
async function loadTools() {
  const tools = await api('/api/tools');
  if (!tools) return;

  const buildTools = tools.filter(t => t.category === 'build-tools');
  const platTools = tools.filter(t => t.category === 'platform-tools');
  const termuxTools = tools.filter(t => t.category === 'termux');

  document.getElementById('build-tools-list').innerHTML = buildTools.map(t => `
    <div class="card-row">
      <div class="card-row-info">
        <div class="card-row-label">${t.name}</div>
        <div class="card-row-desc">${t.path}</div>
      </div>
      <span class="badge ${t.exists ? 'badge-ok' : 'badge-miss'}">${t.exists ? (t.size/1024).toFixed(0)+'K' : 'missing'}</span>
    </div>
  `).join('');

  document.getElementById('platform-tools-list').innerHTML = platTools.map(t => `
    <div class="card-row">
      <div class="card-row-info">
        <div class="card-row-label">${t.name}</div>
        <div class="card-row-desc">${t.path}</div>
      </div>
      <span class="badge ${t.exists ? 'badge-ok' : 'badge-miss'}">${t.exists ? (t.size/1024).toFixed(0)+'K' : 'missing'}</span>
    </div>
  `).join('');

  document.getElementById('termux-tools-list').innerHTML = termuxTools.map(t => `
    <div class="card-row">
      <div class="card-row-info">
        <div class="card-row-label">${t.name}</div>
        <div class="card-row-desc">${t.category}</div>
      </div>
      <span class="badge ${t.exists ? 'badge-ok' : 'badge-miss'}">${t.exists ? 'installed' : 'not found'}</span>
    </div>
  `).join('');

  // BusyBox
  const bb = await api('/api/busybox');
  const bbc = document.getElementById('busybox-info');
  if (bb) {
    bbc.innerHTML = `
      <div class="card-row">
        <div class="card-row-info">
          <div class="card-row-label">${esc(bb.version)}</div>
          <div class="card-row-desc">${bb.count} applets</div>
        </div>
        <span class="badge badge-ok">active</span>
      </div>
      <div class="card-row">
        <div class="card-row-info">
          <div class="card-row-desc" style="font-family:monospace;font-size:10px;line-height:1.4;max-height:120px;overflow-y:auto">${esc(bb.applets).replace(/,/g, ', ')}</div>
        </div>
      </div>
    `;
  }
}

// ---- Test ----
async function runTest() {
  const out = document.getElementById('test-output');
  out.textContent = 'Running tests...';
  const res = await api('/api/test');
  if (res && res.output) {
    out.textContent = res.output;
  } else {
    out.textContent = 'Failed to run tests';
  }
}

async function loadLog() {
  const out = document.getElementById('log-output');
  out.textContent = 'Loading...';
  const res = await api('/api/log');
  if (res && res.log) {
    out.textContent = res.log;
  } else {
    out.textContent = 'No log available';
  }
}

// ---- Paths ----
async function loadPaths() {
  const paths = await api('/api/paths');
  const pc = document.getElementById('path-list');
  if (paths) {
    pc.innerHTML = paths.map((p, i) => `
      <div class="card-row">
        <div class="card-row-info">
          <span class="prop-name">${esc(p)}</span>
        </div>
        <span class="badge badge-info">#${i}</span>
      </div>
    `).join('');
  }

  // Env file
  const envOut = document.getElementById('env-output');
  try {
    const res = await fetch('/api/status');
    const env = await res.json();
    envOut.textContent = JSON.stringify(env, null, 2);
  } catch(e) {
    envOut.textContent = 'Failed to load';
  }
}

// ---- Init ----
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.tab-item').forEach(t =>
    t.addEventListener('click', () => switchTab(t.dataset.tab)));
  switchTab('dash');
});
