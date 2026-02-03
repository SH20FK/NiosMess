const DEFAULT_API = "http://144.31.1.79:27580";
const $ = (id) => document.getElementById(id);

const FAVORITES_CHAT_ID = "__favorites__";
const DEFAULT_EMPTY_TITLE = "Пока что здесь пустовато";
const DEFAULT_EMPTY_SUBTITLE = "Выберите чат, чтобы начать общение";

const state = {
  apiBase: DEFAULT_API,
  session: null,
  isRegister: false,
  activeTarget: null,
  lastMsgId: -1,
  messages: [],
  messagesLoaded: false,
  syncTimer: null,
  profileTimer: null,
  searchTimer: null,
  loadingCount: 0,
  rendering: false,
  contextMenuTarget: null,
  favorites: new Set(JSON.parse(localStorage.getItem("niosmess_favorites") || "[]")),
  favoritesData: JSON.parse(localStorage.getItem("niosmess_favorites_data") || "{}"),
  messageSearchResults: [],
  messageSearchIndex: -1,
  messageSearchQuery: "",
  settings: JSON.parse(localStorage.getItem("niosmess_settings") || '{"theme":"dark","accent":"blue"}'),
};

const obfMap = {
  "А":"☢","Б":"⬣","В":"⬟","Г":"⬢","Д":"✥","Е":"✸","Ё":"✦","Ж":"⚡","З":"⬥","И":"◎","Й":"✺","К":"☍","Л":"⬤","М":"☯","Н":"⚑","О":"⚙","П":"⬦","Р":"☁","С":"⬧","Т":"✖","У":"⬨","Ф":"✣","Х":"☊","Ц":"✹","Ч":"✪","Ш":"⬩","Щ":"✶","Ъ":"⍉","Ы":"⌬","Ь":"⌫","Э":"✷","Ю":"✿","Я":"☮",
  "а":"☠","б":"⬞","в":"⬠","г":"⬡","д":"✧","е":"✱","ё":"✫","ж":"⚔","з":"⬪","и":"◉","й":"✻","к":"☌","л":"⬯","м":"☰","н":"⚐","о":"⚗","п":"⬫","р":"☂","с":"⧈","т":"✕","у":"⬭","ф":"✤","х":"☋","ц":"✾","ч":"✯","ш":"⬮","щ":"✵","ъ":"⍊","ы":"⌭","ь":"〉","э":"✼","ю":"❀","я":"☾",
  "A":"∆","B":"∑","C":"⊗","D":"∂","E":"≡","F":"⊥","G":"∇","H":"⊕","I":"∫","J":"⌘","K":"⍟","L":"⌗","M":"⎔","N":"⊘","O":"⊙","P":"⌖","Q":"⌬̸","R":"⎇","S":"⌿","T":"⏚","U":"⎊","V":"⌸","W":"⍥","X":"⨯","Y":"⍠","Z":"⍢",
  "a":"☉","b":"⬖","c":"⬘","d":"✢","e":"✶̇","f":"⬛","g":"⚘","h":"✺̇","i":"⬙","j":"❖","k":"下","l":"⬚","m":"⚐̇","n":"⬢̇","o":"⚙̇","p":"⬣̇","q":"✧̇","r":"凹","s":"⬥̇","t":"✸̇","u":"⬦̇","v":"✷̇","w":"⬧̇","x":"❂","y":"✦̇","z":"⬨̇",
};

const revMap = new Map(Object.entries(obfMap).map(([k, v]) => [v, k]));
const twoChar = new Set([...revMap.keys()].filter((v) => v.length === 2));
const oneChar = new Set([...revMap.keys()].filter((v) => v.length === 1));

function obfuscate(text) {
  let out = "";
  for (const ch of text) out += obfMap[ch] || ch;
  return out;
}

function deobfuscate(text) {
  let out = "";
  let i = 0;
  while (i < text.length) {
    const two = text.slice(i, i + 2);
    if (twoChar.has(two)) {
      out += revMap.get(two);
      i += 2;
      continue;
    }
    const one = text[i];
    out += oneChar.has(one) ? revMap.get(one) : one;
    i += 1;
  }
  return out;
}

function setView(view) {
  $("authView").classList.toggle("hidden", view !== "auth");
  $("appView").classList.toggle("hidden", view !== "app");
  $("myProfileView").classList.toggle("hidden", view !== "myProfile");
}

function toast(msg, duration = 3000) {
  const container = $("toastContainer");
  const el = document.createElement("div");
  el.className = "toast";
  el.textContent = msg;
  container.appendChild(el);

  requestAnimationFrame(() => {
    el.classList.add("toast-show");
  });

  setTimeout(() => {
    el.classList.remove("toast-show");
    el.classList.add("toast-out");
    setTimeout(() => el.remove(), 300);
  }, duration);
}

function resetMessagesEmptyText() {
  const title = $("messagesEmptyTitle");
  const subtitle = $("messagesEmptySubtitle");
  if (title) title.textContent = DEFAULT_EMPTY_TITLE;
  if (subtitle) subtitle.textContent = DEFAULT_EMPTY_SUBTITLE;
}

function getStoredAvatar() {
  return localStorage.getItem("niosmess_avatar") || "";
}

function applyAvatar(el, fallbackInitial) {
  if (!el) return;
  const avatar = getStoredAvatar();
  if (avatar) {
    el.style.backgroundImage = `url(${avatar})`;
    el.style.backgroundSize = "cover";
    el.style.backgroundPosition = "center";
    el.textContent = "";
  } else {
    el.style.backgroundImage = "";
    el.textContent = fallbackInitial || "?";
  }
}

function saveFavoritesData(data) {
  state.favoritesData = data;
  localStorage.setItem("niosmess_favorites_data", JSON.stringify(data));
}

function showError(msg) {
  const el = $("authError");
  el.textContent = msg;
  el.classList.remove("hidden");
}

function clearError() {
  $("authError").classList.add("hidden");
  $("authError").textContent = "";
}

function showLoading() {
  state.loadingCount++;
  $("loadingOverlay").classList.remove("is-hidden");
}

