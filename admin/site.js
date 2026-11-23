// The public home page: the working alarm demo in the phone, the phones
// that turn as you move or scroll, and the live download and plan details
// (read from the same database the app uses; nothing here needs a login).

(function () {
  'use strict';
  var config = window.BRAINWAKE_CONFIG || {};
  var calm = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ------------------------------------------------------ the alarm demo
  var NEEDED = 3;
  var QUESTIONS = [
    { topic: 'Pharmacology', text: 'First-line drug for anaphylaxis?', answer: 'Adrenaline',
      options: ['Hydrocortisone', 'Adrenaline', 'Chlorphenamine', 'Salbutamol', 'Atropine'],
      why: 'Intramuscular adrenaline comes first. Steroids and antihistamines act too slowly to save an airway.' },
    { topic: 'Pathology', text: 'Reed-Sternberg cells are the hallmark of which disease?', answer: 'Hodgkin lymphoma',
      options: ['Burkitt lymphoma', 'Chronic myeloid leukaemia', 'Hodgkin lymphoma', 'Multiple myeloma', 'Infectious mononucleosis'],
      why: 'The large "owl-eye" Reed-Sternberg cell defines Hodgkin lymphoma.' },
    { topic: 'Pharmacology', text: 'Antidote for paracetamol overdose?', answer: 'N-acetylcysteine', typed: true, alts: ['NAC', 'acetylcysteine'],
      why: 'N-acetylcysteine restores glutathione, which mops up the toxic metabolite NAPQI.' },
    { topic: 'Anatomy', text: 'Which nerve is compressed in carpal tunnel syndrome?', answer: 'Median nerve',
      options: ['Ulnar nerve', 'Radial nerve', 'Median nerve', 'Axillary nerve', 'Musculocutaneous nerve'],
      why: 'The median nerve runs through the carpal tunnel with the long flexor tendons.' },
    { topic: 'Pharmacology', text: 'Which test is used to monitor warfarin?', answer: 'INR',
      options: ['aPTT', 'Platelet count', 'Bleeding time', 'INR', 'D-dimer'],
      why: 'Warfarin prolongs the prothrombin time, reported as the INR. The aPTT is for unfractionated heparin.' },
    { topic: 'Biochemistry', text: 'Scurvy is caused by a lack of which vitamin?', answer: 'Vitamin C',
      options: ['Vitamin A', 'Vitamin B1', 'Vitamin C', 'Vitamin D', 'Vitamin K'],
      why: 'Vitamin C is needed to hydroxylate proline and lysine in collagen.' },
  ];

  var screen = document.getElementById('demo');
  var body = document.getElementById('demo-body');
  var streakBox = document.getElementById('demo-streak');
  var clock = document.getElementById('demo-clock');
  var streak = 0, at = 0, minute = 30, busy = false;

  function el(tag, cls, text) { var x = document.createElement(tag); if (cls) x.className = cls; if (text != null) x.textContent = text; return x; }
  function squash(s) { return String(s).toLowerCase().normalize('NFD').replace(/[^a-z0-9]/g, ''); }
  // How many letters apart two words are (for forgiving small typos).
  function distance(a, b) {
    var row = []; for (var j = 0; j <= b.length; j++) row[j] = j;
    for (var i = 1; i <= a.length; i++) {
      var prev = row[0]; row[0] = i;
      for (var k = 1; k <= b.length; k++) {
        var keep = row[k];
        row[k] = Math.min(row[k] + 1, row[k - 1] + 1, prev + (a[i - 1] === b[k - 1] ? 0 : 1));
        prev = keep;
      }
    }
    return row[b.length];
  }
  // Same idea as the app: no typos in short answers, one in medium, two in long.
  function typedRight(given, q) {
    var mine = squash(given); if (!mine) return null;
    var best = null;
    [q.answer].concat(q.alts || []).forEach(function (want) {
      var target = squash(want);
      var allowed = target.length <= 4 ? 0 : target.length <= 8 ? 1 : 2;
      var d = distance(mine, target);
      if (d <= allowed && (best === null || d < best.d)) best = { d: d, want: want };
    });
    return best;
  }

  function drawStreak() {
    streakBox.textContent = '';
    for (var i = 0; i < NEEDED; i++) streakBox.appendChild(el('i', i < streak ? 'on' : ''));
    streakBox.setAttribute('aria-label', streak + ' of ' + NEEDED + ' right in a row');
  }

  function next(delay) {
    busy = true;
    setTimeout(function () { busy = false; at = (at + 1) % QUESTIONS.length; ask(); }, delay);
  }

  function judge(right, q, verdict, spelling) {
    if (right) {
      streak++;
      verdict.innerHTML = '';
      verdict.appendChild(el('b', '', 'Correct. '));
      verdict.appendChild(document.createTextNode(spelling ? 'Spelling: ' + q.answer + '.' : q.why));
    } else {
      streak = 0;
      if (!calm) { screen.classList.remove('shake'); void screen.offsetWidth; screen.classList.add('shake'); }
      verdict.innerHTML = '';
      verdict.appendChild(el('b', 'no', 'Not that. '));
      verdict.appendChild(document.createTextNode('It is ' + q.answer + '. ' + q.why));
    }
    drawStreak();
    if (streak >= NEEDED) { busy = true; setTimeout(finish, 1100); return; }
    next(right ? 1500 : 3600);
  }

  function ask() {
    var q = QUESTIONS[at];
    body.textContent = '';
    body.appendChild(el('div', 'topic', 'Topic: ' + q.topic));
    body.appendChild(el('p', 'question', q.text));
    var verdict = el('p', 'verdict');
    if (q.typed) {
      var row = el('div', 'answer-row');
      var input = el('input'); input.type = 'text'; input.placeholder = 'Type answer…'; input.autocomplete = 'off'; input.spellcheck = false;
      input.setAttribute('aria-label', 'Your answer');
      var go = el('button', '', 'Submit');
      var submit = function () {
        if (busy || !input.value.trim()) return;
        var hit = typedRight(input.value, q);
        input.disabled = true; go.disabled = true;
        judge(!!hit, q, verdict, hit && hit.d > 0);
      };
      go.onclick = submit;
      input.onkeydown = function (e) { if (e.key === 'Enter') submit(); };
      row.appendChild(input); row.appendChild(go); body.appendChild(row);
      verdict.textContent = 'Typed answers forgive small spelling slips. Try "n acetyl cystine".';
    } else {
      var list = el('div', 'options');
      q.options.forEach(function (option) {
        var b = el('button', '', option);
        b.onclick = function () {
          if (busy) return;
          var right = option === q.answer;
          Array.prototype.forEach.call(list.children, function (other) {
            other.disabled = true;
            if (other.textContent === q.answer) other.classList.add('right');
          });
          if (!right) b.classList.add('wrong');
          judge(right, q, verdict, false);
        };
        list.appendChild(b);
      });
      body.appendChild(list);
    }
    body.appendChild(verdict);
  }

  function finish() {
    busy = false;
    screen.classList.add('off');
    minute += 2; clock.textContent = '05:' + minute;
    body.textContent = '';
    var done = el('div', 'done');
    done.appendChild(el('div', 'big-time', '05:' + minute));
    done.appendChild(el('h4', '', 'Alarm off. Good morning.'));
    done.appendChild(el('p', '', NEEDED + ' right in a row. You are awake, and three questions into the day.'));
    var again = el('button', 'again', 'Ring it again');
    again.onclick = function () { streak = 0; minute = 30; clock.textContent = '05:30'; screen.classList.remove('off'); at = (at + 1) % QUESTIONS.length; drawStreak(); ask(); };
    done.appendChild(again);
    body.appendChild(done);
  }

  if (screen) { drawStreak(); ask(); }

  // -------------------------------------------- phones that turn in 3D
  var hero = document.getElementById('demo-phone');
  var fan = document.getElementById('fan');
  if (!calm && window.matchMedia('(pointer: fine)').matches) {
    window.addEventListener('pointermove', function (e) {
      var x = e.clientX / window.innerWidth - 0.5, y = e.clientY / window.innerHeight - 0.5;
      if (hero) { hero.style.setProperty('--ry', (-16 + x * 14) + 'deg'); hero.style.setProperty('--rx', (7 - y * 10) + 'deg'); }
      if (fan) { fan.style.setProperty('--px', (x * 12) + 'deg'); fan.style.setProperty('--py', (-y * 8) + 'deg'); }
    }, { passive: true });
  }
  // The three screenshots start fanned out and close up as they pass by.
  if (fan && !calm) {
    var onScroll = function () {
      var box = fan.getBoundingClientRect();
      var middle = box.top + box.height / 2 - window.innerHeight / 2;
      var far = Math.min(1, Math.abs(middle) / (window.innerHeight * 0.75));
      fan.style.setProperty('--open', (0.45 + far * 0.75).toFixed(3));
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  // ------------------------------------- live details from the database
  function read(path) {
    if (!config.supabaseUrl) return Promise.reject(new Error('no server'));
    return fetch(config.supabaseUrl + '/rest/v1/' + path, { headers: { apikey: config.supabaseKey, Authorization: 'Bearer ' + config.supabaseKey } })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); });
  }
  function money(n) { return Number(n).toLocaleString('en-KE', { maximumFractionDigits: 0 }); }

  // The newest version to download.
  var button = document.getElementById('download-button');
  var hint = document.getElementById('download-hint');
  read('app_releases?select=version,url,size_mb,notes,published_at&order=published_at.desc&limit=1').then(function (rows) {
    var r = rows[0];
    if (!r || !r.url) throw new Error('none');
    button.href = r.url;
    button.removeAttribute('aria-disabled');
    button.setAttribute('download', '');
    button.textContent = 'Download';
    var date = new Date(r.published_at).toLocaleDateString('en-KE', { day: 'numeric', month: 'long', year: 'numeric' });
    document.getElementById('release-line').textContent = 'Version ' + r.version + ' · ' + date + (r.size_mb ? ' · ' + Math.round(r.size_mb) + ' MB' : '') + ' · Android 8 and later';
    if (r.notes) document.getElementById('release-notes').textContent = 'New in this version: ' + r.notes;
    hint.textContent = 'An install file (APK). Steps below.';
    var heroLine = document.getElementById('hero-version');
    if (heroLine) heroLine.textContent = 'Free to start. No account needed for your first three alarms. Version ' + r.version + '.';
  }).catch(function () {
    hint.innerHTML = 'The download is not up yet. Ask us for the file on <a href="https://wa.me/254702797977">WhatsApp</a>.';
  });

  // The paid plans, as the owner has them set right now.
  Promise.all([
    read('tiers?select=id,name,features,price_month,price_year,sort_order&active=eq.true&order=sort_order'),
    read('app_config?select=key,value&key=eq.premium_currency'),
  ]).then(function (got) {
    var currency = (got[1][0] && got[1][0].value) || 'KES';
    var list = document.getElementById('plan-list');
    var paid = got[0].filter(function (t) { return t.price_month || t.price_year; });
    if (!paid.length) return;
    Array.prototype.slice.call(list.querySelectorAll('.plan.paid')).forEach(function (old) { old.remove(); });
    paid.forEach(function (t) {
      var card = el('article', 'plan paid');
      card.appendChild(el('h3', '', t.name));
      var price = el('p', 'price');
      if (t.price_month) { price.appendChild(document.createTextNode(currency + ' ' + money(t.price_month) + ' ')); price.appendChild(el('span', '', 'a month')); }
      if (t.price_year) price.appendChild(el('small', '', (t.price_month ? 'or ' : '') + currency + ' ' + money(t.price_year) + ' a year'));
      card.appendChild(price);
      var ul = el('ul');
      (t.features || []).forEach(function (f) { ul.appendChild(el('li', '', f)); });
      card.appendChild(ul);
      list.appendChild(card);
    });
  }).catch(function () { /* the plans written in the page stay */ });
})();
