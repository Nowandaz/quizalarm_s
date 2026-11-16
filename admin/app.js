// Admin website. Plain JavaScript, no build step: open index.html from any
// web server. It signs in through Supabase and everything it does is checked
// by the database rules, so this code holds no secret and grants no power.
//
// Sections: helpers, sign-in, shell, dashboard, question bank, users, settings.
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
  if (/^https?:/.test(path)) return path;
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
  return h('div', { class: 'field' }, h('label', {}, label), input, hint && h('div', { class: 'muted small' }, hint));
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
    app.replaceChildren(h('p', { class: 'center' }, `Could not reach the server: ${error.message}`));
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
  const submit = h('button', { class: 'primary', style: 'width:100%' });
  const toggle = h('a', {});
  const note = h('p', { class: 'muted small' });

  const refresh = () => {
    submit.textContent = creating ? 'Create account' : 'Sign in';
    toggle.textContent = creating ? 'I already have an account' : 'Create an account';
  };
  toggle.addEventListener('click', () => { creating = !creating; refresh(); });
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

  app.replaceChildren(h('div', { class: 'auth' },
    h('h1', {}, `${CONFIG.appName} admin`),
    h('p', { class: 'muted' }, 'Sign in to manage the question bank.'),
    h('div', { class: 'card' },
      field('Email', email),
      field('Password', password),
      submit,
      note,
      h('div', { class: 'row spread small', style: 'margin-top:10px' },
        toggle,
        h('a', { onclick: async () => {
          if (!email.value.trim()) { toast('Type your email first', true); return; }
          await attempt(async () => ok(await db.auth.resetPasswordForEmail(email.value.trim(), {
            redirectTo: location.origin + location.pathname,
          })), 'Password reset email sent');
        } }, 'Forgot password?')),
      h('div', { class: 'divider' }, 'or'),
      h('button', { style: 'width:100%', onclick: () => attempt(async () => ok(await db.auth.signInWithOAuth({
        provider: 'google',
        options: { redirectTo: location.origin + location.pathname },
      }))) }, 'Continue with Google'))));
}

function renderNewPassword() {
  const password = h('input', { type: 'password', autocomplete: 'new-password' });
  app.replaceChildren(h('div', { class: 'auth' },
    h('h1', {}, 'Choose a new password'),
    h('div', { class: 'card' },
      field('New password', password, 'At least 6 characters.'),
      h('button', { class: 'primary', style: 'width:100%', onclick: async () => {
        const done = await attempt(async () => ok(await db.auth.updateUser({ password: password.value })), 'Password changed');
        if (done) start();
      } }, 'Save password'))));
}