function hideLoading() {
  state.loadingCount = Math.max(0, state.loadingCount - 1);
  if (state.loadingCount === 0) {
    $("loadingOverlay").classList.add("is-hidden");
  }
}

function setButtonLoading(btnId, loading) {
  const btn = $(btnId);
  if (!btn) return;

  const text = btn.querySelector(".btn-text");
  const loader = btn.querySelector(".btn-loader");

  if (text) text.classList.toggle("hidden", loading);
  if (loader) loader.classList.toggle("hidden", !loading);
  btn.disabled = loading;
}

function applySettings() {
  const settings = state.settings;

  document.documentElement.setAttribute("data-theme", settings.theme || "dark");
  document.documentElement.setAttribute("data-accent", settings.accent || "blue");

  document.querySelectorAll(".theme-card").forEach(card => {
    const theme = card.dataset.theme;
    const accent = card.dataset.accent;
    card.classList.toggle("active",
      theme === (settings.theme || "dark") && accent === (settings.accent || "blue")
    );
  });
}

function saveSettings(updates) {
  state.settings = { ...state.settings, ...updates };
  localStorage.setItem("niosmess_settings", JSON.stringify(state.settings));
  applySettings();
}

async function apiFetch(path, options = {}, { silent = false } = {}) {
  const url = `${state.apiBase}${path}`;
  if (!silent) showLoading();

  try {
    const res = await fetch(url, options);

    if (!res.ok) {
      let data = {};
      try {
        data = await res.json();
      } catch {}
      const msg = data.detail || data.error || `Ошибка сервера (${res.status})`;
      throw new Error(msg);
    }

    const text = await res.text();
    return text ? JSON.parse(text) : {};
  } finally {
    if (!silent) hideLoading();
  }
}

