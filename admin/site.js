// The public home page: the working alarm demo in the phone, the phones
// that turn as you move or scroll, and the live download and plan details
// (read from the same database the app uses; nothing here needs a login).

(function () {
  'use strict';
  var config = window.BRAINWAKE_CONFIG || {};
  var calm = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ------------------------------------------------------ the alarm demo
  // A copy of the app's ringing screen (lib/screens/alarm_ring_screen.dart):
  // the same views, wording and order. The questions come from the app's
  // question bank; an admin picks which ones ("On the home page").
  var NEEDED = 3;
  // Asked only if the bank cannot be reached.
  var SPARE = [
    { type: 'mcq', topic: 'General principles', text: 'First-pass metabolism of an orally administered drug takes place mainly in which organ?', answer: 'Liver',
      options: ['Kidney', 'Liver', 'Lung', 'Stomach', 'Spleen'], alt_answers: [],
      explanation: 'Drugs absorbed from the gut travel in the portal vein to the liver, where some are metabolised before reaching the systemic circulation.' },
    { type: 'saq', topic: 'General principles', text: 'What term describes the fraction of an administered dose that reaches the systemic circulation unchanged?', answer: 'Bioavailability',
      options: [], alt_answers: [], explanation: 'Bioavailability (F) is 100% for an intravenous dose and lower for other routes.' },
    { type: 'mcq', topic: 'Cardiovascular drugs', text: 'Which test is used to monitor warfarin?', answer: 'INR',
      options: ['aPTT', 'Platelet count', 'Bleeding time', 'INR', 'D-dimer'], alt_answers: [],
      explanation: 'Warfarin prolongs the prothrombin time, reported as the INR. The aPTT is used for unfractionated heparin.' },
  ];
  var ICON = {
    check: 'M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z',
    cancel: 'M12 2C6.47 2 2 6.47 2 12s4.47 10 10 10 10-4.47 10-10S17.53 2 12 2zm5 13.59L15.59 17 12 13.41 8.41 17 7 15.59 10.59 12 7 8.41 8.41 7 12 10.59 15.59 7 17 8.41 13.41 12 17 15.59z',
    close: 'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z',
    tick: 'M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z',
    arrow: 'M12 4l-1.41 1.41L16.17 11H4v2h12.17l-5.58 5.59L12 20l8-8z',
    review: 'M20 3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H4V5h16v14zM5 10h5v2H5zm0-3h5v2H5zm0 6h5v2H5zm9.59 3.42l-2.83-2.84 1.41-1.41 1.42 1.41 3.17-3.17 1.41 1.42z',
  };

  var app = document.getElementById('demo');
  var body = document.getElementById('demo-body');
  var streakText = document.getElementById('demo-streak');
  var bar = document.getElementById('demo-bar');
  var note = document.getElementById('demo-note');
  var invite = document.getElementById('invite');
  var phone = document.getElementById('demo-phone');
  var questions = SPARE.slice(), at = 0, streak = 0, wrongRun = 0, missed = 0, busy = false;

  // Where a question's picture is: pictures that ship with the app are
  // kept on this site, the rest in the question bank's picture store.
  function pictureUrl(path) {
    if (!path) return '';
    if (/^https?:/.test(path)) return path;
    if (path.indexOf('seed/') === 0) return path;
    return config.supabaseUrl + '/storage/v1/object/public/' + (config.imageBucket || 'question-images') + '/' + path;
  }

  function el(tag, cls, text) { var x = document.createElement(tag); if (cls) x.className = cls; if (text != null) x.textContent = text; return x; }
  function svg(name) { var s = document.createElementNS('http://www.w3.org/2000/svg', 'svg'); s.setAttribute('viewBox', '0 0 24 24'); var p = document.createElementNS('http://www.w3.org/2000/svg', 'path'); p.setAttribute('d', ICON[name]); s.appendChild(p); return s; }
  function squash(s) { return String(s).toLowerCase().normalize('NFD').replace(/[^a-z0-9]/g, ''); }
  function digits(s) { return String(s).replace(/[^0-9]/g, ''); }
  function distance(a, b) {
    var row = []; for (var j = 0; j <= b.length; j++) row[j] = j;
    for (var i = 1; i <= a.length; i++) {
      var prev = row[0]; row[0] = i;
      for (var k = 1; k <= b.length; k++) { var keep = row[k]; row[k] = Math.min(row[k] + 1, row[k - 1] + 1, prev + (a[i - 1] === b[k - 1] ? 0 : 1)); prev = keep; }
    }
    return row[b.length];
  }
  // The app's rule in short: no typos in short answers, one in medium,
  // two in long ones, and the digits must match exactly.
  function typedRight(given, q) {
    var mine = squash(given); if (!mine) return null;
    var best = null;
    [q.answer].concat(q.alt_answers || []).forEach(function (want) {
      var target = squash(want); if (!target || digits(mine) !== digits(target)) return;
      var allowed = target.length <= 4 ? 0 : target.length <= 8 ? 1 : 2;
      var d = distance(mine, target);
      if (d <= allowed && (best === null || d < best.d)) best = { d: d, want: want };
    });
    return best;
  }

  function show(view) { body.textContent = ''; body.appendChild(view); }
  function header() {
    streakText.textContent = 'Streak: ' + streak + ' / ' + NEEDED;
    bar.style.width = (100 * streak / NEEDED) + '%';
    note.textContent = 'Snooze unlocks after 5 wrong in a row (' + wrongRun + ' so far)';
    note.className = wrongRun > 0 ? 'ring-note hot' : 'ring-note';
  }
  function touched() {
    if (phone) phone.classList.remove('buzz');
  }

  function ask() {
    busy = false;
    var q = questions[at % questions.length];
    var view = el('div', 'view');
    view.appendChild(el('div', 'q-topic', 'TOPIC: ' + String(q.topic || '').toUpperCase()));
    if (q.image_path) { var pic = el('img', 'q-pic'); pic.src = pictureUrl(q.image_path); pic.alt = 'The picture this question is about'; view.appendChild(pic); }
    view.appendChild(el('div', q.image_path ? 'q-text with-pic' : 'q-text', q.text));
    if (q.type === 'mcq') {
      (q.options || []).forEach(function (option, i) {
        var b = el('button', 'q-opt');
        b.appendChild(el('span', 'badge', 'ABCDE'[i] || ''));
        b.appendChild(el('span', '', option));
        b.onclick = function () { answer(q, option, option === q.answer, null); };
        view.appendChild(b);
      });
    } else {
      var input = el('input', 'q-input'); input.type = 'text'; input.placeholder = 'Type answer...'; input.autocomplete = 'off'; input.spellcheck = false;
      input.setAttribute('aria-label', 'Your answer');
      var go = el('button', 'q-submit', 'Submit');
      var submit = function () {
        if (!input.value.trim()) return;
        var hit = typedRight(input.value, q);
        answer(q, input.value.trim(), !!hit, hit && hit.d > 0 ? 'Spelling: ' + hit.want : null);
      };
      go.onclick = submit;
      input.onkeydown = function (e) { if (e.key === 'Enter') submit(); };
      input.onfocus = touched;
      view.appendChild(input); view.appendChild(go);
    }
    show(view);
  }

  function answer(q, given, right, hint) {
    if (busy) return;
    busy = true; touched();
    if (right) {
      streak++; wrongRun = 0; header();
      if (streak >= NEEDED) { setTimeout(done, 350); return; }
      var ok = el('div', 'view correct');
      ok.appendChild(svg('check'));
      ok.appendChild(el('h4', '', 'Correct!'));
      ok.appendChild(el('p', '', (NEEDED - streak) + ' more to go'));
      if (hint) ok.appendChild(el('p', 'hint', hint));
      show(ok);
      setTimeout(function () { at++; ask(); }, hint ? 1900 : 1200);
    } else {
      streak = 0; wrongRun++; missed++; header();
      if (!calm) { app.classList.remove('shake'); void app.offsetWidth; app.classList.add('shake'); }
      var card = el('div', 'view wrong');
      var head = el('div', 'wrong-head'); var x = svg('cancel'); x.style.fill = '#ff453a'; head.appendChild(x); head.appendChild(document.createTextNode('Not quite')); head.appendChild(el('span', '', 'Streak reset'));
      card.appendChild(head);
      if (q.image_path) { var small = el('img', 'q-pic small'); small.src = pictureUrl(q.image_path); small.alt = ''; card.appendChild(small); }
      card.appendChild(el('div', 'wrong-q', q.text));
      var box = function (cls, icon, label, text) {
        var b = el('div', 'abox ' + cls); var i = svg(icon); i.style.fill = 'currentColor'; b.appendChild(i);
        var inner = el('div'); inner.appendChild(el('small', '', label)); inner.appendChild(el('div', '', text)); b.appendChild(inner); return b;
      };
      card.appendChild(box('no', 'close', 'YOUR ANSWER', given));
      card.appendChild(box('yes', 'tick', 'CORRECT ANSWER', q.answer));
      if (q.explanation) { card.appendChild(el('div', 'why-label', 'WHY')); card.appendChild(el('div', 'why', q.explanation)); }
      var next = el('button', 'next'); next.appendChild(svg('arrow')); next.appendChild(document.createTextNode('Next question'));
      next.onclick = function () { at++; ask(); };
      card.appendChild(next);
      show(card);
      busy = false;
    }
  }

  function done() {
    var view = el('div', 'view done');
    view.appendChild(svg('check'));
    view.appendChild(el('h4', '', 'Good morning!'));
    view.appendChild(el('p', '', 'Alarm off. It is 5:33 AM.'));
    // As in the app: after a rough morning, the missed ones can be reviewed.
    if (missed > 0) {
      var review = el('button', 'review'); review.appendChild(svg('review'));
      review.appendChild(document.createTextNode('Review ' + missed + ' missed question' + (missed === 1 ? '' : 's')));
      var tip = el('p', 'review-tip', 'Tap to go over what you got wrong.');
      review.onclick = function () {
        tip.textContent = '';
        tip.className = 'review-tip get';
        tip.appendChild(document.createTextNode('Reviewing missed questions is in the app. '));
        var link = el('a', '', 'Download it'); link.href = '#download'; tip.appendChild(link);
        tip.appendChild(document.createTextNode(' to go over yours every morning.'));
      };
      view.appendChild(review); view.appendChild(tip);
    }
    var again = el('button', 'again-link', 'Ring it again');
    again.onclick = function () { streak = 0; wrongRun = 0; missed = 0; at++; header(); ringing(true); ask(); };
    view.appendChild(again);
    show(view);
    ringing(false);
  }
  function ringing(on) {
    if (!invite) return;
    invite.className = on ? 'ringing' : 'ringing off';
    invite.firstElementChild.textContent = on ? '5:30 AM. Your alarm is ringing.' : 'Alarm off. That is the whole idea.';
    invite.lastElementChild.textContent = on ? 'Answer ' + NEEDED + ' in a row to stop it.' : 'Now imagine it at 5:30 tomorrow.';
  }

  if (app) {
    header(); ask();
    // Real questions from the bank replace the spare ones as soon as they arrive.
    if (config.supabaseUrl) {
      fetch(config.supabaseUrl + '/rest/v1/rpc/homepage_questions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: config.supabaseKey, Authorization: 'Bearer ' + config.supabaseKey },
        body: JSON.stringify({ how_many: 14 }),
      }).then(function (r) { return r.ok ? r.json() : []; }).then(function (rows) {
        // Short ones only: the phone on the page is small.
        var fit = (rows || []).filter(function (q) {
          var room = q.image_path ? 90 : 130, wide = q.image_path ? 34 : 46;
          return q.text && q.answer && q.text.length <= room && (q.type !== 'mcq' || ((q.options || []).length === 5 && q.options.every(function (o) { return o.length <= wide; })));
        });
        if (fit.length >= 3 && streak === 0 && wrongRun === 0 && !busy) { questions = fit; at = 0; ask(); }
        else if (fit.length >= 3) { questions = fit; }
      }).catch(function () { /* the spare questions stay */ });
    }
  }

  // Every phone gets its thickness: copies of its outline stepped back.
  Array.prototype.forEach.call(document.querySelectorAll('.phone'), function (p) {
    for (var z = 1; z <= 6; z++) { var e = el('i', 'edge'); e.style.transform = 'translateZ(' + (-2.2 * z) + 'px)'; p.insertBefore(e, p.firstChild); }
  });

  // -------------------------------------------- phones that turn in 3D
  var hero = phone;
  var fan = document.getElementById('fan');
  if (!calm && window.matchMedia('(pointer: fine)').matches) {
    window.addEventListener('pointermove', function (e) {
      var x = e.clientX / window.innerWidth - 0.5, y = e.clientY / window.innerHeight - 0.5;
      if (hero) { hero.style.setProperty('--ry', (-17 + x * 16) + 'deg'); hero.style.setProperty('--rx', (6 - y * 10) + 'deg'); }
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

  // ------------------------------------------- the iPhone waiting list
  var iosOpen = document.getElementById('ios-open');
  var iosForm = document.getElementById('ios-form');
  var iosDone = document.getElementById('ios-done');
  if (iosOpen && iosForm && iosDone) {
    var iosEmail = document.getElementById('ios-email');
    var say = function (text) { iosDone.textContent = text; iosDone.hidden = false; };
    iosOpen.addEventListener('click', function () {
      iosOpen.hidden = true; iosForm.hidden = false; iosEmail.focus();
    });
    iosForm.addEventListener('submit', function (event) {
      event.preventDefault();
      var address = iosEmail.value.trim();
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(address)) { say('That does not look like an email address.'); return; }
      if (!config.supabaseUrl) { say('Could not save that just now. Try again later.'); return; }
      var send = iosForm.querySelector('button');
      send.disabled = true;
      fetch(config.supabaseUrl + '/rest/v1/rpc/join_ios_waitlist', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: config.supabaseKey, Authorization: 'Bearer ' + config.supabaseKey },
        body: JSON.stringify({ address: address }),
      }).then(function (r) { return r.ok ? r.json() : false; }).then(function (ok) {
        if (ok === true) { iosForm.hidden = true; say('You are on the list. We will email you when it is out.'); }
        else { send.disabled = false; say('Could not save that just now. Try again later.'); }
      }).catch(function () { send.disabled = false; say('Could not save that just now. Try again later.'); });
    });
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
    // The install steps, right after the download starts.
    button.addEventListener('click', function () { var g = document.getElementById('guide'); if (g && g.showModal) setTimeout(function () { g.showModal(); }, 500); });
    button.textContent = 'Download';
    var date = new Date(r.published_at).toLocaleDateString('en-KE', { day: 'numeric', month: 'long', year: 'numeric' });
    document.getElementById('release-line').textContent = 'Version ' + r.version + ' · ' + date + (r.size_mb ? ' · ' + Math.round(r.size_mb) + ' MB' : '') + ' · Android 8 and later';
    if (r.notes) document.getElementById('release-notes').textContent = 'New in this version: ' + r.notes;
    hint.textContent = 'An install file (APK). Steps below.';
    var heroLine = document.getElementById('hero-version');
    if (heroLine) heroLine.textContent = 'Free to start. Your first three alarms need no account. Version ' + r.version + '.';
  }).catch(function () {
    hint.innerHTML = 'The download is not up yet. Ask us for the file on <a href="https://wa.me/254702797977">WhatsApp</a>.';
  });

  var guide = document.getElementById('guide');
  if (guide) {
    ['guide-close', 'guide-ok', 'guide-more'].forEach(function (id) { var b = document.getElementById(id); if (b) b.addEventListener('click', function () { guide.close(); }); });
    guide.addEventListener('click', function (e) { if (e.target === guide) guide.close(); });
  }

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
