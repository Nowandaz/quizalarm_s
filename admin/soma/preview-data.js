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
      { id: 'pharmacology-ans', section_id: 'pharmacology-sec-ans', unit_id: 'pharmacology', name: 'Autonomic nervous system', access: 'free', sort_order: 0, deleted_at: null },
      { id: 'pharmacology-antibiotics', section_id: 'pharmacology-sec-antimicrobials', unit_id: 'pharmacology', name: 'Antibiotics', access: 'paid', sort_order: 1, deleted_at: null },
      { id: 'pharmacology-cvs', section_id: 'pharmacology-sec-cvs', unit_id: 'pharmacology', name: 'Cardiovascular drugs', access: 'guest', sort_order: 2, deleted_at: null },
      { id: 'pathology-spotters', section_id: 'pathology-sec-blood-film', unit_id: 'pathology', name: 'Spotters', access: 'paid', sort_order: 0, deleted_at: null },
    ],
    questions: [],
    email_campaigns: [{ id: 'e1', created_at: days(1), subject: "Brain O' Clock 1.0.1 is out", body: 'Hello,\n\nA new version is ready, with Pharmacology questions and long answer practice.', audience: 'older', app_version: '', total: 23, sent: 22, failed: 1, status: 'done', error: '', button_text: 'Get the update', button_url: 'https://brainoclock.onrender.com/#download' }],
    announcements: [{ id: 2, title: 'Pharmacology topics uploaded', body: 'Autonomic nervous system and Autacoids now have questions. Open Banks to practise.', audience: 'all', link: '', published_at: days(0.2), expires_at: null }, { id: 1, title: 'Pro is 20% off this week', body: 'Use the code EXAMS when you upgrade.', audience: 'free', link: '', published_at: days(9), expires_at: days(2) }],
    sections: [
      { id: 'pharmacology-sec-ans', unit_id: 'pharmacology', parent_id: null, kind: 'section', name: 'Autonomic nervous system', description: '', sort_order: 0, deleted_at: null },
      { id: 'pharmacology-sec-antimicrobials', unit_id: 'pharmacology', parent_id: null, kind: 'section', name: 'Antimicrobials', description: '', sort_order: 1, deleted_at: null },
      { id: 'pharmacology-sec-cvs', unit_id: 'pharmacology', parent_id: null, kind: 'section', name: 'Cardiovascular system', description: '', sort_order: 2, deleted_at: null },
      { id: 'pathology-sub-haematology', unit_id: 'pathology', parent_id: null, kind: 'subunit', name: 'Haematology', description: '', sort_order: 0, deleted_at: null },
      { id: 'pathology-sub-immunology', unit_id: 'pathology', parent_id: null, kind: 'subunit', name: 'Immunology', description: '', sort_order: 1, deleted_at: null },
      { id: 'pathology-sec-blood-film', unit_id: 'pathology', parent_id: 'pathology-sub-haematology', kind: 'section', name: 'Blood film', description: '', sort_order: 0, deleted_at: null },
    ],
    app_releases: [{ id: 2, version: '1.0.1', url: 'https://brainoclock.onrender.com/download/brain-o-clock-1.0.1.apk', size_mb: 24.6, notes: 'Alarms that nobody answers now stop after ten minutes. Faster sign-in with Google.', published_at: days(1) }, { id: 1, version: '1.0.0', url: 'https://brainoclock.onrender.com/download/brain-o-clock-1.0.0.apk', size_mb: 24.1, notes: 'First version.', published_at: days(12) }],
    tiers: [
      { id: 'pro', name: 'Pro', description: 'The whole question bank, the AI and your own alarm volume.', features: ['Every topic in the question bank', 'AI tutor and new AI questions: 100 a day', 'Trends and figures for every topic', 'Choose and lock each alarm\'s volume'], price_month: 100, price_year: null, ai_daily_limit: 100, premium_units: true, sort_order: 1, active: true },
      { id: 'ultra', name: 'Ultra', description: 'Everything in Pro, far more AI and faster support.', features: ['Everything in Pro', 'AI tutor and new AI questions: 500 a day', 'Faster replies from the support team'], price_month: 150, price_year: null, ai_daily_limit: 500, premium_units: true, sort_order: 2, active: true },
    ],
    promo_codes: [
      { code: 'HALF', percent_off: 50, tier: null, max_uses: 20, used: 1, expires_at: null, active: true, note: 'Launch week', created_at: days(3) },
      { code: 'GIFT', percent_off: 100, tier: 'ultra', max_uses: 5, used: 1, expires_at: days(-30), active: true, note: 'Class reps', created_at: days(2) },
    ],
    app_config: [
      { key: 'ai_daily_limit_free', value: 10, note: 'AI calls a free user may make each day' },
      { key: 'ai_daily_limit_premium', value: 200, note: 'AI calls a premium user may make each day' },
      { key: 'ai_enabled', value: true, note: 'Turn all AI features on or off' },
      { key: 'payments_enabled', value: true, note: 'Let people buy premium in the app' },
      { key: 'premium_currency', value: 'KES', note: 'Currency of the prices (as set up on Paystack): KES, NGN, GHS, ZAR or USD' },
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
    { id: 'u1', tier: null, email: 'owner@example.com', display_name: 'Demo Owner', role: 'owner', plan: 'premium', plan_expires_at: null, created_at: days(40), last_sign_in_at: days(0), answers: 312, ai_calls: 41 },
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
    delete() { this.action = (rows) => rows.forEach((r) => this.rows.splice(this.rows.indexOf(r), 1)); return this; }
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

  const ago = (minutes) => new Date(now - minutes * 6e4).toISOString();
  const alarmReports = [
    { id: 1, at: ago(95), user_id: 'u3', email: 'brian@example.com', alarm_id: 482913, device: 'Tecno Camon 30 (Android 14)', app_version: '1.0.0+1', resolved: false,
      detail: { rang: false, problem: 'never_rang', note: 'Woke up by myself at 8, the 6:30 alarm never came.',
        diagnostics: { app_version: '1.0.0+1', scheduled: ago(185), last_actual_ring: ago(1625), reported_at: ago(95),
          device: { manufacturer: 'Tecno', model: 'Camon 30', android: '14', sdk: 34 },
          alarm: { id: 482913, time: '06:30', days: [1, 2, 3, 4, 5], enabled: true, snooze_minutes: 5, custom_ringtone: false, registered_with_phone: { tue: ago(-1255), wed: ago(-2695) } },
          snoozed_recently: false, edited_recently: true, switched_recently: false, alarm_service_ringing_now: false,
          permissions: { battery_unrestricted: false, notifications: true, exact_alarms: true, full_screen: true, over_other_apps: false },
          force_stopped: true, app_exits: [{ reason: 10, at: now - 9 * 36e5, description: 'stop com.example.quiz_alarm due to from pid 2231' }] } } },
    { id: 2, at: ago(600), user_id: 'u2', email: 'amina@example.com', alarm_id: 771204, device: 'Samsung SM-A155F (Android 15)', app_version: '1.0.0+1', resolved: false,
      detail: { rang: false, problem: 'no_sound', note: '', diagnostics: { app_version: '1.0.0+1', scheduled: ago(640), last_actual_ring: ago(640), reported_at: ago(600),
        device: { manufacturer: 'Samsung', model: 'SM-A155F', android: '15', sdk: 35 }, alarm: { id: 771204, time: '05:00', days: [], enabled: false, snooze_minutes: 10, custom_ringtone: true, registered_with_phone: {} },
        snoozed_recently: true, edited_recently: false, switched_recently: false, alarm_service_ringing_now: false,
        permissions: { battery_unrestricted: true, notifications: true, exact_alarms: true, full_screen: true, over_other_apps: true }, force_stopped: false, app_exits: [] } } },
    { id: 3, at: ago(2000), user_id: 'u4', email: 'chao@example.com', alarm_id: 120044, device: 'Xiaomi Redmi Note 13 (Android 14)', app_version: '1.0.0+1', resolved: true,
      detail: { rang: true, scheduled: ago(2060), note: 'The app thought this ring was missed; the user says it rang.' } },
  ];
  const diary = [
    { id: 9, at: ago(95), alarm_id: 482913, type: 'report', detail: {} },
    { id: 8, at: ago(100), alarm_id: 482913, type: 'missed', detail: { scheduled: ago(185), noticed_after_minutes: 85 } },
    { id: 7, at: ago(700), alarm_id: 482913, type: 'edited', detail: { time: '06:30', streak: 5 } },
    { id: 6, at: ago(705), alarm_id: 482913, type: 'scheduled', detail: { for: ago(185) } },
    { id: 5, at: ago(1620), alarm_id: 482913, type: 'dismissed', detail: {} },
    { id: 4, at: ago(1625), alarm_id: 482913, type: 'rang', detail: { late_seconds: 3 } },
  ];

  const payRows = [
    { id: 5, created_at: ago(90), paid_at: ago(89), email: 'dan@example.com', tier: 'ultra', tier_name: 'Ultra', plan: 'month', days: 30, amount: 0, full_amount: 80000, code: 'GIFT', currency: 'KES', status: 'paid', channel: '', note: '', reference: 'bw_77aa01c3e9' },
    { id: 4, created_at: ago(200), paid_at: ago(198), email: 'brian@example.com', tier: 'pro', tier_name: 'Pro', plan: 'year', days: 365, amount: 250000, full_amount: 250000, code: null, currency: 'KES', status: 'paid', channel: 'mobile_money', note: '', reference: 'bw_4f1c9a0e7d' },
    { id: 3, created_at: ago(900), paid_at: ago(899), email: 'eve@example.com', tier: 'ultra', tier_name: 'Ultra', plan: 'month', days: 30, amount: 40000, full_amount: 80000, code: 'HALF', currency: 'KES', status: 'paid', channel: 'card', note: '', reference: 'bw_19c0b7d2a4' },
    { id: 2, created_at: ago(1500), paid_at: null, email: 'chao@example.com', tier: 'pro', tier_name: 'Pro', plan: 'month', days: 30, amount: 30000, full_amount: 30000, code: null, currency: 'KES', status: 'pending', channel: '', note: '', reference: 'bw_a81b33c0f2' },
    { id: 1, created_at: ago(4000), paid_at: ago(3998), email: 'amina@example.com', tier: 'pro', tier_name: 'Pro', plan: 'month', days: 30, amount: 30000, full_amount: 30000, code: null, currency: 'KES', status: 'paid', channel: 'mobile_money', note: '', reference: 'bw_0c77de19b5' },
  ];

  const flags = [
    { id: 'f1', created_at: days(0.2), status: 'open', reason: 'wrong_answer', note: 'Atenolol is beta-1 selective, so B should be accepted too.', email: 'amina@example.com', question_id: 'q-cvs-3', question_text: 'Which of these is a non-selective beta blocker?', in_bank: true, topic_id: 'pharmacology-cvs', topic: 'Cardiovascular drugs', unit_id: 'pharmacology', unit: 'Pharmacology', current_text: 'Which of these is a non-selective beta blocker?', current_answer: 'Propranolol', others: 2 },
    { id: 'f2', created_at: days(1), status: 'open', reason: 'typo', note: '', email: 'brian@example.com', question_id: 'q-ans-7', question_text: 'Wich receptor does atropine block?', in_bank: true, topic_id: 'pharmacology-ans', topic: 'Autonomic nervous system', unit_id: 'pharmacology', unit: 'Pharmacology', current_text: 'Which receptor does atropine block?', current_answer: 'Muscarinic', others: 0 },
    { id: 'f3', created_at: days(3), status: 'resolved', reason: 'picture', note: 'The picture does not load.', email: 'carol@example.com', question_id: 'q-spot-2', question_text: 'Name the cell shown.', in_bank: true, topic_id: 'pathology-spotters', topic: 'Spotters', unit_id: 'pathology', unit: 'Pathology', current_text: 'Name the cell shown.', current_answer: 'Reed-Sternberg cell', others: 0 },
  ];

  const rpcs = {
    admin_email_versions: () => [{ version: '1.0.2', accounts: 14 }, { version: '1.0.1', accounts: 9 }, { version: '1.0.0', accounts: 23 }],
    admin_email_count: (a) => ({ older: 32, version: 23, all: 61, free: 44, paid: 17, waitlist: 12 }[a.audience] || 0),
    admin_devices: () => ({
      by_account: [{ user_id: 'u1', device: 'Samsung SM-A155F (Android 15)', version: '1.1.0+3', platform: 'android', level: 'pro', first_seen: days(20), last_seen: days(0.1) },
        { user_id: 'u1', device: 'Tecno Camon 30 (Android 14)', version: '1.0.0+1', platform: 'android', level: 'pro', first_seen: days(60), last_seen: days(9) }],
      models: [{ device: 'Tecno Camon 30 (Android 14)', phones: 41, without_account: 19, alarms_missed: 61, last_seen: days(0.1) }, { device: 'Samsung SM-A155F (Android 15)', phones: 33, without_account: 12, alarms_missed: 8, last_seen: days(0.2) }, { device: 'Xiaomi Redmi Note 13 (Android 14)', phones: 27, without_account: 14, alarms_missed: 44, last_seen: days(0.3) }, { device: 'Not reported (older app version)', phones: 32, without_account: 20, alarms_missed: 0, last_seen: days(2) }],
    }),
    admin_usage_stats: ({ days: n }) => {
      const wave = (i, base, swing) => Math.max(0, Math.round(base + swing * Math.sin(i / 2.3) + (i % 7 === 0 ? swing : 0)));
      const by_day = Array.from({ length: n + 1 }, (_, i) => ({ day: days(n - i).slice(0, 10), answers: wave(i, 260, 90), alarms_answered: wave(i, 58, 14), alarms_missed: wave(i, 5, 3), new_accounts: wave(i, 3, 2), new_phones: wave(i, 6, 3) }));
      return { days: n,
        phones: { total: 214, active: 163, active_7d: 121, new: 58, by_level: { guest: 71, free: 64, pro: 22, ultra: 6 }, by_version: [{ version: '1.1.0+3', phones: 131 }, { version: '1.0.0+1', phones: 32 }], sharing: 118, answered: 48210, correct: 33120, alarms_ok: 3890, alarms_missed: 312, alarms_set: 402 },
        accounts: { total: 139, new: 41, free: 104, pro: 27, ultra: 6, by_hand: 2 },
        questions: { in_bank: 412, answered_all_time: 31877, answered: by_day.reduce((t, d) => t + d.answers, 0), correct: Math.round(by_day.reduce((t, d) => t + d.answers, 0) * 0.68), learners: 88, in_alarms: Math.round(by_day.reduce((t, d) => t + d.answers, 0) * 0.41),
          by_topic: [{ topic: 'Pharmacology / Cardiovascular drugs', answered: 1820, correct: 1201, learners: 61 }, { topic: 'Pharmacology / Autonomic nervous system', answered: 1340, correct: 991, learners: 48 }, { topic: 'Pathology / Spotters', answered: 720, correct: 402, learners: 19 }, { topic: "People's own questions", answered: 310, correct: 240, learners: 12 }],
          hardest: [{ id: 'q1', text: 'Which of these is a non-selective beta blocker?', topic: 'Cardiovascular drugs', topic_id: 'pharmacology-cvs', unit_id: 'pharmacology', answered: 64, correct: 14, rate: 22 }, { id: 'q2', text: 'Name the cell shown.', topic: 'Spotters', topic_id: 'pathology-spotters', unit_id: 'pathology', answered: 31, correct: 10, rate: 32 }] },
        alarms: { rang: by_day.reduce((t, d) => t + d.alarms_answered + d.alarms_missed, 0), answered: by_day.reduce((t, d) => t + d.alarms_answered, 0), snoozed: 211, never_rang: 9, timed_out: by_day.reduce((t, d) => t + d.alarms_missed, 0) - 9, people: 74 },
        by_day };
    },
    admin_list_flags: ({ only_open }) => flags.filter((f) => !only_open || f.status === 'open').map((f) => ({ ...f })),
    admin_resolve_flag: ({ flag, resolved }) => { flags.find((f) => f.id === flag).status = resolved ? 'resolved' : 'open'; return 1; },
    admin_list_payments: () => payRows,
    admin_payment_totals: () => ({ paid: 4, pending: 1, failed: 0, buyers: 4, premium_users: 5, expiring_soon: 1,
      income: [{ currency: 'KES', amount: 320000, payments: 3 }],
      by_tier: [{ tier: 'Pro', period: 'year', currency: 'KES', payments: 1, amount: 250000 }, { tier: 'Ultra', period: 'month', currency: 'KES', payments: 2, amount: 40000 }, { tier: 'Pro', period: 'month', currency: 'KES', payments: 1, amount: 30000 }],
      by_channel: [{ channel: 'mobile_money', payments: 2 }, { channel: 'card', payments: 1 }, { channel: 'code (free)', payments: 1 }],
      members: [{ tier: 'Pro', accounts: 3 }, { tier: 'Ultra', accounts: 1 }, { tier: 'Premium (by hand)', accounts: 1 }] }),
    admin_alarm_health: () => ({ rang: 412, missed: 9, reports: 2, open_reports: alarmReports.filter((r) => !r.resolved && !r.detail.rang).length, false_alarms: 1, late_over_a_minute: 6, phones_reporting: 38,
      missed_by_device: [{ device: 'Tecno Camon 30 (Android 14)', missed: 5, users: 3 }, { device: 'Xiaomi Redmi Note 13 (Android 14)', missed: 3, users: 2 }, { device: 'Samsung SM-A155F (Android 15)', missed: 1, users: 1 }],
      problems: [{ problem: 'never_rang', reports: 1 }, { problem: 'no_sound', reports: 1 }] }),
    admin_alarm_reports: ({ only_open }) => alarmReports.filter((r) => !only_open || !r.resolved).map((r) => ({ ...r })),
    admin_alarm_events: () => diary,
    admin_resolve_alarm_report: ({ report_id, is_resolved }) => { alarmReports.find((r) => r.id === report_id).resolved = is_resolved; },
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
  window.BRAINWAKE_CONFIG = { appName: "Brain O' Clock", supabaseUrl: '', supabaseKey: '', imageBucket: '', demo: true };
})();