async function loginOrRegister() {
  clearError();
  setButtonLoading("authBtn", true);

  const payload = {
    email: $("emailInput").value.trim(),
    password: $("passwordInput").value.trim(),
    username: $("usernameInput").value.trim(),
    name: $("nameInput").value.trim(),
    code: $("codeInput").value.trim() || null,
  };

  const mode = state.isRegister ? "register" : "login";

  try {
    const data = await apiFetch(`/${mode}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (data.status === "wait_code") {
      $("codeField").classList.remove("hidden");
      $("authBtn").querySelector(".btn-text").textContent = "ПОДТВЕРДИТЬ";
      toast("Код отправлен на email");
      return;
    }

    if (data.token) {
      saveSession({ token: data.token, username: data.username || payload.username });
      initApp();
      return;
    }

    if (data.status === "ok") {
      const token = data.token || data.access_token || "";
      if (!token) throw new Error("Сервер не вернул token.");
      saveSession({ token, username: data.username || payload.username });
      initApp();
      return;
    }

    throw new Error("Неожиданный ответ сервера.");
  } catch (err) {
    showError(err.message);
  } finally {
    setButtonLoading("authBtn", false);
  }
}

async function checkSession() {
  const raw = localStorage.getItem("niosmess_session");
  if (!raw) {
    hideLoading();
    return;
  }

  try {
    const data = JSON.parse(raw);
    if (!data.token || !data.username) {
      hideLoading();
      return;
    }

    showLoading();
    const res = await apiFetch("/check_session", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token: data.token, username: data.username }),
    }, { silent: true });

    if (res.status === "ok" || res.token || res.username) {
      saveSession({ ...data, ...res });
      initApp();
    }
  } catch {
    localStorage.removeItem("niosmess_session");
  } finally {
    hideLoading();
  }
}

function saveSession(data) {
  state.session = data;
  localStorage.setItem("niosmess_session", JSON.stringify(data));
}

function stopTimers() {
  if (state.syncTimer) clearInterval(state.syncTimer);
  state.syncTimer = null;

  if (state.profileTimer) clearInterval(state.profileTimer);
  state.profileTimer = null;
}

function clearSession() {
  stopTimers();
  state.session = null;
  state.activeTarget = null;
  state.messages = [];
  state.lastMsgId = -1;
  state.messagesLoaded = false;
  localStorage.removeItem("niosmess_session");
}

function setAuthMode(isRegister) {
  state.isRegister = isRegister;

  $("authTitle").textContent = isRegister ? "Регистрация" : "Вход";
  $("authBtn").querySelector(".btn-text").textContent = isRegister ? "ПРОДОЛЖИТЬ" : "ВОЙТИ";
  $("toggleAuthBtn").textContent = isRegister ? "Уже есть аккаунт?" : "Создать аккаунт";

  $("usernameField").classList.toggle("hidden", !isRegister);
  $("nameField").classList.toggle("hidden", !isRegister);
  $("codeField").classList.add("hidden");
  $("codeInput").value = "";
}

async function loadChats({ silent = false } = {}) {
  if (!state.session) return;

  try {
    const data = await apiFetch(
      `/get_chats?user=${encodeURIComponent(state.session.username)}&token=${encodeURIComponent(state.session.token)}&version=1.0`,
      {},
      { silent }
    );

    renderChatList(Array.isArray(data) ? data : []);
  } catch (err) {
    if (!silent) toast("Не удалось загрузить чаты");
  }
}

function renderChatList(chats) {
  const list = $("chatList");
  const empty = $("chatEmpty");

  list.querySelectorAll(".skeleton-item").forEach(el => el.remove());
  list.innerHTML = "";

  const favCount = Object.keys(state.favoritesData || {}).length;
  const favItem = document.createElement("div");
  favItem.className = "chat-item favorites-item";
  favItem.dataset.username = FAVORITES_CHAT_ID;
  if (state.activeTarget === FAVORITES_CHAT_ID) favItem.classList.add("active");

  const favAvatar = document.createElement("div");
  favAvatar.className = "chat-item-avatar favorites-avatar";
  favAvatar.textContent = "★";
  favItem.appendChild(favAvatar);

  const favContent = document.createElement("div");
  favContent.className = "chat-item-content";
  favContent.innerHTML = `
    <div class="chat-item-header">
      <div class="chat-item-name">Избранное</div>
      <div class="chat-item-time"></div>
    </div>
    <div class="chat-item-message">${favCount ? `Сообщений: ${favCount}` : "Сохраненные сообщения"}</div>
  `;
  favItem.appendChild(favContent);
  favItem.addEventListener("click", () => openFavoritesChat());
  list.appendChild(favItem);

  if (!Array.isArray(chats) || chats.length === 0) {
    empty.classList.add("hidden");
    return;
  }

  empty.classList.add("hidden");

  chats.forEach((u) => {
    const item = document.createElement("div");
    item.className = "chat-item";
    item.dataset.username = u.username;

    if (u.username === state.activeTarget) item.classList.add("active");

    const avatar = document.createElement("div");
    avatar.className = "chat-item-avatar";
    avatar.textContent = (u.name ? String(u.name)[0] : u.username ? String(u.username)[0] : "?").toUpperCase();

    const content = document.createElement("div");
    content.className = "chat-item-content";

    const header = document.createElement("div");
    header.className = "chat-item-header";

    const name = document.createElement("div");
    name.className = "chat-item-name";
    name.textContent = u.name || u.username || "—";

    header.appendChild(name);

    const message = document.createElement("div");
    message.className = "chat-item-message";
    message.textContent = u.isonline ? "в сети" : "не в сети";

    content.appendChild(header);
    content.appendChild(message);

    if (u.isonline) {
      const indicator = document.createElement("div");
      indicator.className = "status-indicator online";
      item.appendChild(indicator);
    }

    item.appendChild(avatar);
    item.appendChild(content);

    item.addEventListener("click", () => selectChat(u));
    list.appendChild(item);
  });
}

function openFavoritesChat() {
  closeMessageSearch();
  state.activeTarget = FAVORITES_CHAT_ID;
  state.messages = [];
  state.messagesLoaded = true;

  $("chatTitle").textContent = "Избранное";
  const favCount = Object.keys(state.favoritesData || {}).length;
  $("chatSubtitle").textContent = favCount ? `Сообщений: ${favCount}` : "Сохраненные сообщения";
  $("chatSubtitle").classList.remove("online");

  const inputWrapper = document.querySelector(".message-input-wrapper");
  inputWrapper.style.display = "none";

  $("messageInput").disabled = true;
  $("sendBtn").disabled = true;
  $("attachBtn").disabled = true;
  $("emojiBtn").disabled = true;
  $("profileBtn").disabled = true;
  $("searchMessagesBtn").disabled = false;

  document.querySelectorAll(".chat-item").forEach(item => {
    item.classList.toggle("active", item.dataset.username === FAVORITES_CHAT_ID);
  });

  if ($("profilePanel").classList.contains("show")) {
    toggleProfile(false);
  }

  renderFavoritesMessages();
}

function renderFavoritesMessages() {
  const list = $("messageList");
  list.innerHTML = "";

  const data = Object.values(state.favoritesData || {});
  if (data.length === 0) {
    $("messagesEmpty").classList.remove("hidden");
    $("messagesEmptyTitle").textContent = "Избранное пусто";
    $("messagesEmptySubtitle").textContent = "Добавьте сообщение в избранное через контекстное меню";
    return;
  }

  $("messagesEmpty").classList.add("hidden");
  data.sort((a, b) => (b.savedAt || 0) - (a.savedAt || 0));
  data.forEach((item) => {
    const wrapper = document.createElement("div");
    wrapper.className = "favorite-message";

    const meta = document.createElement("div");
    meta.className = "favorite-meta";
    meta.textContent = item.chatWith ? `Из чата: ${item.chatWith}` : "Из чата";
    wrapper.appendChild(meta);

    createMessageElement(item.message || item, wrapper);
    list.appendChild(wrapper);
  });

  $("chatSubtitle").textContent = `Сообщений: ${data.length}`;
}

function openHelpModal() {
  $("helpModal").classList.remove("hidden");
}

function closeHelpModal() {
  $("helpModal").classList.add("hidden");
}

function openMessageSearch() {
  if (!state.activeTarget) return;
  const bar = $("messageSearchBar");
  bar.classList.remove("hidden");
  $("messageSearchInput").focus();
  runMessageSearch();
}

function closeMessageSearch() {
  const bar = $("messageSearchBar");
  bar.classList.add("hidden");
  $("messageSearchInput").value = "";
  clearMessageSearchHighlights();
}

function clearMessageSearchHighlights() {
  document.querySelectorAll("#messageList .message").forEach((el) => {
    el.classList.remove("message-search-hit", "message-search-current");
  });
  state.messageSearchResults = [];
  state.messageSearchIndex = -1;
  $("messageSearchCount").textContent = "0/0";
}

function runMessageSearch() {
  const q = $("messageSearchInput").value.trim().toLowerCase();
  state.messageSearchQuery = q;

  const messages = Array.from(document.querySelectorAll("#messageList .message"));
  messages.forEach((el) => el.classList.remove("message-search-hit", "message-search-current"));

  if (!q) {
    clearMessageSearchHighlights();
    return;
  }

  const matches = messages.filter((el) => el.textContent.toLowerCase().includes(q));
  matches.forEach((el) => el.classList.add("message-search-hit"));
  state.messageSearchResults = matches;
  state.messageSearchIndex = matches.length ? 0 : -1;

  updateMessageSearchCount();
  focusMessageSearchResult();
}

function updateMessageSearchCount() {
  const total = state.messageSearchResults.length;
  const index = state.messageSearchIndex >= 0 ? state.messageSearchIndex + 1 : 0;
  $("messageSearchCount").textContent = `${index}/${total}`;
}

function focusMessageSearchResult() {
  const results = state.messageSearchResults;
  if (!results.length) return;

  results.forEach((el) => el.classList.remove("message-search-current"));
  const current = results[state.messageSearchIndex];
  if (!current) return;
  current.classList.add("message-search-current");
  current.scrollIntoView({ behavior: "smooth", block: "center" });
}

function stepMessageSearch(direction) {
  const total = state.messageSearchResults.length;
  if (!total) return;

  state.messageSearchIndex = (state.messageSearchIndex + direction + total) % total;
  updateMessageSearchCount();
  focusMessageSearchResult();
}

async function selectChat(u) {
  if (u.username === FAVORITES_CHAT_ID) {
    openFavoritesChat();
    return;
  }
  closeMessageSearch();
  state.activeTarget = u.username;
  state.lastMsgId = -1;
  state.messages = [];
  state.messagesLoaded = false;

  $("chatTitle").textContent = u.name || u.username || "Чат";
  $("chatSubtitle").textContent = u.isonline ? "в сети" : "не в сети";

  if (u.isonline) {
    $("chatSubtitle").classList.add("online");
  } else {
    $("chatSubtitle").classList.remove("online");
  }

  $("chatAvatar").textContent = (u.name ? String(u.name)[0] : u.username ? String(u.username)[0] : "?").toUpperCase();

  resetMessagesEmptyText();
  $("messagesEmpty").classList.remove("hidden");
  $("messageList").innerHTML = "";

  const inputWrapper = document.querySelector(".message-input-wrapper");
  inputWrapper.style.display = "flex";

  $("messageInput").disabled = false;
  $("sendBtn").disabled = false;
  $("attachBtn").disabled = false;
  $("emojiBtn").disabled = false;
  $("profileBtn").disabled = false;
  $("searchMessagesBtn").disabled = false;

  document.querySelectorAll(".chat-item").forEach(item => {
    item.classList.toggle("active", item.dataset.username === u.username);
  });

  if ($("profilePanel").classList.contains("show")) {
    toggleProfile(false);
  }

  loadDraft();

  setTimeout(() => $("messageInput").focus(), 100);

  await loadMessages({ silent: false });
}

function saveDraft() {
  if (!state.activeTarget) return;

  const text = $("messageInput").value.trim();
  const drafts = JSON.parse(localStorage.getItem("niosmess_drafts") || "{}");

  if (text) {
    drafts[state.activeTarget] = text;
  } else {
    delete drafts[state.activeTarget];
  }

  localStorage.setItem("niosmess_drafts", JSON.stringify(drafts));
}

function loadDraft() {
  if (!state.activeTarget) return;

  const drafts = JSON.parse(localStorage.getItem("niosmess_drafts") || "{}");
  const draft = drafts[state.activeTarget] || "";

  $("messageInput").value = draft;
  autoResize($("messageInput"));
}

function clearDraft() {
  if (!state.activeTarget) return;

  const drafts = JSON.parse(localStorage.getItem("niosmess_drafts") || "{}");
  delete drafts[state.activeTarget];
  localStorage.setItem("niosmess_drafts", JSON.stringify(drafts));
}

async function loadMessages({ silent = true } = {}) {
  if (!state.activeTarget || !state.session) return;
  if (state.activeTarget === FAVORITES_CHAT_ID) return;

  try {
    const data = await apiFetch(
      `/get_messages?me=${encodeURIComponent(state.session.username)}&other=${encodeURIComponent(state.activeTarget)}&token=${encodeURIComponent(state.session.token)}`,
      {},
      { silent }
    );

    const newMessages = Array.isArray(data) ? data : [];

    if (!state.messagesLoaded) {
      if (newMessages.length === 0) {
        $("messageList").innerHTML = "";
        $("messagesEmpty").classList.remove("hidden");
        state.messagesLoaded = true;
        return;
      }

      state.messages = newMessages;
      state.messagesLoaded = true;
      renderMessages(newMessages);
      return;
    }

    if (newMessages.length === 0) {
      return;
    }

    const existingIds = new Set(state.messages.map(m => m.id || m.temp_id));
    const newItems = newMessages.filter(m => !existingIds.has(m.id || m.temp_id));

    if (newItems.length === 0 && state.messages.length === newMessages.length) {
      return;
    }

    if (newItems.length > 0) {
      state.messages = newMessages;

      newItems.forEach(msg => {
        appendMessage(msg);
      });

      const list = $("messageList");
      const wasAtBottom = list.scrollHeight - list.scrollTop - list.clientHeight < 100;
      if (wasAtBottom) {
        setTimeout(() => {
          list.scrollTop = list.scrollHeight;
        }, 50);
      }
    }

  } catch (err) {
    if (!silent) toast("Не удалось загрузить сообщения");
  }
}

function renderMessages(msgs) {
  if (state.rendering) return;
  state.rendering = true;

  const list = $("messageList");
  const wasAtBottom = list.scrollHeight - list.scrollTop - list.clientHeight < 50;

  $("messagesEmpty").classList.add("hidden");
  list.innerHTML = "";

  msgs.forEach((m) => {
    createMessageElement(m, list);
  });

  if (wasAtBottom || msgs.length <= 5) {
    requestAnimationFrame(() => {
      list.scrollTop = list.scrollHeight;
    });
  }

  if (!$("messageSearchBar").classList.contains("hidden") && state.messageSearchQuery) {
    runMessageSearch();
  }

  state.rendering = false;
}

function appendMessage(msg) {
  const list = $("messageList");
  $("messagesEmpty").classList.add("hidden");
  createMessageElement(msg, list);
  if (!$("messageSearchBar").classList.contains("hidden") && state.messageSearchQuery) {
    runMessageSearch();
  }
}

function createMessageElement(m, container) {
  const media = new Set(["jpg", "jpeg", "png", "gif", "webp", "svg", "ico", "bmp"]);
  const isMe = m.sender === state.session.username;
  const isFile = typeof m.text === "string" && m.text.startsWith("FILE:");
  const msgId = String(m.id || m.temp_id);

  const message = document.createElement("div");
  message.className = `message ${isMe ? "out" : "in"}`.trim();
  message.dataset.id = msgId;

  if (m.temp) message.classList.add("sending");
  if (state.favorites.has(msgId)) message.classList.add("favorite");

  if (isFile) {
    const raw = m.text.replace("FILE:", "").trim();
    const ext = raw.toLowerCase().split(".").pop();
    const link = `${state.apiBase}/download/${encodeURIComponent(raw)}`;

    if (media.has(ext)) {
      const preview = document.createElement("div");
      preview.className = "file-preview";

      const img = document.createElement("img");
      img.src = link;
      img.alt = raw;
      img.loading = "lazy";

      preview.appendChild(img);
      message.appendChild(preview);

      preview.addEventListener("click", () => window.open(link, "_blank"));
    } else {
      const fileDiv = document.createElement("div");
      fileDiv.className = "message-file";
      fileDiv.innerHTML = `📄 <a href="${link}" target="_blank" rel="noreferrer">${raw}</a>`;
      message.appendChild(fileDiv);
    }
  } else {
    const safe = String(m.text ?? "");
    const deobf = deobfuscate(safe).replace(/\s+/g, " ").trim();

    const formatted = parseMarkdown(deobf);

    const urlRegex = /(https?:\/\/[^\s]+)/g;
    const urls = deobf.match(urlRegex);

    const textSpan = document.createElement("span");
    textSpan.innerHTML = formatted;
    message.appendChild(textSpan);

    if (urls && urls.length > 0) {
      addLinkPreview(message, urls[0]);
    }
  }

  message.addEventListener("contextmenu", (e) => {
    e.preventDefault();
    showContextMenu(e, message, m);
  });

  container.appendChild(message);
}

function parseMarkdown(text) {
  let result = text;

  result = result.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  result = result.replace(/__(.+?)__/g, "<strong>$1</strong>");

  result = result.replace(/\*(.+?)\*/g, "<em>$1</em>");
  result = result.replace(/_(.+?)_/g, "<em>$1</em>");

  result = result.replace(/`(.+?)`/g, "<code>$1</code>");

  result = result.replace(/~~(.+?)~~/g, "<del>$1</del>");

  return result;
}

async function addLinkPreview(messageEl, url) {
  try {
    const urlObj = new URL(url);
    const domain = urlObj.hostname;

    const preview = document.createElement("div");
    preview.className = "link-preview";

    preview.innerHTML = `
      <div class="link-preview-title">${domain}</div>
      <div class="link-preview-url">${url}</div>
    `;

    preview.addEventListener("click", () => window.open(url, "_blank"));

    messageEl.appendChild(preview);
  } catch {}
}

async function sendMessage() {
  const input = $("messageInput");
  const txt = input.value.trim();

  if (!txt || !state.activeTarget || !state.session) return;

  input.value = "";
  autoResize(input);
  clearDraft();

  const tempId = `temp_${Date.now()}_${Math.random()}`;
  const tempMsg = {
    temp_id: tempId,
    sender: state.session.username,
    receiver: state.activeTarget,
    text: txt,
    temp: true,
  };

  state.messages.push(tempMsg);
  appendMessage(tempMsg);

  const payload = {
    sender: state.session.username,
    receiver: state.activeTarget,
    text: obfuscate(txt.replace(/\s+/g, " ").trim()),
    token: state.session.token,
  };

  try {
    await apiFetch("/send_message", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    }, { silent: true });

    state.messages = state.messages.filter(m => m.temp_id !== tempId);

    const tempEl = document.querySelector(`[data-id="${tempId}"]`);
    if (tempEl) {
      tempEl.style.animation = "fadeOut 0.2s ease forwards";
      setTimeout(() => {
        tempEl.remove();

        loadMessages({ silent: true });
      }, 200);
    } else {
      loadMessages({ silent: true });
    }
  } catch (err) {
    state.messages = state.messages.filter(m => m.temp_id !== tempId);
    const tempEl = document.querySelector(`[data-id="${tempId}"]`);
    if (tempEl) tempEl.remove();
    toast("Не удалось отправить");
  } finally {
    input.focus();
  }
}

async function uploadFile(file) {
  if (!file || !state.activeTarget || !state.session) return;

  const maxSize = 50 * 1024 * 1024;
  if (file.size > maxSize) {
    toast("Файл слишком большой (макс. 50MB)");
    return;
  }

  const form = new FormData();
  form.append("file", file);
  form.append("sender", state.session.username);
  form.append("receiver", state.activeTarget);
  form.append("token", state.session.token);

  showLoading();

  try {
    const res = await fetch(`${state.apiBase}/upload`, { method: "POST", body: form });

    if (!res.ok) {
      let data = {};
      try { data = await res.json(); } catch {}
      throw new Error(data.detail || data.error || "Ошибка загрузки");
    }

    toast("Файл отправлен ✓");
    setTimeout(() => {
      state.lastMsgId = -1;
      loadMessages({ silent: true });
    }, 500);
  } catch (err) {
    toast(err.message);
  } finally {
    hideLoading();
  }
}

let currentEmojiCategory = null;

function initEmojiPicker() {
  const picker = $("emojiPicker");

  const header = picker.querySelector(".emoji-header");
  header.innerHTML = `
    <input id="emojiSearch" type="text" placeholder="Поиск эмодзи..." />
    <div class="emoji-categories"></div>
  `;

  const categoriesDiv = header.querySelector(".emoji-categories");

  Object.keys(emojiCategories).forEach((categoryName, index) => {
    const tab = document.createElement("button");
    tab.className = "emoji-category-tab";
    tab.textContent = categoryName;
    tab.dataset.category = categoryName;

    if (index === 0) {
      tab.classList.add("active");
      currentEmojiCategory = categoryName;
    }

    tab.addEventListener("click", () => {
      document.querySelectorAll(".emoji-category-tab").forEach(t => t.classList.remove("active"));
      tab.classList.add("active");
      currentEmojiCategory = categoryName;
      renderEmojiCategory(categoryName);
      $("emojiSearch").value = "";
    });

    categoriesDiv.appendChild(tab);
  });

  renderEmojiCategory(Object.keys(emojiCategories)[0]);

  $("emojiSearch").addEventListener("input", (e) => {
    const query = e.target.value.toLowerCase().trim();

    if (!query) {
      renderEmojiCategory(currentEmojiCategory);
      return;
    }

    const results = [];
    Object.values(emojiCategories).forEach(category => {
      category.forEach(item => {
        if (item.keywords.some(kw => kw.includes(query))) {
          results.push(item.emoji);
        }
      });
    });

    const uniqueResults = [...new Set(results)];

    const grid = $("emojiGrid");
    grid.innerHTML = "";

    if (uniqueResults.length === 0) {
      grid.innerHTML = '<div style="grid-column: 1/-1; text-align: center; padding: 20px; color: var(--text-tertiary);">Ничего не найдено</div>';
      return;
    }

    uniqueResults.forEach(emoji => {
      const item = document.createElement("div");
      item.className = "emoji-item";
      item.textContent = emoji;
      item.addEventListener("click", () => {
        insertEmoji(emoji);
      });
      grid.appendChild(item);
    });
  });
}

function renderEmojiCategory(categoryName) {
  const grid = $("emojiGrid");
  grid.innerHTML = "";

  const category = emojiCategories[categoryName];

  if (!category) return;

  category.forEach(item => {
    const emojiEl = document.createElement("div");
    emojiEl.className = "emoji-item";
    emojiEl.textContent = item.emoji;
    emojiEl.title = item.keywords[0];
    emojiEl.addEventListener("click", () => {
      insertEmoji(item.emoji);
    });
    grid.appendChild(emojiEl);
  });
}

function toggleEmojiPicker() {
  if (!state.activeTarget) {
    toast("Сначала выберите чат");
    return;
  }

  const picker = $("emojiPicker");
  const isHidden = picker.classList.contains("hidden");

  picker.classList.toggle("hidden");

  if (isHidden) {
    $("emojiSearch").value = "";
    renderEmojiCategory(currentEmojiCategory || Object.keys(emojiCategories)[0]);
    setTimeout(() => $("emojiSearch").focus(), 100);
  }
}

function insertEmoji(emoji) {
  const input = $("messageInput");
  const pos = input.selectionStart;
  const text = input.value;

  input.value = text.substring(0, pos) + emoji + text.substring(pos);
  input.setSelectionRange(pos + emoji.length, pos + emoji.length);
  input.focus();

  saveDraft();
  autoResize(input);
}

function showContextMenu(e, messageEl, messageData) {
  const menu = $("contextMenu");
  state.contextMenuTarget = { el: messageEl, data: messageData };

  menu.style.left = `${e.pageX}px`;
  menu.style.top = `${e.pageY}px`;
  menu.classList.remove("hidden");

  const msgId = String(messageData.id || messageData.temp_id);
  const isFav = state.favorites.has(msgId);
  $("ctxFavorite").querySelector("span").textContent = isFav ? "Убрать из избранного" : "Избранное";
}

function hideContextMenu() {
  $("contextMenu").classList.add("hidden");
  state.contextMenuTarget = null;
}

function copyMessage() {
  if (!state.contextMenuTarget) return;

  const text = state.contextMenuTarget.el.textContent;
  navigator.clipboard.writeText(text).then(() => {
    toast("Скопировано ✓");
  });

  hideContextMenu();
}

function toggleFavorite() {
  if (!state.contextMenuTarget) return;

  const msgId = String(state.contextMenuTarget.data.id || state.contextMenuTarget.data.temp_id);
  const data = { ...state.favoritesData };

  if (state.favorites.has(msgId)) {
    state.favorites.delete(msgId);
    state.contextMenuTarget.el.classList.remove("favorite");
    delete data[msgId];
    toast("Удалено из избранного");
  } else {
    state.favorites.add(msgId);
    state.contextMenuTarget.el.classList.add("favorite");
    data[msgId] = {
      message: state.contextMenuTarget.data,
      savedAt: Date.now(),
      chatWith: state.activeTarget || "",
    };
    toast("Добавлено в избранное ⭐");
  }

  localStorage.setItem("niosmess_favorites", JSON.stringify([...state.favorites]));
  saveFavoritesData(data);
  if (state.activeTarget === FAVORITES_CHAT_ID) {
    renderFavoritesMessages();
  }
  hideContextMenu();
}

function deleteMessageLocal() {
  if (!state.contextMenuTarget) return;

  state.contextMenuTarget.el.style.animation = "fadeOut 0.3s ease forwards";

  setTimeout(() => {
    state.contextMenuTarget.el.remove();
    toast("Сообщение скрыто локально");
  }, 300);

  hideContextMenu();
}

function applyFormatToSelection(format) {
  if (!state.contextMenuTarget) return;

  const messageEl = state.contextMenuTarget.el;
  const textEl = messageEl.querySelector("span");

  if (!textEl) return;

  const selection = window.getSelection();
  const selectedText = selection.toString();

  if (!selectedText) {
    toast("Выделите текст для форматирования");
    hideContextMenu();
    return;
  }

  let formatted = "";

  switch(format) {
    case "bold":
      formatted = `**${selectedText}**`;
      break;
    case "italic":
      formatted = `*${selectedText}*`;
      break;
    case "code":
      formatted = `\`${selectedText}\``;
      break;
  }

  const input = $("messageInput");
  const currentValue = input.value;
  input.value = currentValue ? `${currentValue} ${formatted}` : formatted;
  input.focus();
  saveDraft();
  autoResize(input);

  toast("Добавлено в поле ввода");
  hideContextMenu();
}

async function searchUsers() {
  if (!state.session) return;

  const q = $("searchInput").value.trim();

  $("clearSearch").classList.toggle("hidden", !q);

  if (!q) {
    await loadChats({ silent: true });
    return;
  }

  try {
    const data = await apiFetch(
      `/search_users?q=${encodeURIComponent(q)}&token=${encodeURIComponent(state.session.token)}&my_username=${encodeURIComponent(state.session.username)}`,
      {},
      { silent: true }
    );
    renderChatList(Array.isArray(data) ? data : []);
  } catch {
    renderChatList([]);
  }
}

async function ping() {
  if (!state.session) return;

  try {
    await apiFetch("/ping", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username: state.session.username, token: state.session.token }),
    }, { silent: true });
  } catch {}
}

