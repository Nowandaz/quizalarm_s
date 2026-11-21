// Admin website. Plain JavaScript, no build step: open index.html from any
// web server. It signs in through Supabase and everything it does is checked
// by the database rules, so this code holds no secret and grants no power.
//
// Sections: helpers, sign-in, shell, dashboard, question bank, accounts,
// settings (AI providers, AI limits).
'use strict';

const CONFIG = window.BRAINWAKE_CONFIG;
const db = window.supabase.createClient(CONFIG.supabaseUrl, CONFIG.supabaseKey);
const app = document.getElementById('app');
document.title = `${CONFIG.appName} admin`;

// ------------------------------------------------------------------ helpers

/** Builds a DOM element: h('div', {class: 'card', onclick: f}, child, ...). */
function h(tag, attrs, ...children) {
  const el = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs || {})) {
    if (value === null || value === undefined || value === false) continue;
    if (key.startsWith('on')) el.addEventListener(key.slice(2), value);
    else if (key === 'class') el.className = value;
    else if (key === 'value') el.value = value;
    else if (key === 'checked' || key === 'disabled' || key === 'selected') el[key] = !!value;
    else el.setAttribute(key, value === true ? '' : value);
  }
  for (const child of children.flat(Infinity)) {
    if (child === null || child === undefined || child === false) continue;
    el.append(child.nodeType ? child : document.createTextNode(String(child)));
  }
  return el;
}

/** Replaces an element's content, skipping empty values (so `cond && el`
 *  can be used in the list without printing "false"). */
function fill(el, ...children) {
  el.replaceChildren(...children.flat(Infinity).filter((c) => c !== null && c !== undefined && c !== false && c !== ''));
}

// Small line icons (drawn here so the site needs no icon files).
const ICONS = {
  home: 'M3 11l9-8 9 8M5 10v10h14V10',
  book: 'M4 5a2 2 0 012-2h13v16H6a2 2 0 00-2 2zM4 19V5M9 7h6',
  users: 'M16 19v-1a4 4 0 00-4-4H7a4 4 0 00-4 4v1M9.5 10a3.5 3.5 0 100-7 3.5 3.5 0 000 7M21 19v-1a4 4 0 00-3-3.8M15.5 3.2a3.5 3.5 0 010 6.6',
  settings: 'M4 6h10M18 6h2M4 12h4M12 12h8M4 18h12M20 18h0M14 4v4M8 10v4M16 16v4',
  plus: 'M12 5v14M5 12h14',
  edit: 'M4 20h4L19 9l-4-4L4 16zM14 6l4 4',
  trash: 'M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6',
  spark: 'M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 16l.7 2 .2.1 2 .7-2 .7-.2.1-.7 2-.7-2-.2-.1-2-.7 2-.7.2-.1z',
  image: 'M4 5h16v14H4zM4 16l5-5 4 4 3-3 4 4M9 9.5a1 1 0 100-2 1 1 0 000 2',
  upload: 'M12 16V4M7 9l5-5 5 5M4 20h16',
  download: 'M12 4v12M7 11l5 5 5-5M4 20h16',
  check: 'M5 12l5 5 9-10',
  test: 'M9 3h6M10 3v6l-5 9a2 2 0 002 3h10a2 2 0 002-3l-5-9V3M8 15h8',
  layers: 'M12 3l9 5-9 5-9-5zM3 13l9 5 9-5',
  gauge: 'M4 18a8 8 0 1116 0M12 18l4-6',
  alarm: 'M12 21a8 8 0 100-16 8 8 0 000 16M12 9v4l2.5 2M5 3L2 6M19 3l3 3',
};
function icon(name) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('class', 'icon');
  svg.setAttribute('aria-hidden', 'true');
  const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  path.setAttribute('d', ICONS[name] || '');
  svg.append(path);
  return svg;
}

function toast(message, bad = false) {
  const el = h('div', { class: bad ? 'toast bad' : 'toast' }, message);
  document.getElementById('toasts').append(el);
  setTimeout(() => el.remove(), bad ? 7000 : 3000);
}

/** Unwraps a Supabase result; throws a readable error if it failed. */
function ok(result) {
  if (result.error) throw new Error(result.error.message || String(result.error));
  return result.data;
}

/** Runs an action, showing its error instead of failing silently. */
async function attempt(action, doneMessage) {
  try {
    const value = await action();
    if (doneMessage) toast(doneMessage);
    return value;
  } catch (error) {
    console.error(error);
    toast(error.message || 'Something went wrong', true);
    return undefined;
  }
}

function slug(text) {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || 'item';
}

function randomId(length = 6) {
  return Array.from(crypto.getRandomValues(new Uint8Array(length)))
    .map((n) => 'abcdefghijklmnopqrstuvwxyz0123456789'[n % 36]).join('');
}

function when(value) {
  if (!value) return '-';
  return new Date(value).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });
}

function imageUrl(path) {
  if (!path) return '';
  if (/^(https?:|data:)/.test(path)) return path;
  return `${CONFIG.supabaseUrl}/storage/v1/object/public/${CONFIG.imageBucket}/${path}`;
}

/** Opens a dialog; build(close) returns its content. */
function dialog(build) {
  const overlay = h('div', { class: 'overlay' });
  const close = () => overlay.remove();
  overlay.append(h('div', { class: 'dialog stack' }, build(close)));
  overlay.addEventListener('mousedown', (event) => { if (event.target === overlay) close(); });
  document.body.append(overlay);
  const first = overlay.querySelector('input, textarea, select');
  if (first) first.focus();
  return close;
}

function confirmDialog(title, body, actionLabel, action) {
  dialog((close) => [
    h('h2', {}, title),
    h('p', { class: 'muted' }, body),
    h('div', { class: 'row' },
      h('button', { class: 'right', onclick: close }, 'Cancel'),
      h('button', { class: 'primary', onclick: async () => { close(); await action(); } }, actionLabel)),
  ]);
}

function field(label, input, hint) {
  return h('div', { class: 'field' }, h('label', {}, label), input, hint && h('div', { class: 'muted small', style: 'margin-top:4px' }, hint));
}

function toggle(checked, onchange, title) {
  return h('label', { class: 'switch', title: title || '' }, h('input', { type: 'checkbox', checked, onchange }), h('span', {}));
}

function pageHead(title, subtitle, ...actions) {
  return h('div', { class: 'page-head' },
    h('div', {}, h('h1', {}, title), subtitle && h('p', { class: 'muted', style: 'margin:0' }, subtitle)),
    h('div', { class: 'row' }, actions));
}

// ------------------------------------------------------------------ session

const state = { user: null, profile: null };
const isOwner = () => state.profile && state.profile.role === 'owner';
const isAdmin = () => state.profile && ['admin', 'owner'].includes(state.profile.role);

async function loadProfile() {
  const { data: { session } } = await db.auth.getSession();
  state.user = session ? session.user : null;
  state.profile = null;
  if (state.user) {
    const rows = ok(await db.from('profiles').select('*').eq('id', state.user.id));
    state.profile = rows[0] || null;
  }
}

async function start() {
  try {
    await loadProfile();
  } catch (error) {
    fill(app, h('p', { class: 'center' }, `Could not reach the server: ${error.message}`));
    return;
  }
  render();
}

db.auth.onAuthStateChange((event) => {
  if (event === 'PASSWORD_RECOVERY') { renderNewPassword(); return; }
  if (event === 'SIGNED_IN' || event === 'SIGNED_OUT') setTimeout(start, 0);
});
window.addEventListener('hashchange', render);

function render() {
  if (!state.user) return renderSignIn();
  if (!isAdmin()) return renderNotAdmin();
  renderShell();
}

// ------------------------------------------------------------------ sign-in

