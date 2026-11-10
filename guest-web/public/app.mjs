import { parseInvitation, RelayClient, GuestError, formatMyr } from './protocol.mjs';
export function mountApp(doc, { clientFactory = invitation => new RelayClient(invitation), initialInvitationCode } = {}) {
  const win = doc.defaultView, $ = id => doc.getElementById(id);
  let client = null, syncing = false, controller = null, timer = null, closed = false;
  const status = (message, error = false) => { $('status').textContent = message; $('status').dataset.error = String(error); };
  const explain = error => error instanceof GuestError ? error.message : 'Could not complete this action. Your pending expenses are kept.';
  function text(tag, value, className) { const node = doc.createElement(tag); node.textContent = value; if (className) node.className = className; return node; }
  function options(id, rows, selected) {
    const field = $(id), before = field.value;
    field.replaceChildren(...rows.map(row => { const option = text('option', row.label); option.value = row.id; return option; }));
    if (rows.some(row => row.id === before)) field.value = before;
    else if (rows.some(row => row.id === selected)) field.value = selected;
  }
  function render() {
    if (!client) return;
    const { snapshot, pending } = client.state;
    $('join').hidden = true; $('trip').hidden = false;
    $('trip-name').textContent = snapshot?.name ?? client.invite.name;
    $('expiry').textContent = client.invite.expires === null ? 'Access can be revoked by the host.' : `${client.expired ? 'Expired' : 'Access expires'} ${new Date(client.invite.expires).toLocaleString()}`;
    $('summary').hidden = !snapshot;
    if (snapshot) {
      $('total').textContent = formatMyr(snapshot.total_myr_minor); $('count').textContent = `${snapshot.count} ${snapshot.count === 1 ? 'expense' : 'expenses'} in the host ledger`;
      options('category', snapshot.categories.map(row => ({ id: row.id, label: row.name })));
      options('currency', snapshot.currencies.map(row => ({ id: row.id, label: `${row.code} · ${row.name}` })), snapshot.default_currency);
      $('synced').textContent = `Trip view updated ${new Date(snapshot.synced_at).toLocaleString()}`;
    }
    $('expense-fields').disabled = !snapshot || client.expired || closed || syncing;
    $('sync').disabled = client.expired || closed || syncing; $('sync').textContent = syncing ? 'Syncing…' : 'Sync now';
    $('pending-count').textContent = String(pending.length); $('pending-empty').hidden = pending.length > 0;
    $('pending').replaceChildren(...pending.map(item => {
      const li = doc.createElement('li'), top = text('div', '', 'entry-top');
      top.append(text('strong', `${item.expense.currency} ${item.expense.amount}`, 'num'), text('span', item.expense.date, 'muted small')); li.append(top);
      li.append(text('p', snapshot?.categories.find(row => row.id === item.expense.category)?.name ?? item.expense.category));
      if (item.expense.note) li.append(text('p', item.expense.note, 'muted small'));
      li.append(text('p', item.error ?? (item.request ? 'Waiting for host confirmation' : 'Saved on this device · not sent'), 'muted small'));
      const remove = text('button', 'Remove from queue', 'secondary'); remove.type = 'button'; remove.disabled = syncing;
      remove.addEventListener('click', async () => {
        if (!win.confirm('Remove this pending expense? If already sent, the host may still save it.')) return;
        try { await client.remove(item.id); render(); } catch (error) { status(explain(error), true); }
      }); li.append(remove); return li;
    }));
    const recent = snapshot?.recent ?? []; $('history-empty').hidden = recent.length > 0;
    $('history-empty').textContent = snapshot ? 'No expenses in this trip yet.' : 'Sync to see the latest trip view.';
    $('history').replaceChildren(...recent.map(row => {
      const li = doc.createElement('li'), top = text('div', '', 'entry-top');
      top.append(text('strong', row.category), text('span', row.amount, 'num')); li.append(top, text('p', row.date, 'muted small'));
      if (row.note) li.append(text('p', row.note, 'muted small')); return li;
    }));
  }
  function schedule() {
    clearTimeout(timer);
    if (!client || closed || doc.hidden || client.expired) return;
    timer = setTimeout(() => sync(), client.state.pending.length || client.state.read ? 10000 : 60000);
  }
  async function sync() {
    if (!client || syncing || closed || doc.hidden) return;
    if (!win.navigator.onLine) { status('Offline. Expenses saved on this device will sync when this page is online and visible.'); schedule(); return; }
    syncing = true; controller = new AbortController(); render();
    try { await client.sync({ signal: controller.signal, onProgress: message => status(message) }); status('Up to date. The host confirmed this trip view.'); if ($('form-status').textContent && !client.state.pending.length) $('form-status').textContent = 'Expense saved and confirmed by the host.'; }
    catch (error) { if (error.kind === 'revoked' || error.kind === 'expired') closed = true; status(explain(error), !['waiting', 'offline'].includes(error.kind)); }
    finally { syncing = false; controller = null; render(); schedule(); }
  }
  async function join(code) {
    try {
      const invitation = parseInvitation(code), next = await clientFactory(invitation).load();
      controller?.abort(); clearTimeout(timer); client = next; closed = false;
      try { win.sessionStorage.setItem('expense-guest-invitation', invitation.code); } catch { /* The original link can reopen encrypted pending items. */ }
      if (win.location.hash) win.history.replaceState(null, '', win.location.pathname + win.location.search);
      $('invitation').value = ''; render();
      if (client.expired) { status('This invitation has expired. Ask the host for a new link. Pending expenses remain on this device.', true); return; }
      status('Connecting to the host. Keep their desktop app open.'); await sync();
    } catch (error) { status(explain(error), true); }
  }
  $('join-form').addEventListener('submit', event => { event.preventDefault(); join($('invitation').value); });
  $('sync').addEventListener('click', sync);
  $('expense-form').addEventListener('submit', async event => {
    event.preventDefault(); if (!client || syncing) return;
    $('add').disabled = true;
    try {
      await client.queue(Object.fromEntries(new FormData($('expense-form'))));
      $('amount').value = ''; $('note').value = ''; $('form-status').textContent = 'Saved on this device. Waiting for the host to confirm.'; render(); await sync();
    } catch (error) { $('form-status').textContent = explain(error); }
    finally { $('add').disabled = false; }
  });
  $('leave').addEventListener('click', () => {
    if (!win.confirm('Close this trip on this tab? Keep the original invitation to reopen pending expenses.')) return;
    controller?.abort(); clearTimeout(timer); client = null; closed = true;
    try { win.sessionStorage.removeItem('expense-guest-invitation'); } catch { /* No persistent invitation stored. */ }
    $('trip').hidden = true; $('join').hidden = false; status('Trip closed. Encrypted pending expenses remain on this device.');
  });
  doc.addEventListener('visibilitychange', () => { if (doc.hidden) { clearTimeout(timer); controller?.abort(); } else sync(); });
  win.addEventListener('online', sync);
  win.addEventListener('offline', () => { controller?.abort(); status('Offline. Pending expenses remain on this device.'); });
  const now = new Date(); $('date').value = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`;
  let code = initialInvitationCode;
  if (!code) code = new URLSearchParams(win.location.hash.slice(1)).get('invite');
  if (!code) try { code = win.sessionStorage.getItem('expense-guest-invitation'); } catch { /* Joining still works with the original invitation. */ }
  if (code) join(code);
  return { join, sync };
}