async function loadProfile() {
  if (!state.activeTarget || !state.session) return;

  try {
    const data = await apiFetch(
      `/get_user_info?username=${encodeURIComponent(state.activeTarget)}&token=${encodeURIComponent(state.session.token)}&my_username=${encodeURIComponent(state.session.username)}`,
      {},
      { silent: true }
    );

    $("profileAvatar").textContent = (data.name ? String(data.name)[0] : "?").toUpperCase();
    $("profileName").textContent = data.name || data.username || "—";
    $("profileUser").textContent = data.username ? `@${data.username}` : "";
    $("profileStatus").textContent = data.isfrozen ? "Заморожен" : (data.isonline ? "Онлайн" : "Оффлайн");
    $("profileMail").textContent = data.email || "—";
    $("profileDate").textContent = data.regdate || "—";
  } catch {}
}

function toggleProfile(force) {
  const panel = $("profilePanel");
  const mainView = $("appView");
  const show = typeof force === "boolean" ? force : !panel.classList.contains("show");

  panel.classList.toggle("show", show);

  if (show) {
    mainView.style.gridTemplateColumns = "420px 1fr 400px";
    loadProfile();
    if (state.profileTimer) clearInterval(state.profileTimer);
    state.profileTimer = setInterval(loadProfile, 3000);
  } else {
    mainView.style.gridTemplateColumns = "420px 1fr 0";
    if (state.profileTimer) clearInterval(state.profileTimer);
    state.profileTimer = null;
  }
}