function renderSignIn() {
  let creating = false;
  const email = h('input', { type: 'email', autocomplete: 'email', placeholder: 'you@example.com' });
  const password = h('input', { type: 'password', autocomplete: 'current-password' });
  const submit = h('button', { class: 'primary', style: 'width:100%;justify-content:center' });
  const switchMode = h('a', {});
  const note = h('p', { class: 'muted small' });

  const refresh = () => {
    submit.textContent = creating ? 'Create account' : 'Sign in';
    switchMode.textContent = creating ? 'I already have an account' : 'Create an account';
  };
  switchMode.addEventListener('click', () => { creating = !creating; refresh(); });
  refresh();

  const go = async () => {
    if (!email.value.trim() || !password.value) { toast('Enter your email and password', true); return; }
    submit.disabled = true;
    await attempt(async () => {
      if (creating) {
        const data = ok(await db.auth.signUp({
          email: email.value.trim(),
          password: password.value,
          options: { emailRedirectTo: location.origin + location.pathname },
        }));
        if (!data.session) {
          note.textContent = 'Account created. Open the confirmation link sent to your email, then sign in here.';
        }
      } else {
        ok(await db.auth.signInWithPassword({ email: email.value.trim(), password: password.value }));
      }
    });
    submit.disabled = false;
  };
  submit.addEventListener('click', go);
  password.addEventListener('keydown', (event) => { if (event.key === 'Enter') go(); });

  fill(app, h('div', { class: 'auth' },
    h('h1', {}, `${CONFIG.appName} admin`),
    h('p', { class: 'muted' }, 'Sign in to manage the question bank.'),
    h('div', { class: 'card' },
      field('Email', email),
      field('Password', password),
      submit,
      note,
      h('div', { class: 'row spread small', style: 'margin-top:10px' },
        switchMode,
        h('a', { onclick: async () => {
          if (!email.value.trim()) { toast('Type your email first', true); return; }
          await attempt(async () => ok(await db.auth.resetPasswordForEmail(email.value.trim(), {
            redirectTo: location.origin + location.pathname,
          })), 'Password reset email sent');
        } }, 'Forgot password?')),
      h('div', { class: 'divider' }, 'or'),
      h('button', { style: 'width:100%;justify-content:center', onclick: () => attempt(async () => ok(await db.auth.signInWithOAuth({
        provider: 'google',
        options: { redirectTo: location.origin + location.pathname },
      }))) }, 'Continue with Google'))));
}

function renderNewPassword() {
  const password = h('input', { type: 'password', autocomplete: 'new-password' });
  fill(app, h('div', { class: 'auth' },
    h('h1', {}, 'Choose a new password'),
    h('div', { class: 'card' },
      field('New password', password, 'At least 6 characters.'),
      h('button', { class: 'primary', style: 'width:100%;justify-content:center', onclick: async () => {
        const done = await attempt(async () => ok(await db.auth.updateUser({ password: password.value })), 'Password changed');
        if (done) start();
      } }, 'Save password'))));
}

async function renderNotAdmin() {
  const box = h('div', { class: 'card stack' },
    h('p', {}, `Signed in as ${state.user.email}.`),
    h('p', { class: 'muted' }, 'This account is not an admin. Ask the owner to give it admin access.'));
  fill(app, h('div', { class: 'auth' }, h('h1', {}, `${CONFIG.appName} admin`), box,
    h('p', { style: 'margin-top:12px' }, h('a', { onclick: () => db.auth.signOut() }, 'Sign out'))));

  // First set-up: while nobody owns the system, the signed-in person can.
  const exists = await attempt(async () => ok(await db.rpc('owner_exists')));
  if (exists === false) {
    box.append(
      h('p', {}, 'Nobody owns this system yet. The owner can do everything: manage questions, accounts, plans, settings and keys.'),
      h('button', { class: 'primary', onclick: async () => {
        const claimed = await attempt(async () => ok(await db.rpc('claim_owner')));
        if (claimed) { toast('You are now the owner'); start(); } else toast('Someone else is already the owner', true);
      } }, 'Make me the owner'));
  }
}

// -------------------------------------------------------------------- shell

