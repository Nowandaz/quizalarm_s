// Stand-in for the Supabase client, used only by preview.html. It keeps a
// few made-up rows in memory and answers the same calls app.js makes, so the
// whole site can be looked at and clicked through without a server.
'use strict';
(() => {
  const now = Date.now();
  const days = (n) => new Date(now - n * 864e5).toISOString();
  const picture = 'data:image/svg+xml,' + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 120"><rect width="160" height="120" fill="#1d1d22"/>'
    + '<circle cx="62" cy="58" r="30" fill="#c96a8b"/><circle cx="100" cy="66" r="22" fill="#7d5aa6"/>'
    + '<circle cx="84" cy="44" r="9" fill="#f1d3dc"/></svg>');

  const tables = {
    profiles: [{ id: 'u1', display_name: 'Demo Owner', role: 'owner', plan: 'premium' }],
    units: [
      { id: 'pharmacology', name: 'Pharmacology', description: 'Drug classes, mechanisms and adverse effects.', sort_order: 1, premium: false, deleted_at: null },
      { id: 'pathology', name: 'Pathology', description: 'Spotter questions: name what the picture shows.', sort_order: 2, premium: true, deleted_at: null },
      { id: 'anatomy', name: 'Anatomy', description: '', sort_order: 3, premium: false, deleted_at: days(2) },
    ],
    topics: [
      { id: 'pharmacology-ans', unit_id: 'pharmacology', name: 'Autonomic nervous system', sort_order: 0, deleted_at: null },
      { id: 'pharmacology-antibiotics', unit_id: 'pharmacology', name: 'Antibiotics', sort_order: 1, deleted_at: null },
      { id: 'pharmacology-cvs', unit_id: 'pharmacology', name: 'Cardiovascular drugs', sort_order: 2, deleted_at: null },
      { id: 'pathology-spotters', unit_id: 'pathology', name: 'Spotters', sort_order: 0, deleted_at: null },
    ],
    questions: [],
    app_config: [
      { key: 'ai_daily_limit_free', value: 10, note: 'AI calls a free user may make each day' },
      { key: 'ai_daily_limit_premium', value: 200, note: 'AI calls a premium user may make each day' },
      { key: 'ai_enabled', value: true, note: 'Turn all AI features on or off' },
    ],
  };
  const q = (topic, n, extra) => tables.questions.push({
    id: `${topic}-${n}`, topic_id: topic, type: 'mcq', alt_answers: [], image_path: '', status: 'published',
    source: 'seed', deleted_at: null, created_at: days(30 - n), ...extra });
  q('pharmacology-ans', 1, { text: 'Which drug is a selective beta-1 blocker?', options: ['Propranolol', 'Atenolol', 'Carvedilol', 'Labetalol', 'Timolol'], answer: 'Atenolol', explanation: 'Atenolol blocks beta-1 receptors in the heart with little effect on beta-2 receptors in the airways at usual doses.' });
  q('pharmacology-ans', 2, { text: 'Which receptor does atropine block?', options: ['Nicotinic', 'Muscarinic', 'Alpha-1', 'Beta-2', 'Dopamine D2'], answer: 'Muscarinic', explanation: 'Atropine is a competitive antagonist at muscarinic acetylcholine receptors.' });
  q('pharmacology-ans', 3, { type: 'saq', options: [], text: 'Name the drug of choice for anaphylaxis.', answer: 'Adrenaline', alt_answers: ['Epinephrine'], explanation: 'Intramuscular adrenaline reverses airway swelling and low blood pressure.' });
  q('pharmacology-ans', 4, { status: 'draft', source: 'ai', text: 'Which drug is used to reverse neuromuscular blockade?', options: ['Neostigmine', 'Atropine', 'Pralidoxime', 'Physostigmine', 'Edrophonium'], answer: 'Neostigmine', explanation: '' });
  q('pharmacology-ans', 5, { deleted_at: days(1), text: 'An old question that was deleted.', options: ['A', 'B', 'C', 'D', 'E'], answer: 'A', explanation: 'Kept so it can be restored.' });
  q('pharmacology-antibiotics', 1, { text: 'Which antibiotic class inhibits DNA gyrase?', options: ['Macrolides', 'Fluoroquinolones', 'Penicillins', 'Aminoglycosides', 'Tetracyclines'], answer: 'Fluoroquinolones', explanation: 'Fluoroquinolones such as ciprofloxacin block DNA gyrase and topoisomerase IV.' });
  q('pharmacology-antibiotics', 2, { text: 'Which drug can cause red man syndrome?', options: ['Vancomycin', 'Gentamicin', 'Rifampicin', 'Linezolid', 'Clindamycin'], answer: 'Vancomycin', explanation: 'Fast infusion of vancomycin releases histamine, causing flushing.' });
  q('pharmacology-cvs', 1, { text: 'Which drug class ends in "-pril"?', options: ['ACE inhibitors', 'Beta blockers', 'Statins', 'Calcium channel blockers', 'Loop diuretics'], answer: 'ACE inhibitors', explanation: 'Enalapril, lisinopril and ramipril are ACE inhibitors.' });
  q('pathology-spotters', 1, { type: 'saq', options: [], image_path: picture, text: 'Name the cell shown in this picture.', answer: 'Reed-Sternberg cell', alt_answers: ['Reed Sternberg', 'RS cell'], explanation: 'The owl-eye double nucleus is typical of Hodgkin lymphoma.' });
  q('pathology-spotters', 2, { image_path: picture, text: 'What does this slide show?', options: ['Caseous necrosis', 'Fatty change', 'Amyloid', 'Granulation tissue', 'Fibrinoid necrosis'], answer: 'Caseous necrosis', explanation: 'Structureless pink material surrounded by granulomas, as in tuberculosis.' });

  const users = [
    { id: 'u1', email: 'owner@example.com', display_name: 'Demo Owner', role: 'owner', plan: 'premium', plan_expires_at: null, created_at: days(40), last_sign_in_at: days(0), answers: 312, ai_calls: 41 },
    { id: 'u2', email: 'amina@example.com', display_name: 'Amina', role: 'admin', plan: 'free', plan_expires_at: null, created_at: days(21), last_sign_in_at: days(1), answers: 120, ai_calls: 9 },
    { id: 'u3', email: 'brian@example.com', display_name: '', role: 'user', plan: 'premium', plan_expires_at: days(-30), created_at: days(9), last_sign_in_at: days(3), answers: 58, ai_calls: 77 },
    { id: 'u4', email: 'chao@example.com', display_name: 'Chao', role: 'user', plan: 'free', plan_expires_at: null, created_at: days(2), last_sign_in_at: null, answers: 0, ai_calls: 0 },
  ];
  let providers = [
    { id: 'p1', name: 'Gemini main', type: 'gemini', key_ending: 'x7Qa', endpoint: '', model: 'gemini-flash-latest', weight: 2, enabled: true, uses: 184, last_used_at: days(0), last_error: '', last_error_at: null, created_at: days(10) },
    { id: 'p2', name: 'Groq key 1', type: 'openai', key_ending: '9fK2', endpoint: 'https://api.groq.com/openai/v1', model: 'openai/gpt-oss-120b', weight: 1, enabled: true, uses: 92, last_used_at: days(0), last_error: 'The provider answered 429: rate limit reached', last_error_at: days(1), created_at: days(8) },
    { id: 'p3', name: 'ChatGPT', type: 'openai', key_ending: 'T3bl', endpoint: 'https://api.openai.com/v1', model: 'gpt-4o-mini', weight: 1, enabled: false, uses: 12, last_used_at: days(6), last_error: '', last_error_at: null, created_at: days(7) },
  ];

  // One query: collects filters, then resolves like a Supabase call.
  class Query {
    constructor(table) { this.rows = tables[table]; this.tests = []; this.action = null; }
    select() { return this; }
    order() { return this; }
    eq(k, v) { this.tests.push((r) => r[k] === v); return this; }
    in(k, list) { this.tests.push((r) => list.includes(r[k])); return this; }
    is(k, v) { this.tests.push((r) => (r[k] ?? null) === v); return this; }
    like(k, pattern) { const start = pattern.replace(/%$/, ''); this.tests.push((r) => String(r[k]).startsWith(start)); return this; }
    update(values) { this.action = (rows) => rows.forEach((r) => Object.assign(r, values)); return this; }
    insert(row) { this.rows.push({ deleted_at: null, created_at: new Date().toISOString(), ...row }); this.tests.push((r) => r.id === row.id); return this; }
    upsert(input) {
      for (const row of [].concat(input)) {
        const old = this.rows.find((r) => (r.id ?? r.key) === (row.id ?? row.key));
        if (old) Object.assign(old, row); else this.rows.push({ deleted_at: null, created_at: new Date().toISOString(), ...row });
      }
      return this;
    }
    then(resolve) {
      const rows = this.rows.filter((r) => this.tests.every((t) => t(r)));
      if (this.action) this.action(rows);
      resolve({ data: rows.map((r) => ({ ...r })), error: null });
    }
  }

  const rpcs = {
    owner_exists: () => true,
    admin_stats: () => {
      const live = tables.questions.filter((x) => !x.deleted_at);
      return {
        units: tables.units.filter((x) => !x.deleted_at).length, topics: tables.topics.filter((x) => !x.deleted_at).length,
        questions: live.length, with_pictures: live.filter((x) => x.image_path).length, drafts: live.filter((x) => x.status === 'draft').length,
        users: users.length, premium_users: users.filter((u) => u.plan === 'premium').length, active_users_7d: 3, answers_7d: 214, ai_calls_today: 17,
      };
    },
    admin_list_users: ({ search }) => users.filter((u) => !search || (u.email + u.display_name).toLowerCase().includes(search.toLowerCase())),
    admin_set_role: ({ target, new_role }) => { users.find((u) => u.id === target).role = new_role; },
    admin_set_plan: ({ target, new_plan, expires }) => { Object.assign(users.find((u) => u.id === target), { plan: new_plan, plan_expires_at: expires }); },
    admin_delete_user: ({ target }) => { users.splice(users.findIndex((u) => u.id === target), 1); },
    admin_list_ai_providers: () => providers.map((p) => ({ ...p })),
    admin_save_ai_provider: (a) => {
      let p = providers.find((x) => x.id === a.provider_id);
      if (!p) { p = { id: `p${Date.now()}`, uses: 0, last_used_at: null, last_error: '', last_error_at: null, created_at: new Date().toISOString(), key_ending: '' }; providers.push(p); }
      Object.assign(p, { name: a.new_name.trim(), type: a.new_type, endpoint: a.new_endpoint.trim(), model: a.new_model.trim(), weight: a.new_weight, enabled: a.new_enabled });
      if (a.new_key.trim()) p.key_ending = a.new_key.trim().slice(-4);
      return p.id;
    },
    admin_set_ai_provider_enabled: ({ provider_id, is_enabled }) => { providers.find((p) => p.id === provider_id).enabled = is_enabled; },
    admin_delete_ai_provider: ({ provider_id }) => { providers = providers.filter((p) => p.id !== provider_id); },
  };

  const client = {
    auth: {
      getSession: async () => ({ data: { session: { user: { id: 'u1', email: 'owner@example.com' } } } }),
      onAuthStateChange: () => {},
      signOut: async () => { alert('This is the preview: there is nothing to sign out of.'); },
    },
    from: (table) => new Query(table),
    rpc: async (name, args) => ({ data: rpcs[name](args || {}) ?? null, error: null }),
    storage: { from: () => ({ upload: async () => ({ data: null, error: { message: 'Pictures cannot be uploaded in the preview' } }) }) },
  };

  window.supabase = { createClient: () => client };
  window.BRAINWAKE_CONFIG = { appName: 'BrainWake', supabaseUrl: '', supabaseKey: '', imageBucket: '', demo: true };
})();