function loadMyProfile() {
  const profile = JSON.parse(localStorage.getItem("niosmess_myprofile") || "{}");
  const username = state.session?.username || "user";

  applyAvatar($("myProfileAvatar"), (profile.name || username)[0].toUpperCase());
  $("myProfileName").value = profile.name || username;
  $("myProfileUsername").value = username;
  $("myProfileEmail").value = profile.email || "";
  $("myProfileBio").value = profile.bio || "";

  $("showOnlineStatus").checked = profile.showOnlineStatus !== false;
  $("showLastSeen").checked = profile.showLastSeen !== false;
  $("showTyping").checked = profile.showTyping !== false;
}

function saveMyProfile() {
  setButtonLoading("saveProfileBtn", true);

  const profile = {
    name: $("myProfileName").value.trim(),
    email: $("myProfileEmail").value.trim(),
    bio: $("myProfileBio").value.trim(),
    showOnlineStatus: $("showOnlineStatus").checked,
    showLastSeen: $("showLastSeen").checked,
    showTyping: $("showTyping").checked,
  };

  localStorage.setItem("niosmess_myprofile", JSON.stringify(profile));

  updateUserInfo();

  setTimeout(() => {
    setButtonLoading("saveProfileBtn", false);
    toast("Настройки сохранены ✓");
    closeMyProfile();
  }, 500);
}