function route() {
  const parts = location.hash.replace(/^#\/?/, '').split('/').filter(Boolean).map(decodeURIComponent);
  return { page: parts[0] || 'dashboard', a: parts[1], b: parts[2] };
}

function renderShell() {
  const { page, a, b } = route();
  const link = (name, label, iconName) => h('a', { class: page === name ? 'nav on' : 'nav', href: `#/${name}` }, icon(iconName), label);
  const main = h('div', { class: 'main' }, h('p', { class: 'muted' }, 'Loading...'));
  const name = (state.profile && state.profile.display_name) || state.user.email;

  fill(app, 
    CONFIG.demo && h('div', { class: 'demo-banner' }, 'Preview with made-up data. Nothing here is saved.'),
    h('div', { class: 'shell' },
      h('div', { class: 'side' },
        h('div', { class: 'brand' }, CONFIG.appName),
        h('div', { class: 'brand-sub' }, 'Admin'),
        link('dashboard', 'Dashboard', 'home'),
        link('bank', 'Question bank', 'book'),
        link('alarms', 'Alarm reports', 'alarm'),
        isOwner() && link('users', 'Accounts', 'users'),
        isOwner() && link('settings', 'Settings', 'settings'),
        h('div', { class: 'who' },
          h('div', { style: 'font-weight:700' }, name),
          h('div', { class: 'row spread', style: 'margin-top:6px' },
            h('span', { class: 'pill accent' }, isOwner() ? 'Owner' : 'Admin'),
            h('a', { onclick: () => db.auth.signOut() }, 'Sign out')))),
      main));

  const pages = {
    dashboard: () => pageDashboard(main),
    bank: () => (b ? pageTopic(main, a, b) : a ? pageUnit(main, a) : pageBank(main)),
    alarms: () => pageAlarms(main),
    users: () => (isOwner() ? pageUsers(main) : pageDashboard(main)),
    settings: () => (isOwner() ? pageSettings(main, a) : pageDashboard(main)),
  };
  attempt(pages[page] || pages.dashboard);
}

// ---------------------------------------------------------------- dashboard

async function pageDashboard(main) {
  const stats = ok(await db.rpc('admin_stats'));
  const providers = isOwner() ? ok(await db.rpc('admin_list_ai_providers')) : null;
  const card = (iconName, value, label) => h('div', { class: 'card stat' },
    h('div', { class: 'ic' }, icon(iconName)), h('div', {}, h('b', {}, value ?? 0), h('span', {}, label)));
  const name = (state.profile && state.profile.display_name) || state.user.email.split('@')[0];

  const active = providers ? providers.filter((p) => p.enabled) : [];
  fill(main, 
    pageHead(`Welcome, ${name}`, 'What is in the bank and how it is being used.',
      h('button', { class: 'primary', onclick: () => { location.hash = '#/bank'; } }, icon('plus'), 'Add questions')),

    providers && active.length === 0 && h('div', { class: 'card row', style: 'border-color:var(--bad)' },
      icon('spark'),
      h('div', { class: 'grow' }, h('b', {}, 'No AI provider is switched on'),
        h('div', { class: 'muted small' }, 'AI features in the app (new questions, the tutor) will not work until you add one.')),
      h('button', { onclick: () => { location.hash = '#/settings/providers'; } }, 'Add a provider')),

    h('div', { class: 'section' }, h('h2', {}, 'Question bank'),
      h('div', { class: 'grid' },
        card('layers', stats.units, 'Units'), card('book', stats.topics, 'Topics'),
        card('check', stats.questions, 'Questions'), card('image', stats.with_pictures, 'With a picture'),
        card('edit', stats.drafts, 'Drafts (hidden)'))),
    h('div', { class: 'section' }, h('h2', {}, 'People'),
      h('div', { class: 'grid' },
        card('users', stats.users, 'Accounts'), card('spark', stats.premium_users, 'Premium'),
        card('gauge', stats.active_users_7d, 'Active, last 7 days'),
        card('check', stats.answers_7d, 'Answers, last 7 days'))),
    h('div', { class: 'section' }, h('h2', {}, 'AI'),
      h('div', { class: 'grid' },
        card('spark', stats.ai_calls_today, 'AI calls today'),
        providers && card('layers', active.length, `Provider${active.length === 1 ? '' : 's'} switched on`),
        providers && card('gauge', providers.reduce((n, p) => n + Number(p.uses), 0), 'AI calls served in total'))));
}

// ------------------------------------------------------------ question bank

async function pageBank(main) {
  const units = ok(await db.from('units').select('*').order('sort_order').order('name'));
  const topics = ok(await db.from('topics').select('id, unit_id, deleted_at'));
  const questions = ok(await db.from('questions').select('id, topic_id, status, image_path, deleted_at'));
  const liveTopics = topics.filter((t) => !t.deleted_at);
  const of = (unitId) => {
    const ids = new Set(liveTopics.filter((t) => t.unit_id === unitId).map((t) => t.id));
    const qs = questions.filter((q) => !q.deleted_at && ids.has(q.topic_id));
    return { topics: ids.size, questions: qs.length, drafts: qs.filter((q) => q.status === 'draft').length, pictures: qs.filter((q) => q.image_path).length };
  };

  fill(main, 
    pageHead('Question bank', 'Units, their topics and questions. Changes reach the app the next time it syncs.',
      h('button', { onclick: () => importDialog() }, icon('upload'), 'Import a file'),
      h('button', { class: 'primary', onclick: () => unitDialog(null, units.length) }, icon('plus'), 'Add unit')),
    units.length === 0 && h('div', { class: 'card center muted' }, 'No units yet. Add one, or import a bank file.'),
    h('div', { class: 'grid wide' }, units.map((u) => {
      const n = of(u.id);
      return h('div', { class: u.deleted_at ? 'card click gone' : 'card click', onclick: () => { location.hash = `#/bank/${encodeURIComponent(u.id)}`; } },
        h('div', { class: 'row spread' },
          h('h3', {}, u.name),
          h('div', { class: 'row' },
            u.deleted_at && h('span', { class: 'pill bad' }, 'Deleted'),
            u.premium ? h('span', { class: 'pill accent' }, 'Premium') : h('span', { class: 'pill' }, 'Free'),
            h('button', { class: 'icon-btn', title: 'Edit unit', onclick: (e) => { e.stopPropagation(); unitDialog(u); } }, icon('edit')))),
        h('p', { class: 'muted small', style: 'min-height:20px;margin:6px 0 12px' }, u.description || 'No description.'),
        h('div', { class: 'row small' },
          h('span', {}, h('b', {}, n.topics), ' topics'),
          h('span', {}, h('b', {}, n.questions), ' questions'),
          n.pictures > 0 && h('span', { class: 'muted' }, `${n.pictures} with a picture`),
          n.drafts > 0 && h('span', { class: 'pill' }, `${n.drafts} draft${n.drafts === 1 ? '' : 's'}`)));
    })));
}

function unitDialog(unit, nextOrder = 0) {
  const name = h('input', { type: 'text', value: unit ? unit.name : '' });
  const description = h('textarea', {}, unit ? unit.description : '');
  const order = h('input', { type: 'number', value: unit ? unit.sort_order : nextOrder });
  const premium = h('input', { type: 'checkbox', checked: unit && unit.premium });
  dialog((close) => [
    h('h2', {}, unit ? 'Edit unit' : 'Add unit'),
    field('Name', name),
    field('Description', description),
    field('Order', order, 'Lower numbers come first in the app.'),
    h('label', { class: 'check' }, premium, 'Premium unit'),
    h('p', { class: 'muted small' }, 'Everyone sees that a premium unit exists, but only signed-in users with a premium plan get its questions.'),
    h('div', { class: 'row' },
      unit && (unit.deleted_at
        ? h('button', { onclick: async () => { await attempt(async () => ok(await db.from('units').update({ deleted_at: null }).eq('id', unit.id)), 'Unit restored'); close(); render(); } }, 'Restore')
        : h('button', { class: 'danger', onclick: () => { close(); confirmDialog(`Delete "${unit.name}"?`, 'The unit disappears from the app at its next sync. It can be restored here later.', 'Delete', async () => { await attempt(async () => ok(await db.from('units').update({ deleted_at: new Date().toISOString() }).eq('id', unit.id)), 'Unit deleted'); render(); }); } }, 'Delete')),
      h('button', { class: 'right', onclick: close }, 'Cancel'),
      h('button', { class: 'primary', onclick: async () => {
        if (!name.value.trim()) { toast('Give the unit a name', true); return; }
        const row = { name: name.value.trim(), description: description.value.trim(), sort_order: Number(order.value) || 0, premium: premium.checked };
        const saved = await attempt(async () => {
          if (unit) return ok(await db.from('units').update(row).eq('id', unit.id).select());
          return ok(await db.from('units').insert({ id: await freeId('units', slug(row.name)), ...row }).select());
        }, 'Saved');
        if (saved) { close(); render(); }
      } }, 'Save')),
  ]);
}

/** An id that is not taken yet in a table: 'name', 'name-2', ... */
async function freeId(table, base) {
  const taken = new Set(ok(await db.from(table).select('id').like('id', `${base}%`)).map((r) => r.id));
  if (!taken.has(base)) return base;
  for (let n = 2; ; n++) if (!taken.has(`${base}-${n}`)) return `${base}-${n}`;
}

async function pageUnit(main, unitId) {
  const unit = ok(await db.from('units').select('*').eq('id', unitId))[0];
  if (!unit) { fill(main, h('p', {}, 'That unit does not exist.')); return; }
  const topics = ok(await db.from('topics').select('*').eq('unit_id', unitId).order('sort_order').order('name'));
  const questions = ok(await db.from('questions').select('id, topic_id, status, image_path, deleted_at').in('topic_id', topics.map((t) => t.id).concat('-')));
  const of = (topicId) => questions.filter((q) => q.topic_id === topicId && !q.deleted_at);
  const most = Math.max(1, ...topics.map((t) => of(t.id).length));

  fill(main, 
    h('div', { class: 'crumbs' }, h('a', { href: '#/bank' }, 'Question bank'), ' / ', unit.name),
    pageHead([unit.name, unit.premium && h('span', { class: 'pill accent', style: 'margin-left:10px;vertical-align:middle' }, 'Premium')],
      unit.description || 'No description.',
      h('button', { onclick: () => exportUnit(unit) }, icon('download'), 'Export'),
      h('button', { onclick: () => unitDialog(unit) }, icon('edit'), 'Edit unit'),
      h('button', { class: 'primary', onclick: () => topicDialog(unit, null, topics.length) }, icon('plus'), 'Add topic')),
    topics.length === 0 && h('div', { class: 'card center muted' }, 'No topics yet.'),
    h('div', { class: 'list' }, topics.map((t) => {
      const qs = of(t.id);
      const drafts = qs.filter((q) => q.status === 'draft').length;
      return h('div', { class: t.deleted_at ? 'card click gone' : 'card click', onclick: () => { location.hash = `#/bank/${encodeURIComponent(unit.id)}/${encodeURIComponent(t.id)}`; } },
        h('div', { class: 'row spread' },
          h('h3', {}, t.name, t.deleted_at && h('span', { class: 'pill bad', style: 'margin-left:8px' }, 'Deleted')),
          h('div', { class: 'row small' },
            h('span', {}, h('b', {}, qs.length), ' questions'),
            drafts > 0 && h('span', { class: 'pill' }, `${drafts} draft${drafts === 1 ? '' : 's'}`),
            qs.some((q) => q.image_path) && h('span', { class: 'pill accent' }, 'Pictures'),
            h('button', { class: 'icon-btn', title: 'Edit topic', onclick: (e) => { e.stopPropagation(); topicDialog(unit, t); } }, icon('edit')))),
        h('div', { class: 'bar', style: 'margin-top:10px', title: 'Share of this unit\'s questions' }, h('i', { style: `width:${Math.round(100 * qs.length / most)}%` })));
    })));
}

function topicDialog(unit, topic, nextOrder = 0) {
  const name = h('input', { type: 'text', value: topic ? topic.name : '' });
  const order = h('input', { type: 'number', value: topic ? topic.sort_order : nextOrder });
  dialog((close) => [
    h('h2', {}, topic ? 'Edit topic' : `Add a topic to ${unit.name}`),
    field('Name', name),
    field('Order', order),
    h('div', { class: 'row' },
      topic && (topic.deleted_at
        ? h('button', { onclick: async () => { await attempt(async () => ok(await db.from('topics').update({ deleted_at: null }).eq('id', topic.id)), 'Topic restored'); close(); render(); } }, 'Restore')
        : h('button', { class: 'danger', onclick: () => { close(); confirmDialog(`Delete "${topic.name}"?`, 'The topic and its questions disappear from the app at its next sync. It can be restored here later.', 'Delete', async () => { await attempt(async () => ok(await db.from('topics').update({ deleted_at: new Date().toISOString() }).eq('id', topic.id)), 'Topic deleted'); render(); }); } }, 'Delete')),
      h('button', { class: 'right', onclick: close }, 'Cancel'),
      h('button', { class: 'primary', onclick: async () => {
        if (!name.value.trim()) { toast('Give the topic a name', true); return; }
        const row = { name: name.value.trim(), sort_order: Number(order.value) || 0 };
        const saved = await attempt(async () => {
          if (topic) return ok(await db.from('topics').update(row).eq('id', topic.id).select());
          return ok(await db.from('topics').insert({ id: await freeId('topics', `${unit.id}-${slug(row.name)}`), unit_id: unit.id, ...row }).select());
        }, 'Saved');
        if (saved) { close(); render(); }
      } }, 'Save')),
  ]);
}

async function pageTopic(main, unitId, topicId) {
  const unit = ok(await db.from('units').select('*').eq('id', unitId))[0];
  const topic = ok(await db.from('topics').select('*').eq('id', topicId))[0];
  if (!unit || !topic) { fill(main, h('p', {}, 'That topic does not exist.')); return; }
  const questions = ok(await db.from('questions').select('*').eq('topic_id', topicId).order('created_at'));

  let filter = 'live';
  let search = '';
  const list = h('div', { class: 'list' });
  const chips = h('div', { class: 'chips' });
  const live = questions.filter((x) => !x.deleted_at);
  const FILTERS = [
    ['live', 'All', live.length],
    ['published', 'Published', live.filter((x) => x.status === 'published').length],
    ['draft', 'Drafts', live.filter((x) => x.status === 'draft').length],
    ['picture', 'With a picture', live.filter((x) => x.image_path).length],
    ['deleted', 'Deleted', questions.length - live.length],
  ];

  const draw = () => {
    fill(chips, ...FILTERS.map(([key, label, n]) => h('button', { class: filter === key ? 'chip on' : 'chip', onclick: () => { filter = key; draw(); } }, `${label} (${n})`)));
    const q = search.trim().toLowerCase();
    const rows = questions.filter((x) => {
      if (filter === 'deleted') { if (!x.deleted_at) return false; } else if (x.deleted_at) return false;
      if (filter === 'published' && x.status !== 'published') return false;
      if (filter === 'draft' && x.status !== 'draft') return false;
      if (filter === 'picture' && !x.image_path) return false;
      return !q || x.text.toLowerCase().includes(q) || x.answer.toLowerCase().includes(q);
    });
    fill(list, ...rows.map((x, index) => questionCard(topic, x, index + 1)),
      rows.length === 0 ? h('div', { class: 'card center muted' }, 'No questions match.') : '');
  };

  fill(main, 
    h('div', { class: 'crumbs' }, h('a', { href: '#/bank' }, 'Question bank'), ' / ',
      h('a', { href: `#/bank/${encodeURIComponent(unit.id)}` }, unit.name), ' / ', topic.name),
    pageHead(topic.name, `${live.length} question${live.length === 1 ? '' : 's'} in ${unit.name}`,
      h('button', { class: 'primary', onclick: () => questionDialog(topic, null) }, icon('plus'), 'Add question')),
    h('div', { class: 'row', style: 'margin-bottom:12px' },
      h('input', { type: 'search', class: 'grow', style: 'max-width:420px', placeholder: 'Search questions and answers', oninput: (e) => { search = e.target.value; draw(); } }),
      chips),
    list);
  draw();
}

/** One question as a readable card: picture, text, options with the right
 *  one marked (or the typed answer), and the start of the explanation. */
function questionCard(topic, x, number) {
  return h('div', { class: x.deleted_at ? 'card click gone q' : 'card click q', onclick: () => questionDialog(topic, x) },
    h('div', { class: 'num' }, number),
    h('div', { class: 'grow' },
      h('div', { class: 'row', style: 'margin-bottom:6px' },
        h('span', { class: 'pill' }, x.type === 'mcq' ? 'Multiple choice' : 'Typed answer'),
        x.deleted_at ? h('span', { class: 'pill bad' }, 'Deleted')
          : x.status === 'draft' ? h('span', { class: 'pill' }, 'Draft') : h('span', { class: 'pill ok' }, 'Published'),
        x.source === 'ai' && h('span', { class: 'pill accent' }, 'AI'),
        x.image_path && h('span', { class: 'pill accent' }, 'Picture')),
      h('div', { class: 'text' }, x.text),
      x.type === 'mcq'
        ? h('div', { class: 'opts' }, (x.options || []).map((o, i) => h('div', { class: o === x.answer ? 'opt right-answer' : 'opt' }, h('b', {}, 'ABCDE'[i] || ''), o)))
        : h('div', { class: 'opts' },
            h('div', { class: 'opt right-answer' }, h('b', {}, icon('check')), x.answer),
            (x.alt_answers || []).map((a) => h('div', { class: 'opt' }, h('b', {}, '='), a))),
      x.explanation ? h('div', { class: 'explain' }, x.explanation) : h('div', { class: 'explain', style: 'color:var(--bad)' }, 'No explanation yet.')),
    x.image_path && h('img', { src: imageUrl(x.image_path), alt: 'Question picture', loading: 'lazy' }));
}

function questionDialog(topic, question) {
  const isNew = !question;
  const q = question || { type: 'mcq', text: '', options: ['', '', '', '', ''], answer: '', alt_answers: [], explanation: '', image_path: '', status: 'published' };
  let imagePath = q.image_path || '';

  const type = h('select', {}, h('option', { value: 'mcq' }, 'Multiple choice (5 options)'), h('option', { value: 'saq' }, 'Typed answer'));
  type.value = q.type;
  const text = h('textarea', {}, q.text);
  const explanation = h('textarea', { style: 'min-height:110px' }, q.explanation);
  const status = h('select', {}, h('option', { value: 'published' }, 'Published (visible in the app)'), h('option', { value: 'draft' }, 'Draft (hidden from the app)'));
  status.value = q.status;

  // Multiple choice: five boxes, one marked correct.
  const startOptions = q.type === 'mcq' && q.options.length === 5 ? q.options : ['', '', '', '', ''];
  const optionInputs = startOptions.map((o, i) => h('input', { type: 'text', value: o, placeholder: `Option ${'ABCDE'[i]}` }));
  const radios = startOptions.map((o) => h('input', { type: 'radio', name: 'correct', title: 'Correct answer', checked: q.type === 'mcq' && o === q.answer && o !== '' }));
  if (!radios.some((r) => r.checked)) radios[0].checked = true;
  const mcqBox = h('div', {}, h('label', {}, 'Options (select the correct one)'),
    optionInputs.map((input, i) => h('div', { class: 'option-row' }, radios[i], input)));

  // Typed answer: the answer plus other accepted spellings.
  const answer = h('input', { type: 'text', value: q.type === 'saq' ? q.answer : '' });
  const alternatives = h('textarea', { style: 'min-height:60px' }, (q.alt_answers || []).join('\n'));
  const saqBox = h('div', {}, field('Answer', answer),
    field('Also accepted', alternatives, 'One per line: other names or spellings that count as correct.'));

  const showType = () => { mcqBox.style.display = type.value === 'mcq' ? '' : 'none'; saqBox.style.display = type.value === 'saq' ? '' : 'none'; };
  type.addEventListener('change', showType);
  showType();

  // Picture.
  const preview = h('div', {});
  const drawPreview = () => fill(preview, imagePath
    ? h('div', { class: 'row' }, h('img', { class: 'thumb', src: imageUrl(imagePath), alt: 'Question picture' }),
        h('button', { class: 'small danger', onclick: () => { imagePath = ''; drawPreview(); } }, 'Remove picture'))
    : h('span', { class: 'muted small' }, 'No picture.'));
  drawPreview();
  const file = h('input', { type: 'file', accept: 'image/png,image/jpeg,image/webp', onchange: async (e) => {
    const picked = e.target.files[0];
    if (!picked) return;
    if (picked.size > 5 * 1024 * 1024) { toast('Pictures must be under 5 MB', true); return; }
    const extension = (picked.name.split('.').pop() || 'png').toLowerCase().replace(/[^a-z0-9]/g, '');
    const path = `q/${topic.id}/${Date.now()}-${randomId()}.${extension}`;
    const uploaded = await attempt(async () => ok(await db.storage.from(CONFIG.imageBucket).upload(path, picked, { contentType: picked.type })), 'Picture uploaded');
    if (uploaded) { imagePath = path; drawPreview(); }
  } });

  dialog((close) => [
    h('h2', {}, isNew ? `Add a question to ${topic.name}` : 'Edit question'),
    h('div', { class: 'row' }, h('div', { class: 'grow' }, field('Type', type)), h('div', { class: 'grow' }, field('Status', status))),
    field('Question', text),
    mcqBox, saqBox,
    field('Explanation', explanation, 'Shown after answering, also offline. Say why the answer is right.'),
    h('div', { class: 'field' }, h('label', {}, 'Picture (for spotter questions)'), preview, h('div', { style: 'margin-top:8px' }, file)),
    h('div', { class: 'row' },
      !isNew && (q.deleted_at
        ? h('button', { onclick: async () => { await attempt(async () => ok(await db.from('questions').update({ deleted_at: null }).eq('id', q.id)), 'Question restored'); close(); render(); } }, 'Restore')
        : h('button', { class: 'danger', onclick: () => { close(); confirmDialog('Delete this question?', 'It disappears from the app at its next sync. It can be restored here later.', 'Delete', async () => { await attempt(async () => ok(await db.from('questions').update({ deleted_at: new Date().toISOString() }).eq('id', q.id)), 'Question deleted'); render(); }); } }, 'Delete')),
      h('button', { class: 'right', onclick: close }, 'Cancel'),
      h('button', { class: 'primary', onclick: async () => {
        const row = { type: type.value, text: text.value.trim(), explanation: explanation.value.trim(), image_path: imagePath, status: status.value };
        if (!row.text) { toast('Write the question', true); return; }
        if (row.type === 'mcq') {
          const options = optionInputs.map((i) => i.value.trim());
          if (options.some((o) => !o)) { toast('Fill in all five options', true); return; }
          if (new Set(options.map((o) => o.toLowerCase())).size !== 5) { toast('The five options must be different', true); return; }
          row.options = options;
          row.answer = options[radios.findIndex((r) => r.checked)];
          row.alt_answers = [];
        } else {
          if (!answer.value.trim()) { toast('Give the answer', true); return; }
          row.options = [];
          row.answer = answer.value.trim();
          row.alt_answers = alternatives.value.split('\n').map((s) => s.trim()).filter(Boolean);
        }
        const saved = await attempt(async () => {
          if (!isNew) return ok(await db.from('questions').update(row).eq('id', q.id).select());
          return ok(await db.from('questions').insert({ id: `${topic.id}-${randomId()}`, topic_id: topic.id, source: 'admin', created_by: state.user.id, ...row }).select());
        }, 'Saved');
        if (saved) { close(); render(); }
      } }, 'Save')),
  ]);
}

// Import / export use the same file format as the app's bundled banks:
// { unit: {id, name, description, order}, topics: [{id, name, questions: [...]}] }

function importDialog() {
  const file = h('input', { type: 'file', accept: '.json,application/json' });
  const result = h('p', { class: 'muted small' });
  dialog((close) => [
    h('h2', {}, 'Import a bank file'),
    h('p', { class: 'muted' }, 'A JSON file in the app\'s bank format (one unit with its topics and questions). Existing items with the same id are updated; nothing is deleted.'),
    file, result,
    h('div', { class: 'row' },
      h('button', { class: 'right', onclick: () => { close(); render(); } }, 'Close'),
      h('button', { class: 'primary', onclick: async () => {
        if (!file.files[0]) { toast('Choose a file first', true); return; }
        await attempt(async () => {
          const data = JSON.parse(await file.files[0].text());
          if (!data.unit || !data.unit.id || !Array.isArray(data.topics)) throw new Error('This is not a bank file: it needs "unit" and "topics".');
          ok(await db.from('units').upsert({ id: data.unit.id, name: data.unit.name, description: data.unit.description || '', sort_order: data.unit.order || 0 }));
          let nTopics = 0, nQuestions = 0;
          const skipped = [];
          for (const [index, t] of data.topics.entries()) {
            ok(await db.from('topics').upsert({ id: t.id, unit_id: data.unit.id, name: t.name, sort_order: index }));
            nTopics++;
            const rows = [];
            for (const x of t.questions || []) {
              const isMcq = x.type === 'mcq';
              if (isMcq && (!Array.isArray(x.options) || x.options.length !== 5 || !x.options.includes(x.answer))) { skipped.push(x.id); continue; }
              rows.push({
                id: x.id, topic_id: t.id, type: isMcq ? 'mcq' : 'saq', text: String(x.text).trim(),
                options: isMcq ? x.options : [], answer: String(x.answer).trim(), alt_answers: x.alt_answers || [],
                explanation: x.explanation || '', source: 'seed',
                image_path: x.image ? (/^https?:/.test(x.image) ? x.image : `seed/${String(x.image).split('/').pop()}`) : '',
              });
            }
            if (rows.length) ok(await db.from('questions').upsert(rows));
            nQuestions += rows.length;
          }
          result.textContent = `Imported "${data.unit.name}": ${nTopics} topics, ${nQuestions} questions.`
            + (skipped.length ? ` Skipped ${skipped.length} multiple-choice question(s) without exactly 5 options or whose answer is not an option: ${skipped.join(', ')}.` : '');
        });
      } }, 'Import')),
  ]);
}

async function exportUnit(unit) {
  await attempt(async () => {
    const topics = ok(await db.from('topics').select('*').eq('unit_id', unit.id).is('deleted_at', null).order('sort_order'));
    const questions = ok(await db.from('questions').select('*').in('topic_id', topics.map((t) => t.id).concat('-')).is('deleted_at', null).eq('status', 'published').order('created_at'));
    const data = {
      version: Math.floor(Date.now() / 1000),
      unit: { id: unit.id, name: unit.name, description: unit.description, order: unit.sort_order },
      topics: topics.map((t) => ({
        id: t.id, name: t.name,
        questions: questions.filter((q) => q.topic_id === t.id).map((q) => ({
          id: q.id, type: q.type, text: q.text,
          ...(q.type === 'mcq' ? { options: q.options } : {}),
          answer: q.answer,
          ...(q.alt_answers.length ? { alt_answers: q.alt_answers } : {}),
          explanation: q.explanation,
          ...(q.image_path ? { image: imageUrl(q.image_path) } : {}),
        })),
      })),
    };
    const link = h('a', { href: URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })), download: `${unit.id}.json` });
    link.click();
    URL.revokeObjectURL(link.href);
  }, 'Exported');
}

