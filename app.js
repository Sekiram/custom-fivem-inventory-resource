const resourceName = window.GetParentResourceName ? GetParentResourceName() : 'ps-inventory';
const SLOT_COUNT = 25;
const RING_CIRCUMFERENCE = 119.38;

function nuiFetch(name, data = {}) {
  return fetch(`https://${resourceName}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  }).then((r) => r.json()).catch(() => null);
}

const el = (id) => document.getElementById(id);

const state = {
  inventory: {},
  secondary: null,
  secondaryLabel: 'Secondary Inventory',
  items: {},
  maxWeight: 45,
  hunger: 100,
  thirst: 100,
  health: 100,
  playerName: '',
  playerId: 0,
  drag: null,
  contextTarget: null,
};

let dragGhost = null;
let qtyCallback = null;
let giveState = { slot: null, item: null, selectedTarget: null, maxAmount: 1 };

// ===================== HELPERS =====================
function itemWeight(name) {
  const data = state.items[name];
  return data ? data.weight : 0;
}

function calcWeight(inv) {
  let total = 0;
  for (const key in inv) {
    const item = inv[key];
    if (!item) continue;
    total += itemWeight(item.name) * item.amount;
  }
  return total;
}

// ===================== RENDER =====================
function buildSlot(slotIndex, item, context) {
  const slot = document.createElement('div');
  slot.className = 'slot' + (item ? '' : ' empty');
  slot.dataset.slot = slotIndex;
  slot.dataset.context = context;

  if (item) {
    const data = state.items[item.name] || { label: item.name, icon: '❔', weight: 0 };
    const query = context === 'player' && el('searchInput') ? el('searchInput').value.trim().toLowerCase() : '';

    slot.innerHTML = `
      <div class="slot-label">${data.label}</div>
      <div class="slot-icon">${data.icon || '❔'}</div>
      <div class="slot-footer">
        <span class="slot-amount">${item.amount}x</span>
        <span>${(data.weight * item.amount).toFixed(1)}</span>
      </div>
    `;

    if (query && !data.label.toLowerCase().includes(query)) {
      slot.style.opacity = '0.25';
    }

    slot.addEventListener('mousedown', (e) => onSlotMouseDown(e, slotIndex, context, item));
    slot.addEventListener('contextmenu', (e) => onSlotContextMenu(e, slotIndex, context, item));
    slot.addEventListener('dblclick', () => {
      if (context === 'player') nuiFetch('useItem', { slot: slotIndex });
    });
  }

  slot.addEventListener('mouseup', (e) => onSlotMouseUp(e, slotIndex, context));
  slot.addEventListener('mouseenter', () => { if (state.drag) slot.classList.add('drag-over'); });
  slot.addEventListener('mouseleave', () => slot.classList.remove('drag-over'));

  return slot;
}

function renderGrid(containerId, inv, context) {
  const container = el(containerId);
  container.innerHTML = '';
  for (let i = 1; i <= SLOT_COUNT; i++) {
    const item = inv[String(i)] || inv[i];
    container.appendChild(buildSlot(i, item, context));
  }
}

function renderWeight() {
  const weight = calcWeight(state.inventory);
  el('playerWeightText').textContent = `${weight.toFixed(2)} / ${state.maxWeight.toFixed(2)} kg`;
  const pct = Math.min(100, (weight / state.maxWeight) * 100);
  const fill = el('playerWeightFill');
  fill.style.width = pct + '%';
  fill.className = 'weight-fill' + (pct > 90 ? ' danger' : pct > 70 ? ' warn' : '');

  if (state.secondary) {
    el('secondaryWeightText').textContent = `${calcWeight(state.secondary).toFixed(2)} kg`;
  }

  renderRing('ringWeight', pct);
}

function renderRing(id, pct) {
  const ring = el(id);
  if (!ring) return;
  const clamped = Math.max(0, Math.min(100, pct));
  ring.style.strokeDashoffset = RING_CIRCUMFERENCE - (clamped / 100) * RING_CIRCUMFERENCE;
}

function renderStats() {
  renderRing('ringHealth', state.health);
  renderRing('ringThirst', state.thirst);
  renderRing('ringHunger', state.hunger);
}

function renderAll() {
  el('playerName').textContent = state.playerName;
  el('playerId').textContent = 'ID: ' + state.playerId;
  renderGrid('playerGrid', state.inventory, 'player');
  renderWeight();
  renderStats();

  const secPanel = el('secondaryPanel');
  if (state.secondary) {
    secPanel.classList.add('visible');
    el('secondaryTitle').textContent = state.secondaryLabel || 'Secondary Inventory';
    renderGrid('secondaryGrid', state.secondary, 'drop');
  } else {
    secPanel.classList.remove('visible');
  }
}

// ===================== DRAG & DROP =====================
function onSlotMouseDown(e, slotIndex, context, item) {
  if (e.button !== 0) return;
  e.preventDefault();
  state.drag = { fromSlot: slotIndex, fromContext: context, item };

  dragGhost = document.createElement('div');
  dragGhost.className = 'drag-ghost';
  const data = state.items[item.name] || {};
  dragGhost.textContent = data.icon || '❔';
  dragGhost.style.display = 'block';
  document.body.appendChild(dragGhost);
  moveGhost(e);

  document.addEventListener('mousemove', moveGhost);
  document.addEventListener('mouseup', onGlobalMouseUp, { once: true });
}

function moveGhost(e) {
  if (dragGhost) {
    dragGhost.style.left = e.clientX + 'px';
    dragGhost.style.top = e.clientY + 'px';
  }
}

function onGlobalMouseUp() {
  document.removeEventListener('mousemove', moveGhost);
  if (dragGhost) { dragGhost.remove(); dragGhost = null; }
  setTimeout(() => {
    state.drag = null;
    document.querySelectorAll('.slot.drag-over').forEach((s) => s.classList.remove('drag-over'));
  }, 0);
}

function onSlotMouseUp(e, slotIndex, context) {
  if (!state.drag) return;
  const { fromSlot, fromContext } = state.drag;
  if (fromSlot === slotIndex && fromContext === context) return;

  nuiFetch('moveItem', {
    fromSlot,
    toSlot: slotIndex,
    fromContext,
    toContext: context,
  });
}

// ===================== CONTEXT MENU =====================
function onSlotContextMenu(e, slotIndex, context, item) {
  e.preventDefault();
  if (context !== 'player') return;
  state.contextTarget = { slot: slotIndex, context, item };

  const menu = el('contextMenu');
  menu.classList.add('visible');
  const x = Math.min(e.clientX, window.innerWidth - 160);
  const y = Math.min(e.clientY, window.innerHeight - 180);
  menu.style.left = x + 'px';
  menu.style.top = y + 'px';
}

function closeContextMenu() { el('contextMenu').classList.remove('visible'); }
function isContextMenuOpen() { return el('contextMenu').classList.contains('visible'); }

function handleContextAction(action) {
  const target = state.contextTarget;
  if (!target) return;
  const { slot, item } = target;
  const data = state.items[item.name] || { label: item.name };

  if (action === 'split') {
    nuiFetch('splitItem', { slot });
  } else if (action === 'separate') {
    if (item.amount < 2) { showToast('You need at least 2 items to separate.', 'error'); return; }
    openQuantityModal({
      title: 'Separate Item',
      label: `${data.label} — you have ${item.amount}`,
      max: item.amount - 1,
      onConfirm: (amount) => nuiFetch('separateItem', { slot, amount }),
    });
  } else if (action === 'drop') {
    if (item.amount > 1) {
      openQuantityModal({
        title: 'Drop Item',
        label: `${data.label} — you have ${item.amount}`,
        max: item.amount,
        onConfirm: (amount) => nuiFetch('dropItem', { slot, amount }),
      });
    } else {
      nuiFetch('dropItem', { slot, amount: 1 });
    }
  } else if (action === 'give') {
    openGiveModal(slot, item, data);
  }
}

// ===================== QUANTITY MODAL =====================
function openQuantityModal({ title, label, max, onConfirm }) {
  el('qtyTitle').textContent = title;
  el('qtyItemLabel').textContent = label;
  el('qtyInput').max = max;
  el('qtyInput').min = 1;
  el('qtyInput').value = 1;
  el('qtySlider').max = max;
  el('qtySlider').min = 1;
  el('qtySlider').value = 1;
  qtyCallback = onConfirm;
  el('qtyOverlay').classList.add('visible');
}

function closeQuantityModal() {
  el('qtyOverlay').classList.remove('visible');
  qtyCallback = null;
}

function isQtyModalOpen() { return el('qtyOverlay').classList.contains('visible'); }

// ===================== GIVE MODAL =====================
function openGiveModal(slot, item, data) {
  giveState = { slot, item, selectedTarget: null, maxAmount: item.amount };
  el('giveItemLabel').textContent = `${data.label} — you have ${item.amount}`;
  el('giveQtyInput').max = item.amount;
  el('giveQtyInput').min = 1;
  el('giveQtyInput').value = 1;
  el('giveAmountRow').classList.remove('visible');
  el('giveConfirm').disabled = true;
  el('playerList').innerHTML = '<div class="no-players">Searching nearby players...</div>';
  el('giveOverlay').classList.add('visible');

  nuiFetch('getNearbyPlayers').then((players) => {
    if (!players || players.length === 0) {
      el('playerList').innerHTML = '<div class="no-players">No players nearby.</div>';
      return;
    }
    el('playerList').innerHTML = '';
    players.forEach((p) => {
      const row = document.createElement('div');
      row.className = 'player-row';
      row.innerHTML = `<span>${p.name}</span><span class="dist">${p.distance}m</span>`;
      row.addEventListener('click', () => {
        document.querySelectorAll('.player-row').forEach((r) => r.classList.remove('selected'));
        row.classList.add('selected');
        giveState.selectedTarget = p.serverId;
        el('giveAmountRow').classList.add('visible');
        el('giveConfirm').disabled = false;
      });
      el('playerList').appendChild(row);
    });
  });
}

function closeGiveModal() { el('giveOverlay').classList.remove('visible'); }
function isGiveModalOpen() { return el('giveOverlay').classList.contains('visible'); }

// ===================== TOAST =====================
function showToast(message, kind) {
  const toast = document.createElement('div');
  toast.className = 'toast' + (kind === 'error' ? ' error' : kind === 'success' ? ' success' : '');
  toast.textContent = message;
  el('toasts').appendChild(toast);
  setTimeout(() => toast.remove(), 3000);
}

// ===================== MESSAGE HANDLER =====================
window.addEventListener('message', (event) => {
  const data = event.data || {};
  switch (data.action) {
    case 'open':
      state.inventory = data.inventory || {};
      state.items = data.items || {};
      state.maxWeight = data.maxWeight || 45;
      state.hunger = data.hunger;
      state.thirst = data.thirst;
      state.health = data.health;
      state.playerName = data.playerName;
      state.playerId = data.playerId;
      state.secondary = data.secondary || null;
      state.secondaryLabel = data.secondaryLabel || 'Secondary Inventory';
      el('app').classList.add('visible');
      renderAll();
      break;

    case 'close':
      el('app').classList.remove('visible');
      closeContextMenu();
      closeQuantityModal();
      closeGiveModal();
      state.secondary = null;
      break;

    case 'updateInventory':
      state.inventory = data.inventory || {};
      state.hunger = data.hunger;
      state.thirst = data.thirst;
      state.health = data.health;
      state.maxWeight = data.maxWeight || state.maxWeight;
      renderAll();
      break;

    case 'updateSecondary':
      state.secondary = data.secondary || null;
      renderAll();
      break;

    case 'notify':
      showToast(data.message, data.kind);
      break;
  }
});

// ===================== UI EVENTS =====================
document.addEventListener('DOMContentLoaded', () => {
  el('closeBtn').addEventListener('click', closeInventoryUI);
  el('helpBtn').addEventListener('click', () => {
    showToast('Drag to move items. Right click a slot to drop, split, separate or give.', 'info');
  });

  el('searchInput').addEventListener('input', () => renderGrid('playerGrid', state.inventory, 'player'));

  document.querySelectorAll('.context-item').forEach((btn) => {
    btn.addEventListener('click', () => {
      handleContextAction(btn.dataset.action);
      closeContextMenu();
    });
  });

  document.addEventListener('click', (e) => {
    if (!e.target.closest('.context-menu')) closeContextMenu();
  });

  el('qtyInput').addEventListener('input', () => { el('qtySlider').value = el('qtyInput').value; });
  el('qtySlider').addEventListener('input', () => { el('qtyInput').value = el('qtySlider').value; });
  el('qtyCancel').addEventListener('click', closeQuantityModal);
  el('qtyConfirm').addEventListener('click', () => {
    const amount = parseInt(el('qtyInput').value, 10);
    if (qtyCallback && amount > 0) qtyCallback(amount);
    closeQuantityModal();
  });

  el('giveCancel').addEventListener('click', closeGiveModal);
  el('giveConfirm').addEventListener('click', () => {
    const amount = Math.min(giveState.maxAmount, Math.max(1, parseInt(el('giveQtyInput').value, 10) || 1));
    if (giveState.selectedTarget) {
      nuiFetch('giveItem', { slot: giveState.slot, amount, targetId: giveState.selectedTarget });
    }
    closeGiveModal();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (isQtyModalOpen()) { closeQuantityModal(); return; }
    if (isGiveModalOpen()) { closeGiveModal(); return; }
    if (isContextMenuOpen()) { closeContextMenu(); return; }
    closeInventoryUI();
  });
});

function closeInventoryUI() {
  nuiFetch('close');
  el('app').classList.remove('visible');
  state.secondary = null;
}
