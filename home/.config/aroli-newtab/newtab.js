/* Aroli New Tab — sem rede, sem polling.
   Única espera ativa: um setTimeout até o próximo minuto (relógio HH:MM).
   Todo o resto é dirigido a evento; animações via anime.js vendorizado
   (vendor/anime.min.js, sem CDN), na curva de acomodação da identidade. */
(function () {
  "use strict";

  var EASE = "cubicBezier(0.2, 0, 0, 1)";
  var REDUCED = false;
  try {
    REDUCED = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  } catch (e) { /* sem matchMedia: anima */ }
  // Sem anime ou com movimento reduzido, tudo vira estado final instantâneo.
  var A = (!REDUCED && typeof window.anime === "function") ? window.anime : null;

  var store = makeStore();
  var state = null;

  var DEFAULTS = {
    mode: "system",
    engine: "brave",
    name: "",
    ghUser: "",
    ghToken: "",
    day: todayKey(),
    activity: null,
    shortcuts: [
      { title: "YouTube", url: "https://www.youtube.com" },
      { title: "GitHub", url: "https://github.com" },
      { title: "Arch Wiki", url: "https://wiki.archlinux.org" },
      { title: "Proton Mail", url: "https://mail.proton.me" }
    ],
    todos: [],
    frame: null
  };

  var ENGINES = {
    brave: "https://search.brave.com/search?q=%s",
    google: "https://www.google.com/search?q=%s",
    duckduckgo: "https://duckduckgo.com/?q=%s",
    bing: "https://www.bing.com/search?q=%s",
    youtube: "https://www.youtube.com/results?search_query=%s",
    wikipedia: "https://pt.wikipedia.org/wiki/Special:Search?search=%s"
  };

  var ENGINE_LABELS = {
    brave: "Brave",
    google: "Google",
    duckduckgo: "DuckDuckGo",
    bing: "Bing",
    youtube: "YouTube",
    wikipedia: "Wikipédia"
  };

  function todayKey() {
    var d = new Date();
    return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
  }

  function makeStore() {
    try {
      if (typeof chrome !== "undefined" && chrome.storage && chrome.storage.local) {
        return {
          get: function (cb) {
            chrome.storage.local.get("aroli", function (res) { cb(res && res.aroli); });
          },
          set: function (val, cb) {
            chrome.storage.local.set({ aroli: val }, function () { if (cb) cb(); });
          }
        };
      }
    } catch (e) { /* sem chrome.*: cai para localStorage */ }
    return {
      get: function (cb) {
        // Erro de LEITURA vira null; erro do callback nunca é engolido
        // nem reinvocado (isso mascarava falhas e duplicava a init).
        var saved = null;
        try { saved = JSON.parse(localStorage.getItem("aroli") || "null"); }
        catch (e) { saved = null; }
        cb(saved);
      },
      set: function (val, cb) {
        try { localStorage.setItem("aroli", JSON.stringify(val)); } catch (e) {}
        if (cb) cb();
      }
    };
  }

  function normUrl(u) {
    u = (u || "").trim();
    if (!u) return "";
    if (!/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(u)) u = "https://" + u;
    return u;
  }

  // Link direto (até sem esquema: "dns.com/caminho", "localhost:3000")
  // contra termo de busca. Com espaço, nunca é link.
  function looksLikeUrl(s) {
    s = (s || "").trim();
    if (!s || /\s/.test(s)) return false;
    if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(s)) return true;
    if (/^localhost(:\d+)?(\/\S*)?$/.test(s)) return true;
    return /^[^\s/]+\.[a-zA-Z]{2,}(:\d+)?(\/\S*)?$/.test(s);
  }

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function init() {
    store.get(function (saved) {
      state = Object.assign({}, DEFAULTS, saved || {});
      state.shortcuts = Array.isArray(state.shortcuts) ? state.shortcuts.slice(0, 8) : [];
      state.todos = Array.isArray(state.todos) ? state.todos : [];
      // Limpeza diária: só na abertura, sem timers.
      if (state.day !== todayKey()) {
        state.day = todayKey();
        state.todos = state.todos.filter(function (t) { return !t.done; });
        persist();
      }
      applyMode(state.mode, false);
      renderAll();
      startClock();
      loadActivity();
    });
  }

  function persist(cb) { store.set(state, cb); }

  /* ---------- tema ---------- */

  var STATIC_FRAMES = {
    dark: { frame: [16, 17, 17], inactive: [10, 11, 11], incognito: [5, 5, 5], toolbar: [22, 25, 25], tab_text: [197, 199, 197], accent: [154, 183, 176] },
    black: { frame: [5, 5, 5], inactive: [5, 5, 5], incognito: [5, 5, 5], toolbar: [14, 16, 16], tab_text: [197, 199, 197], accent: [154, 183, 176] }
  };

  function applyMode(mode, save) {
    state.mode = mode;
    document.documentElement.setAttribute("data-theme", mode);
    var sys = document.getElementById("systemCss");
    if (sys) sys.disabled = (mode !== "system");
    document.querySelectorAll(".seg button").forEach(function (b) {
      b.setAttribute("aria-pressed", b.dataset.mode === mode ? "true" : "false");
    });
    if (save !== false) persist(function () { paintBrowserFrame(); });
    else paintBrowserFrame();
  }

  function setThemeStatus(msg) {
    var s = document.getElementById("themeStatus");
    if (s) s.textContent = msg;
  }

  function themed(colors) {
    try {
      chrome.theme.update({ colors: colors }, function () {
        var err = chrome.runtime && chrome.runtime.lastError ? chrome.runtime.lastError.message : "";
        // Policy gerenciada (ex. Omarchy color.json) vence o tema aqui.
        setThemeStatus(err ? "Navegador manteve o tema forçado: " + err : "Aplicado ao navegador ✓");
      });
    } catch (e) { setThemeStatus("Fora da extensão, só a página repinta."); }
  }
  function paintBrowserFrame() {
    try {
      if (typeof chrome === "undefined" || !chrome.theme || !chrome.theme.update) {
        setThemeStatus("Fora da extensão, só a página repinta.");
        return;
      }
      if (state.mode === "system") {
        fetch("theme-system.json", { cache: "no-store" }).then(function (r) {
          if (!r.ok) throw 0;
          return r.json();
        }).then(function (j) {
          if (j && j.colors) {
            state.frame = j.colors;
            persist();
            themed(j.colors);
          }
        }).catch(function () { /* mantém o frame atual; sem retry */ });
      } else {
        var f = STATIC_FRAMES[state.mode] || STATIC_FRAMES.dark;
        var colors = {
          frame: f.frame,
          frame_inactive: f.inactive,
          frame_incognito: f.incognito,
          frame_incognito_inactive: f.incognito,
          toolbar: f.toolbar,
          tab_text: f.tab_text,
          tab_background_text: [133, 138, 137],
          toolbar_text: [197, 199, 197],
          toolbar_button_icon: [174, 185, 188],
          omnibox_text: [197, 199, 197],
          omnibox_background: f.toolbar,
          bookmark_text: [197, 199, 197],
          ntp_background: f.frame,
          ntp_text: [197, 199, 197],
          ntp_link: f.accent,
          button_background: f.accent
        };
        state.frame = colors;
        persist();
        themed(colors);
      }
    } catch (e) { /* API indisponível fora do Brave/Chrome */ }
  }

  /* ---------- atividade GitHub: grade do ano, com cache ---------- */
  /* Célula = {d:"2026-09-23", n:3, f:false}: só JSON puro, porque o
     storage serializa e Date não sobrevive à volta (vira string). */

  var YEAR_COLS = 53; // com token: o ano inteiro
  var DAYS_COLS = 13; // sem token: últimos ~90 dias (13×7)
  var ACT_V = 3;

  function isCell(c) {
    return c && typeof c.d === "string" && typeof c.n === "number" && typeof c.f === "boolean";
  }

  function parseIso(s) {
    var p = String(s).split("-");
    return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
  }

  function isoDay(d) {
    return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
  }

  // Colunas = semanas (dom..sáb), última coluna = semana atual.
  // Ordem em coluna-major, como o CSS (grid-auto-flow: column) espera.
  function yearCells(counts, cols) {
    var today = new Date();
    today.setHours(0, 0, 0, 0);
    var end = new Date(today);
    end.setDate(end.getDate() + ((6 - end.getDay() + 7) % 7)); // sábado
    var start = new Date(end);
    start.setDate(start.getDate() - (cols * 7 - 1)); // domingo
    var cells = [];
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < 7; r++) {
        var d = new Date(start);
        d.setDate(start.getDate() + c * 7 + r);
        var iso = isoDay(d);
        cells.push({ d: iso, n: counts[iso] || 0, f: d > today });
      }
    }
    return cells;
  }

  function shortDate(iso) {
    try {
      return parseIso(iso).toLocaleDateString(navigator.language || "pt-BR", { day: "numeric", month: "short" });
    } catch (e) { return iso; }
  }

  function monthOf(iso) {
    try { return parseIso(iso).toLocaleDateString("en-US", { month: "short" }); }
    catch (e) { return ""; }
  }

  function levelOf(n) { return n <= 0 ? 0 : n <= 2 ? 1 : n <= 5 ? 2 : n <= 9 ? 3 : 4; }

  function renderActivity() {
    var box = document.getElementById("activity");
    var months = document.getElementById("activityMonths");
    var hint = document.getElementById("activityHint");
    var link = document.getElementById("activityLink");
    var user = (state.ghUser || "").trim();
    link.href = user ? "https://github.com/" + encodeURIComponent(user) : "https://github.com/";
    var a = state.activity;
    if (!user) {
      box.innerHTML = "";
      months.innerHTML = "";
      link.textContent = "The year";
      hint.textContent = "Defina seu usuário do GitHub nos ajustes.";
      return;
    }
    link.textContent = ((state.ghToken || "").trim() ? "The year · " : "90 days · ") + user;
    var cells = a && a.v === ACT_V && a.user === user && Array.isArray(a.cells)
      ? a.cells.filter(isCell) : [];
    // Cache de formato antigo (ou corrompido) nunca renderiza: refaz.
    if (!cells.length || cells.length !== (a.cols || YEAR_COLS) * 7) {
      box.innerHTML = "";
      months.innerHTML = "";
      hint.textContent = "Carregando…";
      if (a && a.user === user) state.activity = null;
      return;
    }
    box.innerHTML = cells.map(function (cell, i) {
      if (cell.f) return '<span class="day future"></span>';
      return '<span class="day l' + levelOf(cell.n) + '" data-i="' + i + '"></span>';
    }).join("");
    var seen = null;
    months.innerHTML = cells.map(function (cell, col) {
      if (col % 7 !== 0) return "";
      var m = monthOf(cell.d);
      if (!m || m === seen) return "";
      seen = m;
      return "<span>" + m + "</span>";
    }).join("");
    if (a.full) {
      var active = cells.filter(function (cell) { return !cell.f && cell.n > 0; }).length;
      hint.textContent = active + " of 365 days had a contribution.";
    } else {
      hint.textContent = a.total + " commits · últimos ~90 dias (token amplia para o ano).";
    }
  }

  function fetchYearGQL(user, token) {
    var now = new Date();
    var from = new Date(now);
    from.setFullYear(from.getFullYear() - 1);
    var q = "query($u:String!,$f:DateTime!,$t:DateTime!){user(login:$u){contributionsCollection(from:$f,to:$t){contributionCalendar{weeks{contributionDays{date contributionCount}}}}}}";
    return fetch("https://api.github.com/graphql", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": "Bearer " + token },
      body: JSON.stringify({ query: q, variables: { u: user, f: from.toISOString(), t: now.toISOString() } })
    }).then(function (r) { if (!r.ok) throw 0; return r.json(); })
      .then(function (j) {
        var weeks = (((j.data || {}).user || {}).contributionsCollection || {}).contributionCalendar;
        weeks = (weeks || {}).weeks || [];
        if (!weeks.length) throw 0;
        var counts = {};
        weeks.forEach(function (w) {
          (w.contributionDays || []).forEach(function (d) { counts[d.date] = d.contributionCount || 0; });
        });
        return { full: true, counts: counts };
      });
  }

  function fetchEvents(user) {
    return fetch("https://api.github.com/users/" + encodeURIComponent(user) + "/events/public?per_page=100", { cache: "no-store" })
      .then(function (r) { if (!r.ok) throw 0; return r.json(); })
      .then(function (evts) {
        if (!Array.isArray(evts)) throw 0;
        var counts = {};
        var total = 0;
        evts.forEach(function (e) {
          if (!e || e.type !== "PushEvent") return;
          var day = String(e.created_at || "").slice(0, 10);
          var n = (e.payload && e.payload.commits && e.payload.commits.length) || 1;
          counts[day] = (counts[day] || 0) + n;
          total += n;
        });
        return { full: false, counts: counts, total: total };
      });
  }

  function loadActivity() {
    renderActivity(); // cache primeiro: pintura instantânea
    var user = (state.ghUser || "").trim();
    if (!user) return;
    var token = (state.ghToken || "").trim();
    var hint = document.getElementById("activityHint");
    // Toda abertura recarrega do GitHub; o cache só segura a tela até chegar.
    var job = token ? fetchYearGQL(user, token) : fetchEvents(user);
    var cols = token ? YEAR_COLS : DAYS_COLS;
    var key = user + "\n" + (token ? "gql" : "events");
    job.then(function (res) {
      state.activity = { v: ACT_V, key: key, user: user, full: res.full, total: res.total || 0, cols: cols, cells: yearCells(res.counts, cols), fetchedAt: Date.now() };
      persist(renderActivity);
    }).catch(function () {
      var a = state.activity;
      var hint = document.getElementById("activityHint");
      if (a && a.cells && a.user === user) hint.textContent += " (offline — cache)";
      else {
        document.getElementById("activity").innerHTML = "";
        document.getElementById("activityMonths").innerHTML = "";
        hint.textContent = token ? "Token ou usuário inválido." : "Não foi possível carregar agora.";
      }
    });
  }

  /* Toast do dia sob o mouse: sem timers, só mouseover/mouseleave. */
  function wireToast() {
    var box = document.getElementById("activity");
    var zone = box.closest(".zone");
    var toast = document.getElementById("calToast");
    box.addEventListener("mousemove", function (ev) {
      var t = ev.target;
      if (!t || !t.classList || !t.classList.contains("day") || t.classList.contains("future")) {
        toast.hidden = true;
        return;
      }
      var cell = state.activity && state.activity.cells[Number(t.dataset.i)];
      if (!isCell(cell)) { toast.hidden = true; return; }
      toast.textContent = cell.n === 0
        ? "No contributions on " + shortDate(cell.d)
        : cell.n + (cell.n === 1 ? " contribution on " : " contributions on ") + shortDate(cell.d);
      var zr = zone.getBoundingClientRect();
      var r = t.getBoundingClientRect();
      toast.hidden = false;
      var x = r.left - zr.left + r.width / 2 - toast.offsetWidth / 2;
      var y = r.top - zr.top - toast.offsetHeight - 8;
      toast.style.left = Math.max(4, x) + "px";
      toast.style.top = Math.max(0, y) + "px";
    });
    box.addEventListener("mouseleave", function () { toast.hidden = true; });
  }

  /* ---------- render ---------- */

  function greeting() {
    var h = new Date().getHours();
    var g = h < 5 ? "Boa madrugada" : h < 12 ? "Bom dia" : h < 18 ? "Boa tarde" : "Boa noite";
    document.getElementById("greet").textContent = state.name ? g + ", " + state.name + "!" : g + "!";
  }

  var DIGITS = ["d0", "d1", "d2", "d3"];

  function setDigit(i, ch) {
    var s = document.getElementById(DIGITS[i]);
    if (!s || s.textContent === ch) return;
    s.textContent = ch;
    if (A) A({ targets: s, translateY: ["55%", "0%"], opacity: [0, 1], duration: 280, easing: EASE });
  }

  function startClock() {
    var dateEl = document.getElementById("date");
    function paint(first) {
      var d = new Date();
      var t = String(d.getHours()).padStart(2, "0") + String(d.getMinutes()).padStart(2, "0");
      for (var i = 0; i < 4; i++) {
        if (first) {
          var s = document.getElementById(DIGITS[i]);
          if (s) s.textContent = t.charAt(i);
        } else {
          setDigit(i, t.charAt(i));
        }
      }
      try {
        dateEl.textContent = d.toLocaleDateString(navigator.language || "pt-BR",
          { weekday: "long", day: "numeric", month: "long" });
      } catch (e) { dateEl.textContent = d.toDateString(); }
      greeting();
      if (first) entrance();
      // Próximo minuto, sem drift e sem intervalo fixo.
      var wait = (60 - d.getSeconds()) * 1000 - d.getMilliseconds() + 50;
      setTimeout(function () { paint(false); }, Math.max(wait, 1000));
    }
    paint(true);
  }

  /* Entrada da tela: surge uma vez, em cascata. Sem JS de animação,
     o conteúdo já nasce visível (anime.from não esconde nada antes). */
  function entrance() {
    if (!A) return;
    A.timeline({ easing: EASE })
      .add({ targets: ".hero .kicker, .hero .greet", opacity: [0, 1], translateY: [10, 0], duration: 320, delay: A.stagger(70) })
      .add({ targets: ".clockblock, .mark", opacity: [0, 1], translateY: [10, 0], duration: 320, delay: A.stagger(70) }, "-=200")
      .add({ targets: ".search", opacity: [0, 1], translateY: [10, 0], duration: 320 }, "-=200")
      .add({ targets: ".zone", opacity: [0, 1], translateY: [12, 0], duration: 320, delay: A.stagger(90) }, "-=200")
      .add({ targets: ".footbar, .gear", opacity: [0, 1], duration: 280 }, "-=160");
  }

  /* Entrada/saída de itens via anime; sem ele, troca instantânea. */
  function listEnter(ul) {
    if (!A || !ul || !ul.children.length) return;
    A({ targets: ul.children[ul.children.length - 1], opacity: [0, 1], translateY: [8, 0], duration: 280, easing: EASE });
  }

  function listLeave(ul, idx, remove) {
    var li = ul && ul.children[idx];
    if (!A || !li) { remove(); return; }
    A({ targets: li, opacity: 0, translateX: 12, duration: 200, easing: EASE, complete: remove });
  }

  function renderShortcuts() {
    var ul = document.getElementById("shortcuts");
    ul.innerHTML = state.shortcuts.map(function (s, i) {
      var letter = (s.title || "?").trim().charAt(0).toUpperCase() || "?";
      return '<li><a href="' + esc(s.url) + '"><span class="tile">' + esc(letter) +
        '</span><span class="lname">' + esc(s.title) + "</span></a>" +
        '<button class="del" data-i="' + i + '" aria-label="Remover ' + esc(s.title) + '">×</button></li>';
    }).join("");
    ul.querySelectorAll(".del").forEach(function (b) {
      b.addEventListener("click", function () {
        var idx = Number(b.dataset.i);
        listLeave(ul, idx, function () {
          state.shortcuts.splice(idx, 1);
          persist(renderShortcuts);
        });
      });
    });
  }

  function renderTodos() {
    var ul = document.getElementById("todo");
    ul.innerHTML = state.todos.map(function (t, i) {
      return '<li class="' + (t.done ? "done" : "") + '">' +
        '<input type="checkbox" data-i="' + i + '"' + (t.done ? " checked" : "") +
        ' aria-label="Concluir ' + esc(t.text) + '">' +
        "<span>" + esc(t.text) + "</span>" +
        '<button class="rm" data-i="' + i + '" aria-label="Remover tarefa">×</button></li>';
    }).join("");
    ul.querySelectorAll('input[type="checkbox"]').forEach(function (c) {
      c.addEventListener("change", function () {
        state.todos[Number(c.dataset.i)].done = c.checked;
        persist(renderTodos);
      });
    });
    ul.querySelectorAll(".rm").forEach(function (b) {
      b.addEventListener("click", function () {
        var idx = Number(b.dataset.i);
        listLeave(ul, idx, function () {
          state.todos.splice(idx, 1);
          persist(renderTodos);
        });
      });
    });
  }

  function renderAll() {
    wireDd();
    syncEngine();
    renderShortcuts();
    renderTodos();

    document.getElementById("searchForm").addEventListener("submit", function (ev) {
      ev.preventDefault();
      var q = document.getElementById("q").value.trim();
      if (!q) return;
      if (looksLikeUrl(q)) {
        location.href = normUrl(q);
        return;
      }
      var tpl = ENGINES[state.engine] || ENGINES.brave;
      location.href = tpl.replace("%s", encodeURIComponent(q));
    });
    document.getElementById("engineBtn").addEventListener("click", function (ev) {
      ev.stopPropagation();
      setDd(document.getElementById("engineList").hidden);
    });
    document.addEventListener("click", function (ev) {
      var dd = document.getElementById("engineDd");
      if (dd && !dd.contains(ev.target)) setDd(false);
    });
    document.getElementById("addForm").addEventListener("submit", function (ev) {
      ev.preventDefault();
      if (state.shortcuts.length >= 8) return;
      var title = document.getElementById("addTitle").value.trim().slice(0, 24);
      var url = normUrl(document.getElementById("addUrl").value);
      if (!title || !url) return;
      state.shortcuts.push({ title: title, url: url });
      document.getElementById("addTitle").value = "";
      document.getElementById("addUrl").value = "";
      persist(function () { renderShortcuts(); listEnter(document.getElementById("shortcuts")); });
    });
    document.getElementById("todoForm").addEventListener("submit", function (ev) {
      ev.preventDefault();
      var v = document.getElementById("todoInput").value.trim().slice(0, 120);
      if (!v) return;
      state.todos.push({ text: v, done: false });
      document.getElementById("todoInput").value = "";
      persist(function () { renderTodos(); listEnter(document.getElementById("todo")); });
    });
    var nameInput = document.getElementById("nameInput");
    nameInput.value = state.name || "";
    nameInput.addEventListener("change", function () {
      state.name = nameInput.value.trim().slice(0, 24);
      persist(greeting);
      greeting();
    });
    var ghInput = document.getElementById("ghUser");
    ghInput.value = state.ghUser || "";
    var ghReset = function () {
      state.ghUser = ghInput.value.trim().slice(0, 39);
      state.ghToken = ghToken.value.trim().slice(0, 100);
      state.activity = null;
      persist(loadActivity);
    };
    ghInput.addEventListener("change", ghReset);
    var ghToken = document.getElementById("ghToken");
    ghToken.value = state.ghToken || "";
    ghToken.addEventListener("change", ghReset);
    wireToast();
    document.querySelectorAll(".seg button").forEach(function (b) {
      b.addEventListener("click", function () { applyMode(b.dataset.mode, true); });
    });
    wireSettings();
  }

  var ENGINE_ORDER = ["brave", "google", "duckduckgo", "bing", "youtube", "wikipedia"];

  function syncEngine() {
    var eng = state.engine || "brave";
    document.getElementById("engineCur").textContent = ENGINE_LABELS[eng] || eng;
    document.getElementById("engineBadge").textContent = ENGINE_LABELS[eng] || eng;
    document.querySelectorAll("#engineList li").forEach(function (li) {
      li.setAttribute("aria-selected", li.dataset.value === eng ? "true" : "false");
    });
  }

  function setDd(open) {
    var list = document.getElementById("engineList");
    var btn = document.getElementById("engineBtn");
    if (!list || !btn) return;
    btn.setAttribute("aria-expanded", open ? "true" : "false");
    if (open && list.hidden) {
      list.hidden = false;
      if (A) A({ targets: list, opacity: [0, 1], translateY: [-6, 0], duration: 200, easing: EASE });
    } else if (!open && !list.hidden) {
      var close = function () { list.hidden = true; };
      if (A) A({ targets: list, opacity: [1, 0], duration: 160, easing: EASE, complete: close });
      else close();
    }
  }

  function wireDd() {
    var list = document.getElementById("engineList");
    list.innerHTML = ENGINE_ORDER.map(function (k) {
      return '<li role="option" data-value="' + k + '">' + ENGINE_LABELS[k] + "</li>";
    }).join("");
    list.querySelectorAll("li").forEach(function (li) {
      li.addEventListener("click", function () {
        state.engine = li.dataset.value;
        setDd(false);
        persist(syncEngine);
      });
    });
  }

  /* ---------- aba de ajustes (oculta; sem timers, só eventos) ---------- */

  function setSettings(open) {
    document.body.setAttribute("data-settings", open ? "open" : "closed");
    document.getElementById("gear").setAttribute("aria-expanded", open ? "true" : "false");
    document.getElementById("sheet").setAttribute("aria-hidden", open ? "false" : "true");
    var sheet = document.getElementById("sheet");
    var scrim = document.getElementById("scrim");
    if (A) {
      if (open) {
        A({ targets: scrim, opacity: [0, 1], duration: 280, easing: EASE });
        A({ targets: sheet, translateX: ["102%", "0%"], duration: 320, easing: EASE });
        A({ targets: "#gear svg", rotate: "+=90", duration: 280, easing: EASE });
      } else {
        A({ targets: scrim, opacity: [1, 0], duration: 280, easing: EASE });
        A({ targets: sheet, translateX: ["0%", "102%"], duration: 320, easing: EASE });
        A({ targets: "#gear svg", rotate: "-=90", duration: 280, easing: EASE });
      }
    }
    if (open) document.getElementById("closeSettings").focus();
    else document.getElementById("gear").focus();
  }

  function wireSettings() {
    document.getElementById("gear").addEventListener("click", function () {
      setSettings(document.body.getAttribute("data-settings") !== "open");
    });
    document.getElementById("closeSettings").addEventListener("click", function () {
      setSettings(false);
    });
    document.getElementById("scrim").addEventListener("click", function () {
      setSettings(false);
    });
    document.addEventListener("keydown", function (ev) {
      if (ev.key !== "Escape") return;
      var list = document.getElementById("engineList");
      if (list && !list.hidden) { setDd(false); return; }
      if (document.body.getAttribute("data-settings") === "open") setSettings(false);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