function handleAvatarUpload(file) {
  if (!file) return;
  if (!file.type || !file.type.startsWith("image/")) {
    toast("Выберите изображение");
    return;
  }

  const reader = new FileReader();
  reader.onload = () => {
    const dataUrl = String(reader.result || "");
    if (!dataUrl) return;

    localStorage.setItem("niosmess_avatar", dataUrl);
    updateUserInfo();
    loadMyProfile();
    toast("Аватар обновлен ✓");
  };

  reader.readAsDataURL(file);
}

function updateUserInfo() {
  const username = state.session?.username || "user";
  const profile = JSON.parse(localStorage.getItem("niosmess_myprofile") || "{}");
  const name = profile.name || username;
  const initial = name[0].toUpperCase();

  const menuName = $("menuName");
  const menuUsername = $("menuUsername");
  const menuAvatar = $("menuAvatar");

  if (menuName) menuName.textContent = name;
  if (menuUsername) menuUsername.textContent = `@${username}`;
  if (menuAvatar) applyAvatar(menuAvatar, initial);
}

function openMyProfile() {
  loadMyProfile();
  setView("myProfile");
  closeSideMenu();
}

function closeMyProfile() {
  setView("app");
}

function openSideMenu() {
  const menu = $("sideMenu");
  menu.classList.remove("hidden");
  updateUserInfo();

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      menu.classList.add("menu-open");
    });
  });
}