// ------------------------------------------------------------ alarm reports

const ALARM_PROBLEMS = {
  never_rang: 'Alarm never rang',
  rang_late: 'Alarm rang late',
  no_sound: 'Alarm rang but had no sound',
  stopped: 'Alarm stopped unexpectedly',
  snooze_failed: "Snooze didn't work",
  other: 'Other',
};
const EVENT_NAMES = {
  created: 'Alarm created', scheduled: 'Scheduled', rang: 'Rang', dismissed: 'Dismissed',
  snoozed: 'Snoozed', edited: 'Edited', switched_on: 'Switched on', switched_off: 'Switched off',
  skipped: 'Skipped by the user', deleted: 'Deleted', missed: 'MISSED (noticed by the app)',
  report: 'Report sent',
};

function whenExactly(value) {
  if (!value) return '-';
  return new Date(value).toLocaleString(undefined, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

function yesNo(value, good = true) {
  if (value === null || value === undefined) return h('span', { class: 'muted' }, 'unknown');
  const ok = value === good;
  return h('span', { class: ok ? 'pill ok' : 'pill bad' }, value ? 'Yes' : 'No');
}

/** The facts attached to a report, as a two-column list. */
function diagnosticsBox(d) {
  if (!d) return h('p', { class: 'muted small' }, 'No diagnostics were attached.');
  const p = d.permissions || {};
  const device = d.device || {};
  const alarm = d.alarm || {};
  const registered = Object.entries(alarm.registered_with_phone || {});
  const row = (label, value) => [h('div', { class: 'muted' }, label), h('div', {}, value)];
  return h('div', { class: 'kv' },
    row('Scheduled for', whenExactly(d.scheduled)),
    row('Last actual ring', whenExactly(d.last_actual_ring)),
    row('Reported at', whenExactly(d.reported_at)),
    row('Phone', device.model ? `${device.manufacturer} ${device.model}, Android ${device.android} (SDK ${device.sdk})` : (device.platform || 'unknown')),
    row('App version', d.app_version || '-'),
    row('Alarm', alarm.id ? `#${alarm.id}, ${alarm.time}, ${(alarm.days || []).length ? 'days ' + alarm.days.join(',') : 'once'}, ${alarm.enabled ? 'on' : 'off'}, snooze ${alarm.snooze_minutes} min${alarm.custom_ringtone ? ', own ringtone' : ''}` : 'not chosen'),
    row('Registered with the phone', registered.length ? registered.map(([k, v]) => `${k}: ${whenExactly(v)}`).join('; ') : 'nothing'),
    row('Snoozed recently', yesNo(d.snoozed_recently, false)),
    row('Edited recently', yesNo(d.edited_recently, false)),
    row('Switched on/off recently', yesNo(d.switched_recently, false)),
    row('Alarm sounding when reported', yesNo(d.alarm_service_ringing_now, false)),
    row('Battery saving switched off for the app', yesNo(p.battery_unrestricted)),
    row('Notifications allowed', yesNo(p.notifications)),
    row('Exact alarms allowed', yesNo(p.exact_alarms)),
    row('Full-screen alarms allowed', yesNo(p.full_screen)),
    row('May open over other apps', yesNo(p.over_other_apps)),
    row('App was force-stopped', yesNo(d.force_stopped, false)),
    row('Why Android last stopped the app', (d.app_exits || []).length
      ? d.app_exits.map((e) => `${EXIT_REASONS[e.reason] || 'reason ' + e.reason} (${whenExactly(e.at)})${e.description ? ': ' + e.description : ''}`).join('; ')
      : 'not recorded'));
}
// Android's ApplicationExitInfo reasons.
const EXIT_REASONS = {
  1: 'exited by itself', 2: 'killed by a signal', 3: 'low memory', 4: 'crash', 5: 'native crash',
  6: 'not responding', 7: 'start-up failure', 8: 'permission change', 9: 'excessive resource use',
  10: 'stopped by the user', 11: 'user stopped', 12: 'dependency died', 13: 'other', 14: 'frozen',
};

async function pageAlarms(main) {
  let onlyOpen = true;
  const list = h('div', { class: 'list' });
  const healthBox = h('div', {});
  const chips = h('div', { class: 'chips', style: 'margin-bottom:12px' });

  const drawHealth = async () => {
    const x = ok(await db.rpc('admin_alarm_health', { days: 7 }));
    const card = (iconName, value, label, bad) => h('div', { class: 'card stat' },
      h('div', { class: 'ic', style: bad && value > 0 ? 'color:var(--bad)' : '' }, icon(iconName)),
      h('div', {}, h('b', {}, value ?? 0), h('span', {}, label)));
    fill(healthBox,
      h('div', { class: 'grid' },
        card('alarm', x.rang, 'Alarms rang'),
        card('alarm', x.missed, 'Missed (noticed by the app)', true),
        card('gauge', x.late_over_a_minute, 'Rang over a minute late', true),
        card('edit', x.open_reports, 'Reports to look at', true),
        card('users', x.phones_reporting, 'Phones reporting')),
      (x.missed_by_device.length > 0 || x.problems.length > 0) && h('div', { class: 'grid wide', style: 'margin-top:12px' },
        x.missed_by_device.length > 0 && h('div', { class: 'card' }, h('h3', {}, 'Missed alarms by phone'),
          h('table', {}, h('tbody', {}, x.missed_by_device.map((d) => h('tr', {}, h('td', {}, d.device || 'unknown'), h('td', {}, `${d.missed} missed`), h('td', { class: 'muted' }, `${d.users} user${d.users === 1 ? '' : 's'}`)))))),
        x.problems.length > 0 && h('div', { class: 'card' }, h('h3', {}, 'What people reported'),
          h('table', {}, h('tbody', {}, x.problems.map((p) => h('tr', {}, h('td', {}, ALARM_PROBLEMS[p.problem] || p.problem || 'unknown'), h('td', {}, p.reports))))))));
  };

  const drawList = async () => {
    fill(chips,
      h('button', { class: onlyOpen ? 'chip on' : 'chip', onclick: () => { onlyOpen = true; attempt(drawList); } }, 'To look at'),
      h('button', { class: !onlyOpen ? 'chip on' : 'chip', onclick: () => { onlyOpen = false; attempt(drawList); } }, 'All reports'));
    const reports = ok(await db.rpc('admin_alarm_reports', { only_open: onlyOpen, max_rows: 200 }));
    fill(list, reports.map((r) => {
      const d = r.detail || {};
      const rang = d.rang === true;
      const diary = h('div', {});
      const details = h('div', { style: 'display:none;margin-top:12px' }, !rang && diagnosticsBox(d.diagnostics), diary);
      return h('div', { class: r.resolved ? 'card gone' : 'card' },
        h('div', { class: 'row' },
          h('div', { class: 'grow' },
            h('div', { class: 'row' },
              h('h3', {}, rang ? 'It did ring (the app thought it was missed)' : (ALARM_PROBLEMS[d.problem] || d.problem || 'Problem')),
              rang ? h('span', { class: 'pill' }, 'False alarm') : h('span', { class: 'pill bad' }, 'Report'),
              r.resolved && h('span', { class: 'pill ok' }, 'Dealt with')),
            h('div', { class: 'muted small', style: 'margin-top:4px' },
              `${whenExactly(r.at)}  \u00b7  ${r.email || 'unknown user'}  \u00b7  ${r.device || 'unknown phone'}  \u00b7  app ${r.app_version || '?'}`),
            d.note && h('div', { class: 'explain', style: 'margin-top:8px' }, `"${d.note}"`)),
          h('button', { onclick: (e) => {
            const open = details.style.display === 'none';
            details.style.display = open ? '' : 'none';
            e.currentTarget.textContent = open ? 'Hide details' : 'Details';
          } }, 'Details'),
          h('button', { onclick: () => attempt(async () => {
            const events = ok(await db.rpc('admin_alarm_events', { target: r.user_id, around: r.at, hours: 24 }));
            details.style.display = '';
            fill(diary, h('h3', { style: 'margin-top:14px' }, 'What the phone recorded in the 24 hours before'),
              events.length === 0 ? h('p', { class: 'muted small' }, 'Nothing was recorded.') :
              h('table', {}, h('tbody', {}, events.map((e) => h('tr', { style: e.type === 'missed' ? 'color:var(--bad)' : '' },
                h('td', { class: 'small' }, whenExactly(e.at)),
                h('td', {}, EVENT_NAMES[e.type] || e.type),
                h('td', { class: 'small muted' }, e.alarm_id ? `alarm #${e.alarm_id}` : ''),
                h('td', { class: 'small muted' }, e.type === 'report' ? '' : Object.entries(e.detail || {}).map(([k, v]) => `${k}: ${typeof v === 'object' ? JSON.stringify(v) : v}`).join(', ')))))));
          }) }, 'Diary'),
          h('button', { class: r.resolved ? '' : 'primary', onclick: async () => {
            await attempt(async () => ok(await db.rpc('admin_resolve_alarm_report', { report_id: r.id, is_resolved: !r.resolved })), r.resolved ? 'Reopened' : 'Marked as dealt with');
            attempt(drawList); attempt(drawHealth);
          } }, r.resolved ? 'Reopen' : 'Dealt with')),
        details);
    }), reports.length === 0 && h('div', { class: 'card center muted' }, onlyOpen ? 'No reports waiting. ' : 'No reports yet.'));
  };

  fill(main,
    pageHead('Alarm reports', 'How alarms behaved on people\'s phones in the last 7 days, and the problems they reported.'),
    healthBox,
    h('div', { class: 'section' }, h('h2', {}, 'Reports'), chips, list));
  await drawHealth();
  await drawList();
}

// ----------------------------------------------------------------- accounts

async function pageUsers(main) {
  const body = h('tbody', {});
  const search = h('input', { type: 'search', placeholder: 'Search by email or name', style: 'max-width:420px' });
  let timer = null;

  const load = async () => {
    const users = ok(await db.rpc('admin_list_users', { search: search.value.trim(), max_rows: 200, skip: 0 }));
    fill(body, ...users.map((u) => {
      const mine = u.id === state.user.id;
      const role = h('select', { style: 'width:auto', onchange: async (e) => {
        const done = await attempt(async () => ok(await db.rpc('admin_set_role', { target: u.id, new_role: e.target.value })), 'Role changed');
        if (done === undefined) e.target.value = u.role; else u.role = e.target.value;
      } }, ['user', 'admin', 'owner'].map((r) => h('option', { value: r, selected: u.role === r }, r[0].toUpperCase() + r.slice(1))));
      const expiry = h('input', { type: 'date', style: 'width:auto', value: u.plan_expires_at ? u.plan_expires_at.slice(0, 10) : '', title: 'Premium ends on (empty = no end date)' });
      const plan = h('select', { style: 'width:auto' }, ['free', 'premium'].map((p) => h('option', { value: p, selected: u.plan === p }, p[0].toUpperCase() + p.slice(1))));
      const savePlan = async () => {
        expiry.style.display = plan.value === 'premium' ? '' : 'none';
        await attempt(async () => ok(await db.rpc('admin_set_plan', {
          target: u.id, new_plan: plan.value,
          expires: plan.value === 'premium' && expiry.value ? new Date(`${expiry.value}T23:59:59`).toISOString() : null,
        })), 'Plan changed');
      };
      plan.addEventListener('change', savePlan);
      expiry.addEventListener('change', savePlan);
      expiry.style.display = u.plan === 'premium' ? '' : 'none';

      return h('tr', {},
        h('td', {}, h('b', {}, u.email || '(no email)'), mine && h('span', { class: 'pill accent', style: 'margin-left:8px' }, 'You'),
          u.display_name && h('div', { class: 'muted small' }, u.display_name)),
        h('td', {}, role),
        h('td', {}, h('div', { class: 'row' }, plan, expiry)),
        h('td', { class: 'small' }, when(u.created_at)),
        h('td', { class: 'small' }, when(u.last_sign_in_at)),
        h('td', {}, u.answers), h('td', {}, u.ai_calls),
        h('td', {}, !mine && h('button', { class: 'icon-btn danger', title: 'Delete account', onclick: () => confirmDialog(`Delete ${u.email}?`, 'The account and everything that belongs to it (answers, sessions, backup, AI questions) is removed for good.', 'Delete account', async () => { await attempt(async () => ok(await db.rpc('admin_delete_user', { target: u.id })), 'Account deleted'); load(); }) }, icon('trash'))));
    }), users.length === 0 ? h('tr', {}, h('td', { colspan: 8, class: 'muted' }, 'No accounts match.')) : '');
  };
  search.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(() => attempt(load), 300); });

  fill(main, 
    pageHead('Accounts', 'Everyone who has signed up. Admins manage the question bank; owners can do everything on this site.'),
    h('div', { style: 'margin-bottom:12px' }, search),
    h('div', { class: 'card table-wrap', style: 'padding:6px' },
      h('table', {}, h('thead', {}, h('tr', {}, h('th', {}, 'Account'), h('th', {}, 'Role'), h('th', {}, 'Plan'), h('th', {}, 'Joined'), h('th', {}, 'Last sign-in'), h('th', {}, 'Answers'), h('th', {}, 'AI calls'), h('th', {}))), body)));
  await load();
}