async function renderNotAdmin() {
  const box = h('div', { class: 'card stack' },
    h('p', {}, `Signed in as ${state.user.email}.`),
    h('p', { class: 'muted' }, 'This account is not an admin. Ask the owner to give it admin access.'));
  app.replaceChildren(h('div', { class: 'auth' }, h('h1', {}, `${CONFIG.appName} admin`), box,
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
  const link = (name, label) => h('a', { class: page === name ? 'nav on' : 'nav', href: `#/${name}` }, label);
  const main = h('div', { class: 'main' }, h('p', { class: 'muted' }, 'Loading...'));

  app.replaceChildren(h('div', { class: 'shell' },
    h('div', { class: 'side' },
      h('div', { class: 'brand' }, CONFIG.appName),
      link('dashboard', 'Dashboard'),
      link('bank', 'Question bank'),
      isOwner() && link('users', 'Accounts'),
      isOwner() && link('settings', 'Settings'),
      h('div', { class: 'who' },
        h('div', {}, state.user.email),
        h('div', { class: 'muted' }, isOwner() ? 'Owner' : 'Admin'),
        h('a', { onclick: () => db.auth.signOut() }, 'Sign out'))),
    main));

  const pages = {
    dashboard: () => pageDashboard(main),
    bank: () => (b ? pageTopic(main, a, b) : a ? pageUnit(main, a) : pageBank(main)),
    users: () => (isOwner() ? pageUsers(main) : pageDashboard(main)),
    settings: () => (isOwner() ? pageSettings(main) : pageDashboard(main)),
  };
  attempt(pages[page] || pages.dashboard);
}

// ---------------------------------------------------------------- dashboard

async function pageDashboard(main) {
  const stats = ok(await db.rpc('admin_stats'));
  const card = (value, label) => h('div', { class: 'card stat' }, h('b', {}, value ?? 0), h('span', {}, label));
  main.replaceChildren(
    h('h1', {}, 'Dashboard'),
    h('p', { class: 'muted' }, 'What is in the bank and how it is being used.'),
    h('h2', { style: 'margin-top:18px' }, 'Question bank'),
    h('div', { class: 'grid' },
      card(stats.units, 'Units'), card(stats.topics, 'Topics'),
      card(stats.questions, 'Questions'), card(stats.with_pictures, 'With a picture'),
      card(stats.drafts, 'Drafts (hidden from the app)')),
    h('h2', { style: 'margin-top:22px' }, 'People'),
    h('div', { class: 'grid' },
      card(stats.users, 'Accounts'), card(stats.premium_users, 'Premium'),
      card(stats.active_users_7d, 'Active in the last 7 days'),
      card(stats.answers_7d, 'Answers in the last 7 days'),
      card(stats.ai_calls_today, 'AI calls today')));
}

// ------------------------------------------------------------ question bank

async function pageBank(main) {
  const units = ok(await db.from('units').select('*').order('sort_order').order('name'));
  const topics = ok(await db.from('topics').select('id, unit_id, deleted_at'));
  const questions = ok(await db.from('questions').select('id, topic_id, deleted_at'));
  const liveTopics = topics.filter((t) => !t.deleted_at);
  const count = (unitId) => {
    const ids = new Set(liveTopics.filter((t) => t.unit_id === unitId).map((t) => t.id));
    return [ids.size, questions.filter((q) => !q.deleted_at && ids.has(q.topic_id)).length];
  };

  main.replaceChildren(
    h('div', { class: 'row spread' },
      h('div', {}, h('h1', {}, 'Question bank'), h('p', { class: 'muted' }, 'Units, their topics and questions. Changes reach the app the next time it syncs.')),
      h('div', { class: 'row' },
        h('button', { onclick: () => importDialog() }, 'Import a file'),
        h('button', { class: 'primary', onclick: () => unitDialog(null, units.length) }, 'Add unit'))),
    h('div', { class: 'card table-wrap', style: 'margin-top:14px;padding:6px' },
      h('table', {},
        h('thead', {}, h('tr', {}, h('th', {}, 'Unit'), h('th', {}, 'Topics'), h('th', {}, 'Questions'), h('th', {}, 'Access'), h('th', {}, 'Order'), h('th', {}))),
        h('tbody', {}, units.map((u) => {
          const [nTopics, nQuestions] = count(u.id);
          return h('tr', { class: u.deleted_at ? 'click gone' : 'click', onclick: () => { location.hash = `#/bank/${encodeURIComponent(u.id)}`; } },
            h('td', {}, h('b', {}, u.name), u.deleted_at && h('span', { class: 'pill bad', style: 'margin-left:8px' }, 'Deleted'),
              u.description && h('div', { class: 'muted small' }, u.description)),
            h('td', {}, nTopics), h('td', {}, nQuestions),
            h('td', {}, u.premium ? h('span', { class: 'pill accent' }, 'Premium') : h('span', { class: 'pill' }, 'Free')),
            h('td', {}, u.sort_order),
            h('td', {}, h('button', { class: 'small', onclick: (e) => { e.stopPropagation(); unitDialog(u); } }, 'Edit')));
        }),
        units.length === 0 && h('tr', {}, h('td', { colspan: 6, class: 'muted' }, 'No units yet. Add one, or import a bank file.'))))));
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
  if (!unit) { main.replaceChildren(h('p', {}, 'That unit does not exist.')); return; }
  const topics = ok(await db.from('topics').select('*').eq('unit_id', unitId).order('sort_order').order('name'));
  const questions = ok(await db.from('questions').select('id, topic_id, status, deleted_at').in('topic_id', topics.map((t) => t.id).concat('-')));
  const of = (topicId) => questions.filter((q) => q.topic_id === topicId && !q.deleted_at);

  main.replaceChildren(
    h('div', { class: 'crumbs' }, h('a', { href: '#/bank' }, 'Question bank'), ' / ', unit.name),
    h('div', { class: 'row spread' },
      h('div', {}, h('h1', {}, unit.name, unit.premium && h('span', { class: 'pill accent', style: 'margin-left:10px;vertical-align:middle' }, 'Premium')),
        h('p', { class: 'muted' }, unit.description || 'No description.')),
      h('div', { class: 'row' },
        h('button', { onclick: () => exportUnit(unit) }, 'Export'),
        h('button', { onclick: () => unitDialog(unit) }, 'Edit unit'),
        h('button', { class: 'primary', onclick: () => topicDialog(unit, null, topics.length) }, 'Add topic'))),
    h('div', { class: 'card table-wrap', style: 'margin-top:14px;padding:6px' },
      h('table', {},
        h('thead', {}, h('tr', {}, h('th', {}, 'Topic'), h('th', {}, 'Questions'), h('th', {}, 'Drafts'), h('th', {}, 'Order'), h('th', {}))),
        h('tbody', {}, topics.map((t) => h('tr', { class: t.deleted_at ? 'click gone' : 'click', onclick: () => { location.hash = `#/bank/${encodeURIComponent(unit.id)}/${encodeURIComponent(t.id)}`; } },
          h('td', {}, h('b', {}, t.name), t.deleted_at && h('span', { class: 'pill bad', style: 'margin-left:8px' }, 'Deleted')),
          h('td', {}, of(t.id).length),
          h('td', {}, of(t.id).filter((q) => q.status === 'draft').length),
          h('td', {}, t.sort_order),
          h('td', {}, h('button', { class: 'small', onclick: (e) => { e.stopPropagation(); topicDialog(unit, t); } }, 'Edit')))),
        topics.length === 0 && h('tr', {}, h('td', { colspan: 5, class: 'muted' }, 'No topics yet.'))))));
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
  if (!unit || !topic) { main.replaceChildren(h('p', {}, 'That topic does not exist.')); return; }
  const questions = ok(await db.from('questions').select('*').eq('topic_id', topicId).order('created_at'));

  let filter = 'live';
  let search = '';
  const body = h('tbody', {});
  const counter = h('span', { class: 'muted small' });

  const draw = () => {
    const q = search.trim().toLowerCase();
    const rows = questions.filter((x) => {
      if (filter === 'live' && x.deleted_at) return false;
      if (filter === 'draft' && (x.deleted_at || x.status !== 'draft')) return false;
      if (filter === 'picture' && (x.deleted_at || !x.image_path)) return false;
      if (filter === 'deleted' && !x.deleted_at) return false;
      return !q || x.text.toLowerCase().includes(q) || x.answer.toLowerCase().includes(q);
    });
    counter.textContent = `${rows.length} shown`;
    body.replaceChildren(...rows.map((x) => h('tr', { class: x.deleted_at ? 'click gone' : 'click', onclick: () => questionDialog(topic, x) },
      h('td', {}, h('span', { class: 'pill' }, x.type === 'mcq' ? 'Choice' : 'Typed')),
      h('td', {}, x.text, h('div', { class: 'muted small' }, `Answer: ${x.answer}`)),
      h('td', {}, x.image_path ? h('span', { class: 'pill accent' }, 'Picture') : ''),
      h('td', {}, x.deleted_at ? h('span', { class: 'pill bad' }, 'Deleted')
        : x.status === 'draft' ? h('span', { class: 'pill' }, 'Draft') : h('span', { class: 'pill ok' }, 'Published')))),
    rows.length === 0 ? h('tr', {}, h('td', { colspan: 4, class: 'muted' }, 'No questions match.')) : '');
  };

  const filterSelect = h('select', { style: 'width:auto', onchange: (e) => { filter = e.target.value; draw(); } },
    h('option', { value: 'live' }, 'All current'), h('option', { value: 'draft' }, 'Drafts'),
    h('option', { value: 'picture' }, 'With a picture'), h('option', { value: 'deleted' }, 'Deleted'));

  main.replaceChildren(
    h('div', { class: 'crumbs' }, h('a', { href: '#/bank' }, 'Question bank'), ' / ',
      h('a', { href: `#/bank/${encodeURIComponent(unit.id)}` }, unit.name), ' / ', topic.name),
    h('div', { class: 'row spread' },
      h('h1', {}, topic.name),
      h('button', { class: 'primary', onclick: () => questionDialog(topic, null) }, 'Add question')),
    h('div', { class: 'row', style: 'margin:12px 0' },
      h('input', { type: 'search', class: 'grow', placeholder: 'Search questions and answers', oninput: (e) => { search = e.target.value; draw(); } }),
      filterSelect, counter),
    h('div', { class: 'card table-wrap', style: 'padding:6px' },
      h('table', {}, h('thead', {}, h('tr', {}, h('th', {}, 'Type'), h('th', {}, 'Question'), h('th', {}), h('th', {}, 'Status'))), body)));
  draw();
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
  const optionInputs = startOptions.map((o) => h('input', { type: 'text', value: o, placeholder: 'Option' }));
  const radios = startOptions.map((o, i) => h('input', { type: 'radio', name: 'correct', title: 'Correct answer', checked: q.type === 'mcq' ? o === q.answer && o !== '' : i === 0 }));
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
  const drawPreview = () => preview.replaceChildren(imagePath
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
    field('Type', type),
    field('Question', text),
    mcqBox, saqBox,
    field('Explanation', explanation, 'Shown after answering, also offline. Say why the answer is right.'),
    h('div', { class: 'field' }, h('label', {}, 'Picture (for spotter questions)'), preview, h('div', { style: 'margin-top:8px' }, file)),
    field('Status', status),
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
                image_path: x.image ? `seed/${String(x.image).split('/').pop()}` : '',
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

// -------------------------------------------------------------------- users

async function pageUsers(main) {
  const body = h('tbody', {});
  const search = h('input', { type: 'search', placeholder: 'Search by email or name' });
  let timer = null;

  const load = async () => {
    const users = ok(await db.rpc('admin_list_users', { search: search.value.trim(), max_rows: 200, skip: 0 }));
    body.replaceChildren(...users.map((u) => {
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
        h('td', {}, !mine && h('button', { class: 'small danger', onclick: () => confirmDialog(`Delete ${u.email}?`, 'The account and everything that belongs to it (answers, sessions, backup, AI questions) is removed for good.', 'Delete account', async () => { await attempt(async () => ok(await db.rpc('admin_delete_user', { target: u.id })), 'Account deleted'); load(); }) }, 'Delete')));
    }), users.length === 0 ? h('tr', {}, h('td', { colspan: 8, class: 'muted' }, 'No accounts match.')) : '');
  };
  search.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(() => attempt(load), 300); });

  main.replaceChildren(
    h('h1', {}, 'Accounts'),
    h('p', { class: 'muted' }, 'Everyone who has signed up. Admins manage the question bank; owners can do everything on this site.'),
    h('div', { style: 'margin:12px 0' }, search),
    h('div', { class: 'card table-wrap', style: 'padding:6px' },
      h('table', {}, h('thead', {}, h('tr', {}, h('th', {}, 'Account'), h('th', {}, 'Role'), h('th', {}, 'Plan'), h('th', {}, 'Joined'), h('th', {}, 'Last sign-in'), h('th', {}, 'Answers'), h('th', {}, 'AI calls'), h('th', {}))), body)));
  await load();
}

// ----------------------------------------------------------------- settings

const SECRETS = [
  { name: 'gemini_api_key', label: 'Gemini API key', hint: 'Used by the server for every AI feature. Users never see it.' },
];

async function pageSettings(main) {
  const config = ok(await db.from('app_config').select('*').order('key'));
  const secrets = ok(await db.rpc('admin_secret_status'));

  const configRows = config.map((row) => {
    const kind = typeof row.value;
    const input = kind === 'boolean'
      ? h('input', { type: 'checkbox', checked: row.value })
      : h('input', { type: kind === 'number' ? 'number' : 'text', value: row.value, style: 'max-width:260px' });
    const save = async () => {
      const value = kind === 'boolean' ? input.checked : kind === 'number' ? Number(input.value) : input.value.trim();
      await attempt(async () => ok(await db.from('app_config').update({ value }).eq('key', row.key).select()), 'Saved');
    };
    input.addEventListener('change', save);
    return h('tr', {}, h('td', {}, h('b', {}, row.note || row.key), h('div', { class: 'muted small' }, row.key)), h('td', {}, input));
  });

  const secretRows = SECRETS.map((secret) => {
    const current = secrets.find((s) => s.name === secret.name);
    const input = h('input', { type: 'password', placeholder: current ? 'Paste a new key to replace it' : 'Paste the key', autocomplete: 'off' });
    return h('div', { class: 'field' },
      h('label', {}, secret.label),
      h('p', { class: 'muted small' }, secret.hint, ' ',
        current ? h('span', { class: 'pill ok' }, `Set on ${when(current.updated_at)}, ends in ${current.ending}`) : h('span', { class: 'pill bad' }, 'Not set')),
      h('div', { class: 'row' }, h('div', { class: 'grow' }, input),
        h('button', { class: 'primary', onclick: async () => {
          if (!input.value.trim()) { toast('Paste the key first', true); return; }
          const done = await attempt(async () => ok(await db.rpc('admin_set_secret', { secret_name: secret.name, secret_value: input.value })), 'Key saved');
          if (done !== undefined) render();
        } }, 'Save'),
        current && h('button', { class: 'danger', onclick: () => confirmDialog(`Remove the ${secret.label}?`, 'AI features stop working until a new key is saved.', 'Remove', async () => { await attempt(async () => ok(await db.rpc('admin_set_secret', { secret_name: secret.name, secret_value: '' })), 'Key removed'); render(); }) }, 'Remove')));
  });

  main.replaceChildren(
    h('h1', {}, 'Settings'),
    h('p', { class: 'muted' }, 'Only owners see this page.'),
    h('h2', { style: 'margin-top:18px' }, 'AI'),
    h('div', { class: 'card table-wrap', style: 'padding:6px' }, h('table', {}, h('tbody', {}, configRows))),
    h('h2', { style: 'margin-top:22px' }, 'Keys'),
    h('div', { class: 'card' },
      h('p', { class: 'muted small' }, 'A saved key can be replaced or removed but never read back, not even here. Only its last four characters are shown.'),
      secretRows));
}

start();