function closeSideMenu() {
  const menu = $("sideMenu");

  menu.classList.remove("menu-open");

  setTimeout(() => {
    menu.classList.add("hidden");
  }, 400);
}

function initDragDrop() {
  const dropZone = $("dropZone");
  let dragCounter = 0;

  document.addEventListener("dragenter", (e) => {
    e.preventDefault();
    dragCounter++;
    if (state.activeTarget && dragCounter === 1) {
      dropZone.classList.remove("hidden");
      dropZone.classList.add("active");
    }
  });

  document.addEventListener("dragleave", () => {
    dragCounter--;
    if (dragCounter === 0) {
      dropZone.classList.remove("active");
      setTimeout(() => dropZone.classList.add("hidden"), 200);
    }
  });

  document.addEventListener("dragover", (e) => {
    e.preventDefault();
  });

  document.addEventListener("drop", (e) => {
    e.preventDefault();
    dragCounter = 0;
    dropZone.classList.remove("active");
    setTimeout(() => dropZone.classList.add("hidden"), 200);

    if (!state.activeTarget) return;

    const files = e.dataTransfer?.files;
    if (files && files.length > 0) {
      uploadFile(files[0]);
    }
  });
}

function autoResize(textarea) {
  textarea.style.height = "auto";
  textarea.style.height = Math.min(textarea.scrollHeight, 150) + "px";
}

function initApp() {
  setView("app");
  updateUserInfo();

  $("messageList").innerHTML = "";
  $("messagesEmpty").classList.remove("hidden");

  const inputWrapper = document.querySelector(".message-input-wrapper");
  inputWrapper.style.display = "none";

  loadChats({ silent: false });
  ping();

  stopTimers();
  state.syncTimer = setInterval(async () => {
    await ping();
    await loadChats({ silent: true });
    if (state.activeTarget) {
      await loadMessages({ silent: true });
    }
  }, 2000);
}