// ----------------------------------------------------------------- settings

// Ready-made starting points for the "Add provider" form. "openai" is the
// request format most services speak, not only OpenAI itself.
const PROVIDER_PRESETS = [
  { label: 'Google Gemini', type: 'gemini', endpoint: '', modelHint: 'e.g. gemini-flash-latest', keyHint: 'AIza...' },
  { label: 'Groq', type: 'openai', endpoint: 'https://api.groq.com/openai/v1', modelHint: 'e.g. openai/gpt-oss-120b', keyHint: 'gsk_...' },
  { label: 'OpenAI (ChatGPT)', type: 'openai', endpoint: 'https://api.openai.com/v1', modelHint: 'e.g. gpt-4o-mini', keyHint: 'sk-...' },
  { label: 'OpenRouter', type: 'openai', endpoint: 'https://openrouter.ai/api/v1', modelHint: 'e.g. deepseek/deepseek-chat', keyHint: 'sk-or-v1-...' },
  { label: 'Anthropic (Claude)', type: 'anthropic', endpoint: '', modelHint: 'e.g. claude-haiku-4-5', keyHint: 'sk-ant-...' },
  { label: 'Other (OpenAI-compatible)', type: 'openai', endpoint: '', modelHint: 'The model name your service expects', keyHint: 'Your API key' },
];
const TYPE_DEFAULT_ENDPOINT = {
  openai: 'https://api.openai.com/v1',
  gemini: 'https://generativelanguage.googleapis.com/v1beta',
  anthropic: 'https://api.anthropic.com/v1',
};