function initEvents() {

  $("authBtn").addEventListener("click", loginOrRegister);
  $("toggleAuthBtn").addEventListener("click", () => setAuthMode(!state.isRegister));

  [$("emailInput"), $("passwordInput"), $("usernameInput"), $("nameInput"), $("codeInput")].forEach(input => {
    input?.addEventListener("keydown", (e) => {
      if (e.key === "Enter") loginOrRegister();
    });
  });

  $("sendBtn").addEventListener("click", sendMessage);
  $("messageInput").addEventListener("input", (e) => {
    saveDraft();
    autoResize(e.target);
  });

  $("messageInput").addEventListener("keydown", (e) => {
    if (e.key === "Enter" && e.ctrlKey) {

      e.preventDefault();
      const pos = e.target.selectionStart;
      const val = e.target.value;
      e.target.value = val.substring(0, pos) + "\n" + val.substring(pos);
      e.target.selectionStart = e.target.selectionEnd = pos + 1;
      saveDraft();
      autoResize(e.target);
    } else if (e.key === "Enter" && !e.shiftKey && !e.ctrlKey) {

      e.preventDefault();
      sendMessage();
    }
  });

  $("attachBtn").addEventListener("click", () => $("fileInput").click());
  $("fileInput").addEventListener("change", (e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (file) uploadFile(file);
  });

  $("searchInput").addEventListener("input", () => {
    if (state.searchTimer) clearTimeout(state.searchTimer);
    state.searchTimer = setTimeout(searchUsers, 300);
  });

  $("clearSearch").addEventListener("click", () => {
    $("searchInput").value = "";
    $("clearSearch").classList.add("hidden");
    loadChats({ silent: true });
  });

  $("emojiBtn").addEventListener("click", (e) => {
    e.stopPropagation();
    toggleEmojiPicker();
  });

  $("ctxCopy").addEventListener("click", copyMessage);
  $("ctxFavorite").addEventListener("click", toggleFavorite);
  $("ctxDelete").addEventListener("click", deleteMessageLocal);
  $("ctxBold").addEventListener("click", () => applyFormatToSelection("bold"));
  $("ctxItalic").addEventListener("click", () => applyFormatToSelection("italic"));
  $("ctxCode").addEventListener("click", () => applyFormatToSelection("code"));

  document.addEventListener("click", (e) => {
    if (!$("contextMenu").contains(e.target)) {
      hideContextMenu();
    }

    const picker = $("emojiPicker");
    const emojiBtn = $("emojiBtn");

    if (!picker.contains(e.target) && e.target !== emojiBtn && !emojiBtn.contains(e.target)) {
      picker.classList.add("hidden");
    }
  });

  $("profileBtn").addEventListener("click", () => toggleProfile());
  $("closeProfileBtn").addEventListener("click", () => toggleProfile(false));
  $("chatAvatar").addEventListener("click", () => {
    if (!$("profileBtn").disabled) {
      toggleProfile(true);
    }
  });

  $("searchMessagesBtn").addEventListener("click", () => {
    const bar = $("messageSearchBar");
    if (bar.classList.contains("hidden")) {
      openMessageSearch();
    } else {
      closeMessageSearch();
    }
  });
  $("messageSearchInput").addEventListener("input", runMessageSearch);
  $("messageSearchPrev").addEventListener("click", () => stepMessageSearch(-1));
  $("messageSearchNext").addEventListener("click", () => stepMessageSearch(1));
  $("messageSearchClose").addEventListener("click", closeMessageSearch);
  $("messageSearchClear").addEventListener("click", () => {
    $("messageSearchInput").value = "";
    runMessageSearch();
    $("messageSearchInput").focus();
  });

  $("helpModalClose").addEventListener("click", closeHelpModal);
  $("helpModal").addEventListener("click", (e) => {
    if (e.target.classList.contains("help-modal-backdrop")) {
      closeHelpModal();
    }
  });

  $("backFromProfileBtn").addEventListener("click", closeMyProfile);
  $("saveProfileBtn").addEventListener("click", saveMyProfile);
  $("changeAvatarBtn").addEventListener("click", () => $("avatarInput").click());
  $("avatarInput").addEventListener("change", (e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    handleAvatarUpload(file);
  });

  document.querySelectorAll(".theme-card").forEach(card => {
    card.addEventListener("click", () => {
      const theme = card.dataset.theme;
      const accent = card.dataset.accent;

      saveSettings({ theme, accent });
      toast("Тема изменена ✓");
    });
  });

  $("menuBtn").addEventListener("click", openSideMenu);
  $("menuUserBtn").addEventListener("click", openMyProfile);
  $("settingsMenuBtn").addEventListener("click", openMyProfile);

  $("favoritesMenuBtn").addEventListener("click", () => {
    closeSideMenu();
    openFavoritesChat();
  });

  $("helpMenuBtn").addEventListener("click", () => {
    closeSideMenu();
    openHelpModal();
  });

  $("aboutMenuBtn").addEventListener("click", () => {
    closeSideMenu();
    toast("NiosMess Web v2.0 — Современный мессенджер 💬");
  });

  $("logoutBtn").addEventListener("click", () => {
    clearSession();
    setView("auth");
    toast("Вы вышли из аккаунта");
  });

  $("logoutMenuBtn").addEventListener("click", () => {
    clearSession();
    closeSideMenu();
    setView("auth");
    toast("До встречи! 👋");
  });

  const sideMenuEl = $("sideMenu");
  sideMenuEl.addEventListener("click", (e) => {
    if (e.target.classList.contains("side-menu-backdrop") || e.target === sideMenuEl) {
      closeSideMenu();
    }
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      closeSideMenu();
      hideContextMenu();
      $("emojiPicker").classList.add("hidden");
      closeMessageSearch();
      closeHelpModal();

      if ($("profilePanel").classList.contains("show")) {
        toggleProfile(false);
      }
    }
  });
}

async function boot() {
  showLoading();

  applySettings();
  initEvents();
  initDragDrop();
  initEmojiPicker();
  setAuthMode(false);
  setView("auth");

  await checkSession();

  setTimeout(() => hideLoading(), 300);
}

boot();