/** Sends one tiny request straight from this browser to check a key works.
 *  Only possible while the key is typed in the form (saved keys cannot be
 *  read back). Returns a short description of the reply. */
async function testProvider({ type, key, endpoint, model }) {
  const base = (endpoint || TYPE_DEFAULT_ENDPOINT[type]).replace(/\/+$/, '');
  const prompt = 'Reply with the single word OK.';
  let url, headers, body, read;
  if (type === 'gemini') {
    url = `${base}/models/${encodeURIComponent(model)}:generateContent`;
    headers = { 'Content-Type': 'application/json', 'x-goog-api-key': key };
    body = { contents: [{ parts: [{ text: prompt }] }] };
    read = (d) => d.candidates[0].content.parts.map((p) => p.text || '').join('');
  } else if (type === 'anthropic') {
    url = `${base}/messages`;
    headers = { 'Content-Type': 'application/json', 'x-api-key': key, 'anthropic-version': '2023-06-01', 'anthropic-dangerous-direct-browser-access': 'true' };
    body = { model, max_tokens: 16, messages: [{ role: 'user', content: prompt }] };
    read = (d) => d.content.map((p) => p.text || '').join('');
  } else {
    url = `${base}/chat/completions`;
    headers = { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` };
    body = { model, messages: [{ role: 'user', content: prompt }], max_tokens: 16 };
    read = (d) => d.choices[0].message.content;
  }
  const response = await fetch(url, { method: 'POST', headers, body: JSON.stringify(body) });
  const text = await response.text();
  let data = null;
  try { data = JSON.parse(text); } catch (_) { /* not JSON */ }
  if (!response.ok) {
    const detail = data && data.error ? (data.error.message || JSON.stringify(data.error)) : text.slice(0, 200);
    throw new Error(`The provider answered ${response.status}: ${detail}`);
  }
  return String(read(data) || '').trim().slice(0, 60) || '(empty reply)';
}

function providerDialog(provider) {
  const isNew = !provider;
  const preset = h('select', {}, PROVIDER_PRESETS.map((p, i) => h('option', { value: i }, p.label)));
  const name = h('input', { type: 'text', value: provider ? provider.name : '', placeholder: 'e.g. Groq key 1' });
  const type = h('select', {},
    h('option', { value: 'openai' }, 'openai (OpenAI, Groq, OpenRouter and compatible)'),
    h('option', { value: 'gemini' }, 'gemini (Google)'),
    h('option', { value: 'anthropic' }, 'anthropic (Claude)'));
  type.value = provider ? provider.type : 'gemini';
  const key = h('input', { type: 'password', autocomplete: 'off', placeholder: isNew ? 'Paste the API key' : `Saved (ends in ${provider.key_ending}). Paste a new key to replace it.` });
  const endpoint = h('input', { type: 'url', value: provider ? provider.endpoint : '', placeholder: 'Leave empty for the usual address' });
  const model = h('input', { type: 'text', value: provider ? provider.model : '', placeholder: 'e.g. gemini-flash-latest' });
  const weight = h('input', { type: 'number', min: 1, max: 100, value: provider ? provider.weight : 1 });
  const enabled = h('input', { type: 'checkbox', checked: provider ? provider.enabled : true });
  const testResult = h('span', { class: 'small muted' });

  const applyPreset = () => {
    const p = PROVIDER_PRESETS[Number(preset.value)];
    type.value = p.type;
    endpoint.value = p.endpoint;
    model.placeholder = p.modelHint;
    key.placeholder = p.keyHint;
    if (!name.value.trim()) name.value = p.label;
  };
  preset.addEventListener('change', applyPreset);
  if (isNew) { name.value = ''; applyPreset(); name.value = ''; }

  dialog((close) => [
    h('h2', {}, isNew ? 'Add AI provider' : 'Edit AI provider'),
    isNew && field('Start from', preset, 'Fills in the type and address for a known service.'),
    field('Provider name', name, 'Only for you, to tell them apart (e.g. "Groq key 2").'),
    field('Type', type, 'The request format the service speaks.'),
    field('API key', key, 'Stored in the database where only the server can read it. It is never shown again.'),
    field('Endpoint URL (optional)', endpoint, 'Base address only: do not include /chat/completions at the end.'),
    field('Model', model, 'The exact model name to request from this provider.'),
    h('div', { class: 'row' },
      h('div', { style: 'width:140px' }, field('Weight', weight)),
      h('p', { class: 'muted small grow' }, 'Providers take turns. A weight of 2 gets twice as many calls as a weight of 1.')),
    h('label', { class: 'check' }, enabled, 'Switched on'),
    h('div', { class: 'row' },
      h('button', { onclick: async () => {
        if (!key.value.trim()) { toast(isNew ? 'Paste the key first' : 'Paste the key again to test it (a saved key cannot be read back)', true); return; }
        if (!model.value.trim()) { toast('Enter the model name first', true); return; }
        testResult.textContent = 'Testing...';
        testResult.style.color = '';
        try {
          const reply = await testProvider({ type: type.value, key: key.value.trim(), endpoint: endpoint.value.trim(), model: model.value.trim() });
          testResult.textContent = `Works. It replied: "${reply}"`;
          testResult.style.color = 'var(--ok)';
        } catch (error) {
          testResult.textContent = error.message === 'Failed to fetch'
            ? 'Could not reach the provider from this browser (wrong address, or it blocks browser requests).'
            : error.message;
          testResult.style.color = 'var(--bad)';
        }
      } }, icon('test'), 'Test'),
      h('div', { class: 'grow' }, testResult)),
    h('div', { class: 'row' },
      h('button', { class: 'right', onclick: close }, 'Cancel'),
      h('button', { class: 'primary', onclick: async () => {
        if (!name.value.trim()) { toast('Give the provider a name', true); return; }
        if (isNew && !key.value.trim()) { toast('Paste the API key', true); return; }
        if (!model.value.trim()) { toast('Enter the model name', true); return; }
        const saved = await attempt(async () => ok(await db.rpc('admin_save_ai_provider', {
          provider_id: provider ? provider.id : null,
          new_name: name.value, new_type: type.value, new_key: key.value,
          new_endpoint: endpoint.value, new_model: model.value,
          new_weight: Math.min(100, Math.max(1, Number(weight.value) || 1)),
          new_enabled: enabled.checked,
        })), 'Saved');
        if (saved !== undefined) { close(); render(); }
      } }, 'Save')),
  ]);
}

async function pageSettings(main, tab) {
  const current = tab === 'limits' ? 'limits' : 'providers';
  const tabs = h('div', { class: 'tabs' },
    h('a', { class: current === 'providers' ? 'on' : '', href: '#/settings/providers' }, icon('spark'), 'AI providers'),
    h('a', { class: current === 'limits' ? 'on' : '', href: '#/settings/limits' }, icon('gauge'), 'AI limits'));
  const body = h('div', {});
  fill(main, pageHead('Settings', 'Only owners see this page.'), tabs, body);
  if (current === 'limits') await settingsLimits(body); else await settingsProviders(body);
}

async function settingsProviders(body) {
  const providers = ok(await db.rpc('admin_list_ai_providers'));
  const active = providers.filter((p) => p.enabled);
  const totalWeight = active.reduce((n, p) => n + p.weight, 0) || 1;

  fill(body, 
    h('div', { class: 'row spread', style: 'margin-bottom:12px' },
      h('div', {}, h('h2', { style: 'margin:0' }, 'AI providers'),
        h('p', { class: 'muted small', style: 'margin:0' }, 'The server uses the switched-on providers in turn. If one fails, it moves to the next.')),
      h('button', { class: 'primary', onclick: () => providerDialog(null) }, icon('plus'), 'Add provider')),
    providers.length === 0 && h('div', { class: 'card center muted' }, 'No providers yet. Add one so the app\'s AI features can work.'),
    h('div', { class: 'list' }, providers.map((p) => h('div', { class: p.enabled ? 'card' : 'card gone' },
      h('div', { class: 'row' },
        h('div', { class: 'grow' },
          h('div', { class: 'row' }, h('h3', {}, p.name), h('span', { class: 'pill' }, p.type),
            p.enabled && h('span', { class: 'pill accent' }, `${Math.round(100 * p.weight / totalWeight)}% of calls`)),
          h('div', { class: 'muted small', style: 'margin-top:4px' },
            `Weight: ${p.weight}  ·  Model: ${p.model || '(none)'}  ·  Endpoint: ${p.endpoint || 'usual address'}  ·  Key ends in ${p.key_ending}`),
          h('div', { class: 'muted small' },
            `${p.uses} call${Number(p.uses) === 1 ? '' : 's'} served`, p.last_used_at ? `, last on ${when(p.last_used_at)}` : ''),
          p.last_error && h('div', { class: 'small', style: 'color:var(--bad);margin-top:4px' }, `Last problem (${when(p.last_error_at)}): ${p.last_error}`)),
        toggle(p.enabled, async (e) => {
          const done = await attempt(async () => ok(await db.rpc('admin_set_ai_provider_enabled', { provider_id: p.id, is_enabled: e.target.checked })), e.target.checked ? 'Switched on' : 'Switched off');
          if (done !== undefined) render();
        }, 'Switch this provider on or off'),
        h('button', { class: 'icon-btn', title: 'Edit', onclick: () => providerDialog(p) }, icon('edit')),
        h('button', { class: 'icon-btn danger', title: 'Delete', onclick: () => confirmDialog(`Delete "${p.name}"?`, 'Its key is removed for good.', 'Delete', async () => { await attempt(async () => ok(await db.rpc('admin_delete_ai_provider', { provider_id: p.id })), 'Provider deleted'); render(); }) }, icon('trash')))))));
}

async function settingsLimits(body) {
  const config = ok(await db.from('app_config').select('*').order('key'));
  const rows = config.map((row) => {
    const kind = typeof row.value;
    const save = async (value) => { await attempt(async () => ok(await db.from('app_config').update({ value }).eq('key', row.key).select()), 'Saved'); };
    const input = kind === 'boolean'
      ? toggle(row.value, (e) => save(e.target.checked))
      : h('input', { type: kind === 'number' ? 'number' : 'text', value: row.value, style: 'width:140px',
          onchange: (e) => save(kind === 'number' ? Number(e.target.value) : e.target.value.trim()) });
    return h('div', { class: 'card row' },
      h('div', { class: 'grow' }, h('b', {}, row.note || row.key), h('div', { class: 'muted small' }, row.key)), input);
  });
  fill(body, 
    h('h2', { style: 'margin:0' }, 'AI limits'),
    h('p', { class: 'muted small' }, 'How much AI each person may use, and a switch for all AI features.'),
    h('div', { class: 'list' }, rows));
}

start();
