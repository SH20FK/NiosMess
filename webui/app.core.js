const DEFAULT_API = "https://web.sa2rn.fun";

const $ = (id) => document.getElementById(id);

const DEVICE_PROFILE_KEY = "niosmess_device_profile";

const DEVICE_PROFILE_FILENAME = "niosmess_profile.json";

const REACTIONS_KEY = "niosmess_reactions";

const READ_STATE_KEY = "niosmess_read_state";

const OUTBOX_KEY = "niosmess_outbox";
const SCHEDULED_KEY = "niosmess_scheduled";
const POLLS_KEY = "niosmess_polls";
const MESSAGE_TTL_KEY = "niosmess_message_ttl";
const USER_INFO_CACHE_KEY = "niosmess_user_info_cache_v1";
const USER_INFO_CACHE_TTL = 24 * 60 * 60 * 1000;
const AVATAR_CACHE_NAME = "niosmess-avatar-cache-v1";



const FAVORITES_CHAT_ID = "__favorites__";

const DEFAULT_EMPTY_TITLE = "\u041f\u043e\u043a\u0430 \u0447\u0442\u043e \u0437\u0434\u0435\u0441\u044c \u043f\u0443\u0441\u0442\u043e\u0432\u0430\u0442\u043e";

const DEFAULT_EMPTY_SUBTITLE = "\u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u0447\u0430\u0442, \u0447\u0442\u043e\u0431\u044b \u043d\u0430\u0447\u0430\u0442\u044c \u043e\u0431\u0449\u0435\u043d\u0438\u0435";



const state = {

  apiBase: DEFAULT_API,

  session: null,

  isRegister: false,

  activeTarget: null,

  lastMsgId: -1,

  messages: [],

  messagesLoaded: false,
  messagesLoading: false,

  syncTimer: null,

  profileTimer: null,
  userInfoCache: {},
  userInfoTimestamps: {},
  userInfoPending: {},

  searchTimer: null,

  loadingCount: 0,

  rendering: false,

  contextMenuTarget: null,
  chatContextTarget: null,
  chatContextBound: false,

  favorites: new Set(JSON.parse(localStorage.getItem("niosmess_favorites") || "[]")),

  favoritesData: JSON.parse(localStorage.getItem("niosmess_favorites_data") || "{}"),

  messageSearchResults: [],

  messageSearchIndex: -1,

  messageSearchQuery: "",

  chatIndex: {},
  chatList: [],
  chatSearchActive: false,

  activeChatType: "user",

  pendingCreateType: null,

  pendingCreateAvatar: "",

  pendingCreateAvatarFile: null,

  chatMeta: JSON.parse(localStorage.getItem("niosmess_chat_meta") || "{}"),

  replyTo: null,

  editingMessage: null,

  forwardMessage: null,
  forwardTargets: new Set(),

  reactions: JSON.parse(localStorage.getItem(REACTIONS_KEY) || "{}"),

  readState: JSON.parse(localStorage.getItem(READ_STATE_KEY) || "{}"),

  inviteSelected: new Set(),
  outbox: (() => {
    try {
      const raw = localStorage.getItem(OUTBOX_KEY) || "[]";
      const data = JSON.parse(raw);
      return Array.isArray(data) ? data : [];
    } catch {
      return [];
    }
  })(),
  scheduled: (() => {
    try {
      const raw = localStorage.getItem(SCHEDULED_KEY) || "[]";
      const data = JSON.parse(raw);
      return Array.isArray(data) ? data : [];
    } catch {
      return [];
    }
  })(),
  polls: (() => {
    try {
      const raw = localStorage.getItem(POLLS_KEY) || "{}";
      const data = JSON.parse(raw);
      return data && typeof data === "object" ? data : {};
    } catch {
      return {};
    }
  })(),
  messageTTL: (() => {
    const value = Number(localStorage.getItem(MESSAGE_TTL_KEY));
    return Number.isFinite(value) && value > 0 ? value : 0;
  })(),
  mediaIndexCache: {},
  stickerSets: [],
  activeStickerSetId: null,
  gifResults: [],
  gifQuery: "",
  pickerTab: "emoji",
  favoritesMode: "auto",
  serverSearchActive: false,
  serverSearchCache: null,
  serverSearchResults: [],
  sessions: [],
  sessionsDisabled: false,

  typingTimer: null,
  remoteTypingTimer: null,

  typingBackup: null,

  voiceRecorder: null,

  ws: null,

  wsStatus: "offline",

  wsRetry: 0,

  wsConnectedAt: null,
  wsDisabled: false,
  wsFailures: 0,
  directReadDisabled: false,
  collectiveReadDisabled: false,
  expireTimers: {},
  scheduledTimer: null,

  settings: JSON.parse(localStorage.getItem("niosmess_settings") || '{"theme":"dark","accent":"blue","recentThemes":[],"reduceMotion":false,"compactMode":false,"linkPreviews":true,"notificationSound":true,"desktopNotifications":false,"notificationPreview":true,"draftsEnabled":true,"trimSpaces":true,"ghostMode":false,"interfaceScale":1,"interfaceScaleEnabled":false,"realtimeEnabled":false}'),

};

const utf8Decoder = new TextDecoder("utf-8");
const cp1251Decoder = (() => {
  try {
    return new TextDecoder("windows-1251");
  } catch {
    return null;
  }
})();

function loadUserInfoCache() {
  try {
    const raw = localStorage.getItem(USER_INFO_CACHE_KEY);
    if (!raw) return;
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return;
    const data = parsed.data || {};
    const timestamps = parsed.timestamps || {};
    const now = Date.now();
    Object.keys(data).forEach((key) => {
      const ts = timestamps[key];
      if (ts && now - ts < USER_INFO_CACHE_TTL) {
        state.userInfoCache[key] = data[key];
        state.userInfoTimestamps[key] = ts;
      }
    });
  } catch {}
}

function pruneUserInfoCache() {
  const now = Date.now();
  let changed = false;
  Object.keys(state.userInfoCache).forEach((key) => {
    const ts = state.userInfoTimestamps[key];
    if (!ts || now - ts > USER_INFO_CACHE_TTL) {
      delete state.userInfoCache[key];
      delete state.userInfoTimestamps[key];
      changed = true;
    }
  });
  if (changed) saveUserInfoCache();
}

function saveUserInfoCache() {
  try {
    localStorage.setItem(
      USER_INFO_CACHE_KEY,
      JSON.stringify({ data: state.userInfoCache, timestamps: state.userInfoTimestamps })
    );
  } catch {}
}

function clearProfileCache() {
  state.userInfoCache = {};
  state.userInfoTimestamps = {};
  try {
    localStorage.removeItem(USER_INFO_CACHE_KEY);
  } catch {}
}

loadUserInfoCache();

function mojibakeScore(text) {
  if (!text) return 0;
  const matches = text.match(/[РС]/g);
  const ratio = (matches ? matches.length : 0) / text.length;
  return ratio;
}

async function decodeResponseText(res) {
  const buffer = await res.arrayBuffer();
  const utf8Text = utf8Decoder.decode(buffer);
  if (!cp1251Decoder) return utf8Text;
  const utf8Score = mojibakeScore(utf8Text);
  if (utf8Score < 0.2) return utf8Text;
  const cpText = cp1251Decoder.decode(buffer);
  const cpScore = mojibakeScore(cpText);
  return cpScore < utf8Score ? cpText : utf8Text;
}



const obfMap = {
  "\u0410":"\u2622",
  "\u0411":"\u2b23",
  "\u0412":"\u2b1f",
  "\u0413":"\u2b22",
  "\u0414":"\u2725",
  "\u0415":"\u2738",
  "\u0401":"\u2726",
  "\u0416":"\u26a1",
  "\u0417":"\u2b25",
  "\u0418":"\u25ce",
  "\u0419":"\u273a",
  "\u041a":"\u260d",
  "\u041b":"\u2b24",
  "\u041c":"\u262f",
  "\u041d":"\u2691",
  "\u041e":"\u2699",
  "\u041f":"\u2b26",
  "\u0420":"\u2601",
  "\u0421":"\u2b27",
  "\u0422":"\u2716",
  "\u0423":"\u2b28",
  "\u0424":"\u2723",
  "\u0425":"\u260a",
  "\u0426":"\u2739",
  "\u0427":"\u272a",
  "\u0428":"\u2b29",
  "\u0429":"\u2736",
  "\u042a":"\u2349",
  "\u042b":"\u232c",
  "\u042c":"\u232b",
  "\u042d":"\u2737",
  "\u042e":"\u273f",
  "\u042f":"\u262e",
  "\u0430":"\u2620",
  "\u0431":"\u2b1e",
  "\u0432":"\u2b20",
  "\u0433":"\u2b21",
  "\u0434":"\u2727",
  "\u0435":"\u2731",
  "\u0451":"\u272b",
  "\u0436":"\u2694",
  "\u0437":"\u2b2a",
  "\u0438":"\u25c9",
  "\u0439":"\u273b",
  "\u043a":"\u260c",
  "\u043b":"\u2b2f",
  "\u043c":"\u2630",
  "\u043d":"\u2690",
  "\u043e":"\u2697",
  "\u043f":"\u2b2b",
  "\u0440":"\u2602",
  "\u0441":"\u29c8",
  "\u0442":"\u2715",
  "\u0443":"\u2b2d",
  "\u0444":"\u2724",
  "\u0445":"\u260b",
  "\u0446":"\u273e",
  "\u0447":"\u272f",
  "\u0448":"\u2b2e",
  "\u0449":"\u2735",
  "\u044a":"\u234a",
  "\u044b":"\u232d",
  "\u044c":"\u3009",
  "\u044d":"\u273c",
  "\u044e":"\u2740",
  "\u044f":"\u263e",
  "A":"\u2206",
  "B":"\u2211",
  "C":"\u2297",
  "D":"\u2202",
  "E":"\u2261",
  "F":"\u22a5",
  "G":"\u2207",
  "H":"\u2295",
  "I":"\u222b",
  "J":"\u2318",
  "K":"\u235f",
  "L":"\u2317",
  "M":"\u2394",
  "N":"\u2298",
  "O":"\u2299",
  "P":"\u2316",
  "Q":"\u232c\u0338",
  "R":"\u2387",
  "S":"\u233f",
  "T":"\u23da",
  "U":"\u238a",
  "V":"\u2338",
  "W":"\u2365",
  "X":"\u2a2f",
  "Y":"\u2360",
  "Z":"\u2362",
  "a":"\u2609",
  "b":"\u2b16",
  "c":"\u2b18",
  "d":"\u2722",
  "e":"\u2736\u0307",
  "f":"\u2b1b",
  "g":"\u2698",
  "h":"\u273a\u0307",
  "i":"\u2b19",
  "j":"\u2756",
  "k":"\u4e0b",
  "l":"\u2b1a",
  "m":"\u2690\u0307",
  "n":"\u2b22\u0307",
  "o":"\u2699\u0307",
  "p":"\u2b23\u0307",
  "q":"\u2727\u0307",
  "r":"\u51f9",
  "s":"\u2b25\u0307",
  "t":"\u2738\u0307",
  "u":"\u2b26\u0307",
  "v":"\u2737\u0307",
  "w":"\u2b27\u0307",
  "x":"\u2742",
  "y":"\u2726\u0307",
  "z":"\u2b28\u0307",
};



const revMap = new Map(Object.entries(obfMap).map(([k, v]) => [v, k]));
const obfTokens = Array.from(new Set(revMap.keys()))
  .filter((token) => token && token.length)
  .sort((a, b) => b.length - a.length);



function obfuscate(text) {

  let out = "";

  for (const ch of text) out += obfMap[ch] || ch;

  return out;

}



function deobfuscate(text) {
  let current = String(text ?? "");
  for (let pass = 0; pass < 2; pass += 1) {
    let out = "";
    let i = 0;
    while (i < current.length) {
      let matched = false;
      for (const token of obfTokens) {
        if (current.startsWith(token, i)) {
          out += revMap.get(token) || "";
          i += token.length;
          matched = true;
          break;
        }
      }
      if (!matched) {
        out += current[i];
        i += 1;
      }
    }
    if (out === current) break;
    current = out;
  }
  return current;
}



function setView(view) {

  const authView = $("authView");

  const appView = $("appView");

  const myProfileView = $("myProfileView");



  const hasAuthView = !!authView;

  if (authView) authView.classList.toggle("hidden", view !== "auth");

  if (appView) appView.classList.toggle("hidden", view !== "app" && !(view === "auth" && !hasAuthView));

  if (myProfileView) myProfileView.classList.toggle("hidden", view !== "myProfile");

  if (view !== "app") {
    document.body.classList.remove("mobile-chat-open");
  }

}

function setMobileChatOpen(open) {
  const isMobile = typeof window !== "undefined" && window.matchMedia
    ? window.matchMedia("(max-width: 900px)").matches
    : false;
  if (!isMobile) {
    document.body.classList.remove("mobile-chat-open");
    return;
  }
  document.body.classList.toggle("mobile-chat-open", !!open);
}



function toast(msg, duration = 3000) {
  const el = $("toast");
  if (!el) return;
  el.textContent = msg;
  el.classList.add("show");
  setTimeout(() => el.classList.remove("show"), duration);
}

const DEFAULT_BADGE_TEXT = "\u042d\u0442\u043e\u0442 \u0447\u0435\u043b\u043e\u0432\u0435\u043a \u044f\u0432\u043b\u044f\u0435\u0442\u0441\u044f \u0440\u0430\u0437\u0440\u0430\u0431\u043e\u0442\u0447\u0438\u043a\u043e\u043c \u0438\u043b\u0438 \u0441\u043f\u043e\u043d\u0441\u043e\u0440\u043e\u043c NiosMessa";
let activeBadgeTooltip = null;

function closeBadgeTooltip() {
  if (!activeBadgeTooltip) return;
  const tip = activeBadgeTooltip;
  activeBadgeTooltip = null;
  tip.classList.add("is-hiding");
  const remove = () => {
    tip.remove();
  };
  tip.addEventListener("transitionend", remove, { once: true });
  tip.addEventListener("animationend", remove, { once: true });
  setTimeout(remove, 420);
}

  function openBadgeTooltip(target, text) {
    if (!target) return;
    const existingAnchor = activeBadgeTooltip?.dataset?.anchorId;
    const anchorId = target.dataset.badgeAnchor || "";
    if (activeBadgeTooltip && existingAnchor && anchorId && existingAnchor === anchorId) {
      closeBadgeTooltip();
      return;
    }
    closeBadgeTooltip();
    const tip = document.createElement("div");
    tip.className = "badge-tooltip";
    tip.textContent = text || DEFAULT_BADGE_TEXT;
    tip.dataset.anchorId = anchorId;
    document.body.appendChild(tip);
    const place = () => {
      const rect = target.getBoundingClientRect();
      const tipRect = tip.getBoundingClientRect();
      const margin = 10;
      const centerX = rect.left + rect.width / 2;
      let left = rect.left + rect.width / 2 - tipRect.width / 2;
      let top = rect.bottom + 10;
      if (left < margin) left = margin;
      if (left + tipRect.width > window.innerWidth - margin) {
        left = window.innerWidth - margin - tipRect.width;
      }
      if (top + tipRect.height > window.innerHeight - margin) {
        top = rect.top - tipRect.height - 10;
      }
      const arrowX = Math.min(
        Math.max(centerX - left, 12),
        tipRect.width - 12
      );
      tip.style.left = `${left}px`;
      tip.style.top = `${top}px`;
      tip.style.setProperty("--badge-arrow-x", `${arrowX}px`);
    };
  requestAnimationFrame(place);
  activeBadgeTooltip = tip;
}

document.addEventListener("click", (e) => {
  if (!activeBadgeTooltip) return;
  if (e.target.closest(".user-badge") || e.target.closest(".badge-tooltip")) return;
  closeBadgeTooltip();
});
window.addEventListener("resize", closeBadgeTooltip);
window.addEventListener("scroll", closeBadgeTooltip, true);

function getBadgeData(user, cached) {
  const source = user?.badge_id ? user : (cached?.badge_id ? cached : null);
  if (!source) return null;
  return {
    id: source.badge_id,
    text: source.badge_text || DEFAULT_BADGE_TEXT,
    title: source.badge_title || "",
    icon: source.badge_icon || "fox",
  };
}

function renderNameWithBadge(targetEl, name, badge) {
  if (!targetEl) return;
  targetEl.classList.add("has-badge");
  targetEl.textContent = "";
  const textSpan = document.createElement("span");
  textSpan.className = "name-text";
  textSpan.textContent = name || "";
  targetEl.appendChild(textSpan);
  if (!badge) return;
  const span = document.createElement("span");
  span.className = `user-badge user-badge-${badge.icon || "fox"}`;
  span.title = badge.title || "";
  span.dataset.badgeAnchor = `${badge.id || "badge"}-${Math.random().toString(36).slice(2, 8)}`;
  span.addEventListener("click", (e) => {
    e.stopPropagation();
    openBadgeTooltip(span, badge.text || DEFAULT_BADGE_TEXT);
  });
  targetEl.appendChild(span);
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



function getChatMeta(chatId) {

  return state.chatMeta[String(chatId)] || null;

}



function saveChatMeta(chatId, data) {

  if (!chatId) return;

  state.chatMeta[String(chatId)] = { ...(state.chatMeta[String(chatId)] || {}), ...(data || {}) };

  localStorage.setItem("niosmess_chat_meta", JSON.stringify(state.chatMeta));

}

function isChatPinned(chatId) {
  if (!chatId) return false;
  const meta = getChatMeta(chatId);
  return !!meta?.pinnedChat;
}

function updatePinChatButton() {
  const btn = $("pinChatBtn");
  if (!btn) return;
  const canPin = !!state.activeTarget && state.activeTarget !== FAVORITES_CHAT_ID;
  const pinned = canPin && isChatPinned(state.activeTarget);
  btn.disabled = !canPin;
  btn.classList.toggle("active", !!pinned);
  btn.title = pinned
    ? "\u041e\u0442\u043a\u0440\u0435\u043f\u0438\u0442\u044c \u0447\u0430\u0442"
    : "\u0417\u0430\u043a\u0440\u0435\u043f\u0438\u0442\u044c \u0447\u0430\u0442";
}

function toggleChatPinned(chatId, force) {
  if (!chatId) return;
  const meta = getChatMeta(chatId) || {};
  const next = typeof force === "boolean" ? force : !meta.pinnedChat;
  saveChatMeta(chatId, { pinnedChat: !!next });
  updatePinChatButton();
  if (Array.isArray(state.chatList)) {
    renderChatList(state.chatList);
  }
}



function saveFavoritesData(data) {

  state.favoritesData = data;

  localStorage.setItem("niosmess_favorites_data", JSON.stringify(data));

}



function saveReactions() {

  try {

    localStorage.setItem(REACTIONS_KEY, JSON.stringify(state.reactions));

  } catch (e) {

    console.warn("Failed to save reactions:", e);

  }

}



function getReactions(msgId) {

  return state.reactions[String(msgId)] || { counts: {}, mine: {} };

}

function applyReactionsFromMessage(message) {

  if (!message) return;

  const msgId = message.id || message.temp_id;

  if (msgId === undefined || msgId === null) return;

  let counts = {};

  let mine = {};

  const raw = message.reactions || message.reaction_counts || message.reactions_count || message.reaction;

  if (Array.isArray(raw)) {

    raw.forEach((item) => {

      const emoji = item.emoji || item.key || item.reaction;

      const count = Number(item.count ?? item.value ?? item.total ?? 0);

      if (emoji) counts[emoji] = count;

    });

  } else if (raw && typeof raw === "object") {

    Object.keys(raw).forEach((emoji) => {

      const count = Number(raw[emoji]);

      if (Number.isFinite(count) && count > 0) counts[emoji] = count;

    });

  }

  const mineRaw = message.my_reactions || message.reactions_mine || message.my_reaction;

  if (Array.isArray(mineRaw)) {

    mineRaw.forEach((emoji) => {

      if (emoji) mine[String(emoji)] = true;

    });

  } else if (mineRaw && typeof mineRaw === "object") {

    Object.keys(mineRaw).forEach((emoji) => {

      if (mineRaw[emoji]) mine[emoji] = true;

    });

  }

  if (!Object.keys(counts).length && !Object.keys(mine).length) return;

  state.reactions[String(msgId)] = { counts, mine };

  saveReactions();

}



function toggleReaction(msgId, emoji) {

  const key = String(msgId);

  const data = getReactions(key);

  const counts = { ...data.counts };

  const mine = { ...data.mine };
  const prevState = {
    counts: { ...data.counts },
    mine: { ...data.mine },
  };



  if (mine[emoji]) {

    delete mine[emoji];

    counts[emoji] = Math.max(0, (counts[emoji] || 1) - 1);

    if (counts[emoji] === 0) delete counts[emoji];

  } else {

    mine[emoji] = true;

    counts[emoji] = (counts[emoji] || 0) + 1;

  }



  state.reactions[key] = { counts, mine };

  saveReactions();
  if (typeof updateMessageReactions === "function") {
    updateMessageReactions(key);
  }
  syncReactionWithServer(key, emoji, !!mine[emoji], prevState);

}

async function syncReactionWithServer(msgId, emoji, active, prevState) {

  if (!state.session || !state.activeTarget) return;

  const safeId = String(msgId);

  if (!safeId || safeId.startsWith("temp_") || safeId.startsWith("loc_")) return;

  const chatType = state.activeChatType || "user";

  const endpoint = chatType === "user" ? "/messages/react" : "/collective/react";

  try {

    const data = await apiFetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        token: state.session.token,
        username: state.session.username,
        chat_id: state.activeTarget,
        chat_type: chatType,
        message_id: safeId,
        emoji,
        active: !!active,
        action: active ? "add" : "remove",
      }),
    }, { silent: true });

    if (data && (data.counts || data.reactions)) {
      const nextCounts = data.counts || data.reactions || {};
      const nextMine = data.mine || data.my_reactions || state.reactions[safeId]?.mine || {};
      state.reactions[safeId] = { counts: nextCounts, mine: nextMine };
      saveReactions();
      if (typeof updateMessageReactions === "function") {
        updateMessageReactions(safeId);
      }
    }
  } catch {
    if (prevState) {
      state.reactions[safeId] = prevState;
      saveReactions();
      if (typeof updateMessageReactions === "function") {
        updateMessageReactions(safeId);
      }
    }
  }

}



function saveReadState() {

  try {

    localStorage.setItem(READ_STATE_KEY, JSON.stringify(state.readState));

  } catch (e) {

    console.warn("Failed to save read state:", e);

  }

}







async function markCollectiveRead(chatId) {

  if (!state.session || !chatId || state.collectiveReadDisabled) return;

  const form = new FormData();

  form.append("chat_id", chatId);

  form.append("username", state.session.username);

  form.append("token", state.session.token);

  try {

    await apiFetch("/collective/mark_read", { method: "POST", body: form }, { silent: true });

  } catch (err) {
    if (err && err.status === 404) state.collectiveReadDisabled = true;
  }

}

async function markDirectRead(chatId, lastId) {

  if (!state.session || !chatId || state.directReadDisabled) return;

  const form = new FormData();

  form.append("chat_id", chatId);

  form.append("username", state.session.username);

  form.append("token", state.session.token);

  if (lastId) form.append("last_id", lastId);

  try {

    await apiFetch("/mark_read", { method: "POST", body: form }, { silent: true });

  } catch (err) {
    if (err && err.status === 404) state.directReadDisabled = true;
  }

}

function formatMessageTime(value) {

  if (!value) return "";

  const date = typeof value === "number" ? new Date(value) : new Date(value);

  if (Number.isNaN(date.getTime())) return "";

  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });

}



function formatDuration(seconds) {

  if (!Number.isFinite(seconds)) return "";

  const total = Math.max(0, Math.round(seconds));

  const mins = Math.floor(total / 60);

  const secs = String(total % 60).padStart(2, "0");

  return `${mins}:${secs}`;

}

function formatBytes(bytes) {
  const value = Number(bytes);
  if (!Number.isFinite(value) || value <= 0) return "";
  const units = ["B", "KB", "MB", "GB"];
  let size = value;
  let unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  const digits = size >= 100 || unitIndex === 0 ? 0 : size >= 10 ? 1 : 2;
  return `${size.toFixed(digits)} ${units[unitIndex]}`;
}



function buildDeviceProfileData() {

  let session = state.session;

  if (!session) {

    try {

      session = JSON.parse(localStorage.getItem("niosmess_session") || "null");

    } catch (e) {

      session = null;

    }

  }

  const settings = state.settings || {};

  return {

    token: session?.token || "",

    username: session?.username || "",

    theme: settings.theme || "dark",

    accent: settings.accent || "blue",

    savedAt: new Date().toISOString(),

  };

}



function persistDeviceProfileLocal() {

  const data = buildDeviceProfileData();

  if (!data.token && !data.username) return;

  try {

    localStorage.setItem(DEVICE_PROFILE_KEY, JSON.stringify(data));

  } catch (e) {

    console.warn("Failed to save device profile:", e);

  }

}



function downloadJsonFile(filename, json) {

  const blob = new Blob([json], { type: "application/json" });

  const url = URL.createObjectURL(blob);

  const link = document.createElement("a");

  link.href = url;

  link.download = filename;

  document.body.appendChild(link);

  link.click();

  link.remove();

  URL.revokeObjectURL(url);

}


async function apiFetchFirst(paths, options = {}, apiOptions = {}) {

  let lastError = null;

  for (const path of paths) {

    try {

      return await apiFetch(path, options, apiOptions);

    } catch (err) {

      lastError = err;

      if (!err || err.status !== 404) {

        break;

      }

    }

  }

  throw lastError || new Error("Request failed");

}


function formatSessionTime(value) {

  if (!value) return "";

  let date = null;

  if (typeof value === "number") {

    date = new Date(value);

  } else if (typeof value === "string") {

    const numeric = Number(value);

    date = Number.isFinite(numeric) ? new Date(numeric) : new Date(value);

  }

  if (!date || Number.isNaN(date.getTime())) return "";

  return date.toLocaleString();

}


function renderSessionsList(list = []) {

  const container = $("sessionsList");

  if (!container) return;

  container.innerHTML = "";


  if (!Array.isArray(list) || list.length === 0) {

    const empty = document.createElement("div");

    empty.className = "device-current";

    empty.textContent = "\u041d\u0435\u0442 \u0430\u043a\u0442\u0438\u0432\u043d\u044b\u0445 \u0441\u0435\u0441\u0441\u0438\u0439";

    container.appendChild(empty);

    return;

  }


  list.forEach((session) => {

    const item = document.createElement("div");

    item.className = "device-item";


    const info = document.createElement("div");

    info.className = "device-info";


    const title = document.createElement("div");

    title.className = "device-title";

    title.textContent = session.device || session.name || session.title || "Session";


    const meta = document.createElement("div");

    meta.className = "device-meta";

    const parts = [];

    const ip = session.ip || session.ip_address;

    const agent = session.agent || session.user_agent || session.ua;

    const lastActive = session.last_active || session.lastActive || session.updated_at;

    const created = session.created_at || session.createdAt;

    if (ip) parts.push(ip);

    if (agent) parts.push(String(agent).slice(0, 60));

    const lastText = formatSessionTime(lastActive);

    const createdText = formatSessionTime(created);

    if (lastText) parts.push(`Last \u0430\u043a\u0442\u0438\u0432\u043d\u043e\u0441\u0442\u044c: ${lastText}`);

    if (createdText) parts.push(`\u0421\u043e\u0437\u0434\u0430\u043d\u043e: ${createdText}`);

    meta.textContent = parts.filter(Boolean).join(" \u2022 ");


    info.appendChild(title);

    info.appendChild(meta);

    item.appendChild(info);


    const actions = document.createElement("div");

    actions.className = "device-actions";

    if (session.current || session.is_current || session.isCurrent) {

      const current = document.createElement("div");

      current.className = "device-current";

      current.textContent = "\u042d\u0442\u043e \u0432\u0430\u0448\u0430 \u0441\u0435\u0441\u0441\u0438\u044f";

      actions.appendChild(current);

    }

    item.appendChild(actions);

    container.appendChild(item);

  });

}


async function loadSessions({ silent = false } = {}) {

  if (!state.session) return;

  const params = new URLSearchParams({

    username: state.session.username,

    token: state.session.token,

  }).toString();


  try {

    const data = await apiFetchFirst(

      [

        `/get_sessions?${params}`,

        `/sessions?${params}`,

        `/list_sessions?${params}`,

        `/devices?${params}`,

      ],

      {},

      { silent }

    );

    const list = Array.isArray(data) ? data : Array.isArray(data?.sessions) ? data.sessions : [];

    state.sessions = list;

    renderSessionsList(list);

  } catch (err) {

    state.sessions = [];

    renderSessionsList([]);

    if (!silent) toast("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c \u0441\u0435\u0441\u0441\u0438\u0438");

  }

}


async function logoutOtherSessions() {

  if (!state.session) return;

  const payload = {

    username: state.session.username,

    token: state.session.token,

    mode: "other",

  };


  try {

    await apiFetchFirst(

      [

        "/logout_other_sessions",

        "/logout_sessions",

        "/sessions/logout_other",

        "/sessions/logout_all",

      ],

      {

        method: "POST",

        headers: { "Content-Type": "application/json" },

        body: JSON.stringify(payload),

      },

      { silent: false }

    );

    toast("\u0414\u0440\u0443\u0433\u0438\u0435 \u0441\u0435\u0441\u0441\u0438\u0438 \u0437\u0430\u0432\u0435\u0440\u0448\u0435\u043d\u044b");

    await loadSessions({ silent: true });

  } catch (err) {

    toast("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0432\u044b\u0439\u0442\u0438 \u043d\u0430 \u0434\u0440\u0443\u0433\u0438\u0445 \u0443\u0441\u0442\u0440\u043e\u0439\u0441\u0442\u0432\u0430\u0445");

  }

}



async function exportDeviceProfile() {

  const data = buildDeviceProfileData();

  if (!data.token || !data.username) {

    toast("\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u0432\u043e\u0439\u0434\u0438\u0442\u0435 \u0432 \u0430\u043a\u043a\u0430\u0443\u043d\u0442.");

    return;

  }



  persistDeviceProfileLocal();

  const json = JSON.stringify(data, null, 2);



  if (window.showSaveFilePicker) {

    try {

      const handle = await window.showSaveFilePicker({

        suggestedName: DEVICE_PROFILE_FILENAME,

        types: [

          { description: "JSON", accept: { "application/json": [".json"] } },

        ],

      });

      const writable = await handle.createWritable();

      await writable.write(json);

      await writable.close();

      toast("\u0424\u0430\u0439\u043b \u0441\u043e\u0445\u0440\u0430\u043d\u0451\u043d.");

    } catch (err) {

      if (err && err.name !== "AbortError") {

        console.warn("Failed to save file:", err);

        toast("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0441\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c \u0444\u0430\u0439\u043b.");

      }

    }

    return;

  }



  downloadJsonFile(DEVICE_PROFILE_FILENAME, json);

  toast("\u0424\u0430\u0439\u043b \u0441\u043e\u0445\u0440\u0430\u043d\u0451\u043d.");

}



function showError(msg) {

  const el = $("authError");

  if (!el) return;

  el.textContent = msg;

  el.classList.remove("hidden");

}



function clearError() {

  const el = $("authError");

  if (!el) return;

  el.classList.add("hidden");

  el.textContent = "";

}



function showLoading() {

  state.loadingCount++;

  const overlay = $("loadingOverlay");

  if (overlay) overlay.classList.remove("is-hidden");

}



function hideLoading() {

  state.loadingCount = Math.max(0, state.loadingCount - 1);

  if (state.loadingCount === 0) {

    const overlay = $("loadingOverlay");

    if (overlay) overlay.classList.add("is-hidden");

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

function getThemeKey(theme, accent) {
  return `${theme || "dark"}:${accent || "blue"}`;
}

function getRecentThemes(settings) {
  const list = Array.isArray(settings?.recentThemes) ? settings.recentThemes : [];
  return list.filter(item => item && item.theme && item.accent);
}

function sortThemeCardsByRecent() {
  const track = $("themeTrack") || document.querySelector(".theme-track") || document.querySelector(".theme-grid");
  if (!track) return;

  const cards = Array.from(track.querySelectorAll(".theme-card"));
  if (!cards.length) return;

  cards.forEach((card, idx) => {
    if (!card.dataset.order) {
      card.dataset.order = String(idx);
    }
  });

  const settings = state.settings || {};
  const currentTheme = settings.theme || "dark";
  const currentAccent = settings.accent || "blue";
  const currentKey = getThemeKey(currentTheme, currentAccent);

  let recent = getRecentThemes(settings);
  if (!recent.find(item => getThemeKey(item.theme, item.accent) === currentKey)) {
    recent = [{ theme: currentTheme, accent: currentAccent }, ...recent];
  }

  const recentKeys = recent.map(item => getThemeKey(item.theme, item.accent));

  cards.sort((a, b) => {
    const keyA = getThemeKey(a.dataset.theme, a.dataset.accent);
    const keyB = getThemeKey(b.dataset.theme, b.dataset.accent);
    const idxA = recentKeys.indexOf(keyA);
    const idxB = recentKeys.indexOf(keyB);

    if (idxA === -1 && idxB === -1) {
      return Number(a.dataset.order || 0) - Number(b.dataset.order || 0);
    }
    if (idxA === -1) return 1;
    if (idxB === -1) return -1;
    return idxA - idxB;
  });

  cards.forEach(card => track.appendChild(card));

  const viewport = document.querySelector(".theme-viewport");
  if (viewport) viewport.scrollLeft = 0;
}

function updateThemeCarouselNav() {
  const viewport = document.querySelector(".theme-viewport");
  const track = $("themeTrack") || document.querySelector(".theme-track") || document.querySelector(".theme-grid");
  const prev = $("themePrevBtn");
  const next = $("themeNextBtn");
  if (!viewport || !track || !prev || !next) return;

  const maxScroll = track.scrollWidth - viewport.clientWidth;
  const atStart = viewport.scrollLeft <= 2;
  const atEnd = viewport.scrollLeft >= maxScroll - 2 || maxScroll <= 0;

  prev.classList.toggle("is-disabled", atStart);
  next.classList.toggle("is-disabled", atEnd);
}

function initThemeCarousel() {
  const viewport = document.querySelector(".theme-viewport");
  const track = $("themeTrack") || document.querySelector(".theme-track") || document.querySelector(".theme-grid");
  const prev = $("themePrevBtn");
  const next = $("themeNextBtn");
  if (!viewport || !track || !prev || !next) return;

  const scrollByPage = (dir) => {
    const card = track.querySelector(".theme-card");
    if (!card) return;
    const style = getComputedStyle(track);
    const gapValue = Number.parseFloat(style.columnGap || style.gap || "0") || 12;
    const cardWidth = card.getBoundingClientRect().width;
    const carousel = viewport.closest(".theme-carousel");
    const visible = carousel ? Number.parseFloat(getComputedStyle(carousel).getPropertyValue("--theme-visible")) : 3;
    const count = Number.isFinite(visible) && visible > 0 ? visible : 3;
    const step = (cardWidth + gapValue) * count;
    viewport.scrollBy({ left: step * dir, behavior: "smooth" });
  };

  prev.addEventListener("click", () => scrollByPage(-1));
  next.addEventListener("click", () => scrollByPage(1));
  viewport.addEventListener("scroll", () => {
    requestAnimationFrame(updateThemeCarouselNav);
  });
  window.addEventListener("resize", updateThemeCarouselNav);

  sortThemeCardsByRecent();
  updateThemeCarouselNav();
}



function applySettings() {

  const settings = state.settings;



  document.documentElement.setAttribute("data-theme", settings.theme || "dark");

  document.documentElement.setAttribute("data-accent", settings.accent || "blue");

  document.documentElement.setAttribute("data-reduce-motion", settings.reduceMotion ? "true" : "false");

  document.documentElement.setAttribute("data-density", settings.compactMode ? "compact" : "normal");

  document.documentElement.setAttribute("data-ghost", settings.ghostMode ? "true" : "false");

  const scale = settings.interfaceScaleEnabled ? (settings.interfaceScale || 1) : 1;

  document.documentElement.style.setProperty("--ui-scale", String(scale));

  sortThemeCardsByRecent();



  document.querySelectorAll(".theme-card").forEach(card => {

    const theme = card.dataset.theme;

    const accent = card.dataset.accent;

    card.classList.toggle("active",

      theme === (settings.theme || "dark") && accent === (settings.accent || "blue")

    );

  });

  updateThemeCarouselNav();



  const reduceMotionToggle = $("reduceMotionToggle");

  if (reduceMotionToggle) reduceMotionToggle.checked = !!settings.reduceMotion;

  const compactModeToggle = $("compactModeToggle");

  if (compactModeToggle) compactModeToggle.checked = !!settings.compactMode;

  const linkPreviewsToggle = $("linkPreviewsToggle");

  if (linkPreviewsToggle) linkPreviewsToggle.checked = settings.linkPreviews !== false;

  const notificationSoundToggle = $("notificationSoundToggle");

  if (notificationSoundToggle) notificationSoundToggle.checked = settings.notificationSound !== false;

  const desktopNotificationsToggle = $("desktopNotificationsToggle");

  if (desktopNotificationsToggle) desktopNotificationsToggle.checked = !!settings.desktopNotifications;

  const notificationPreviewToggle = $("notificationPreviewToggle");

  if (notificationPreviewToggle) notificationPreviewToggle.checked = settings.notificationPreview !== false;

  const draftsToggle = $("draftsToggle");

  if (draftsToggle) draftsToggle.checked = settings.draftsEnabled !== false;

  const trimSpacesToggle = $("trimSpacesToggle");

  if (trimSpacesToggle) trimSpacesToggle.checked = settings.trimSpaces !== false;

  const nightModeToggle = $("nightModeToggle");

  if (nightModeToggle) nightModeToggle.checked = (settings.theme || "dark") === "dark";

  const ghostModeToggle = $("ghostModeToggle");

  if (ghostModeToggle) ghostModeToggle.checked = !!settings.ghostMode;

  const interfaceScaleToggle = $("interfaceScaleToggle");

  if (interfaceScaleToggle) interfaceScaleToggle.checked = !!settings.interfaceScaleEnabled;

  const interfaceScaleRange = $("interfaceScaleRange");

  const interfaceScaleValue = $("interfaceScaleValue");

  if (interfaceScaleRange) {

    const percent = Math.round((settings.interfaceScale || 1) * 100);

    interfaceScaleRange.value = String(percent);

    if (interfaceScaleValue) interfaceScaleValue.textContent = `${percent}%`;

  }

}



function saveSettings(updates) {

  const next = { ...state.settings, ...updates };
  if ("theme" in updates || "accent" in updates) {
    const theme = next.theme || "dark";
    const accent = next.accent || "blue";
    const existing = getRecentThemes(next);
    const filtered = existing.filter(item => getThemeKey(item.theme, item.accent) !== getThemeKey(theme, accent));
    next.recentThemes = [{ theme, accent }, ...filtered].slice(0, 12);
  }

  state.settings = next;

  localStorage.setItem("niosmess_settings", JSON.stringify(state.settings));

  persistDeviceProfileLocal();

  applySettings();

}



function selectSettingsTab(tabId = "account") {

  const tabs = document.querySelectorAll(".settings-tab");

  const sections = document.querySelectorAll(".tg-settings-section[data-tab]");

  const actions = document.querySelectorAll(".settings-actions[data-tab]");



  tabs.forEach((tab) => {

    tab.classList.toggle("active", tab.dataset.tab === tabId);

  });



  sections.forEach((section) => {

    section.classList.toggle("active", section.dataset.tab === tabId);

  });



  actions.forEach((action) => {

    action.classList.toggle("active", action.dataset.tab === tabId);

  });


}



function initSettingsTabs() {

  const tabs = document.querySelectorAll(".settings-tab");

  if (!tabs.length) return;



  tabs.forEach((tab) => {

    tab.addEventListener("click", () => {

      selectSettingsTab(tab.dataset.tab);

    });

  });



    selectSettingsTab("account");
    requestAnimationFrame(() => document.documentElement.classList.add("settings-ready"));

}



function initSettingsToggles() {

  $("reduceMotionToggle")?.addEventListener("change", (e) => {

    saveSettings({ reduceMotion: e.target.checked });

  });

  $("compactModeToggle")?.addEventListener("change", (e) => {

    saveSettings({ compactMode: e.target.checked });

  });

  $("linkPreviewsToggle")?.addEventListener("change", (e) => {

    saveSettings({ linkPreviews: e.target.checked });

  });

  $("notificationSoundToggle")?.addEventListener("change", (e) => {

    saveSettings({ notificationSound: e.target.checked });

  });

  $("desktopNotificationsToggle")?.addEventListener("change", (e) => {

    saveSettings({ desktopNotifications: e.target.checked });

  });

  $("notificationPreviewToggle")?.addEventListener("change", (e) => {

    saveSettings({ notificationPreview: e.target.checked });

  });

  $("draftsToggle")?.addEventListener("change", (e) => {

    saveSettings({ draftsEnabled: e.target.checked });

  });

  $("trimSpacesToggle")?.addEventListener("change", (e) => {

    saveSettings({ trimSpaces: e.target.checked });

  });

  $("nightModeToggle")?.addEventListener("change", (e) => {

    saveSettings({ theme: e.target.checked ? "dark" : "light" });

  });

  $("ghostModeToggle")?.addEventListener("change", (e) => {

    saveSettings({ ghostMode: e.target.checked });

  });

  $("interfaceScaleToggle")?.addEventListener("change", (e) => {

    saveSettings({ interfaceScaleEnabled: e.target.checked });

  });

  $("interfaceScaleRange")?.addEventListener("input", (e) => {

    const val = Number(e.target.value || 100) / 100;

    const scaleValue = $("interfaceScaleValue");

    if (scaleValue) scaleValue.textContent = `${Math.round(val * 100)}%`;

    saveSettings({ interfaceScale: val });

  });

}



async function apiFetch(path, options = {}, { silent = false, timeout = 12000 } = {}) {

  const url = `${state.apiBase}${path}`;

  if (!silent) showLoading();

  const controller = options.signal ? null : new AbortController();

  const signal = options.signal || controller?.signal;

  const timeoutId = controller ? setTimeout(() => controller.abort(), timeout) : null;



  try {

    const res = await fetch(url, { ...options, signal });



    if (!res.ok) {

      let data = {};

      try {

        const errorText = await decodeResponseText(res);
        data = errorText ? JSON.parse(errorText) : {};

      } catch {}

      const msg = data.detail || data.error || `Server error (${res.status})`;

      const err = new Error(msg);

      err.status = res.status;

      err.data = data;

      throw err;

    }



    const text = await decodeResponseText(res);

    return text ? JSON.parse(text) : {};

  } catch (err) {

    if (err && err.name === "AbortError") {

      throw new Error("Server is not responding. Please try again.");

    }

    throw err;

  } finally {

    if (timeoutId) clearTimeout(timeoutId);

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
    let data = null;
    if (mode === "login") {
      const form = new FormData();
      const loginId = payload.username || payload.email;
      form.append("username", loginId);
      form.append("password", payload.password);
      data = await apiFetch(`/${mode}`, {
        method: "POST",
        body: form,
      });
    } else {
      data = await apiFetch(`/${mode}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
    }



    if (data.status === "wait_code") {

      $("codeField").classList.remove("hidden");

      $("authBtn").querySelector(".btn-text").textContent = "";

      toast("\u041a\u043e\u0434 \u043e\u0442\u043f\u0440\u0430\u0432\u043b\u0435\u043d \u043d\u0430 email");

      return;

    }



    if (data.token) {

      saveSession({ token: data.token, username: data.username || payload.username });

      initApp();

      return;

    }



    if (data.status === "ok") {

      const token = data.token || data.access_token || "";

      if (!token) throw new Error("\u0421\u0435\u0440\u0432\u0435\u0440 \u043d\u0435 \u0432\u0435\u0440\u043d\u0443\u043b token");

      saveSession({ token, username: data.username || payload.username });

      initApp();

      return;

    }



    throw new Error("\u041d\u0435\u043e\u0436\u0438\u0434\u0430\u043d\u043d\u044b\u0439 \u043e\u0442\u0432\u0435\u0442 \u0441\u0435\u0440\u0432\u0435\u0440\u0430");

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

    window.location.href = "onboarding.html";

    return;

  }



  try {

    const data = JSON.parse(raw);

    if (!data.token || !data.username) {

      hideLoading();

      return;

    }



    showLoading();

    const res = await apiFetch(

      "/check_session",

      {

        method: "POST",

        headers: { "Content-Type": "application/json" },

        body: JSON.stringify({ token: data.token, username: data.username }),

      },

      { silent: true, timeout: 8000 }

    );



    if (res.status === "ok" || res.token || res.username) {

      saveSession({ ...data, ...res });

      initApp();

      return;

    }



    localStorage.removeItem("niosmess_session");

    window.location.href = "onboarding.html";

  } catch (err) {

    console.warn("check_session failed:", err);

    const rawData = localStorage.getItem("niosmess_session");

    if (rawData) {

      try {

        saveSession(JSON.parse(rawData));

        initApp();

      } catch {}

    }

  } finally {

    hideLoading();

  }

}



function saveSession(data) {

  state.session = data;
  state.wsDisabled = false;
  state.wsFailures = 0;
  state.directReadDisabled = false;
  state.collectiveReadDisabled = false;
  state.sessionsDisabled = false;

  localStorage.setItem("niosmess_session", JSON.stringify(data));

  persistDeviceProfileLocal();

}



function stopTimers() {

  if (state.syncTimer) clearInterval(state.syncTimer);

  state.syncTimer = null;



  if (state.profileTimer) clearInterval(state.profileTimer);

  state.profileTimer = null;

}



function clearSession() {

  stopTimers();
  if (typeof stopRealtime === "function") stopRealtime();

  state.session = null;

  state.activeTarget = null;

  state.messages = [];

  state.lastMsgId = -1;

  state.messagesLoaded = false;

  localStorage.removeItem("niosmess_session");

}



function setAuthMode(isRegister) {

  state.isRegister = isRegister;



  const authTitle = $("authTitle");

  const authBtn = $("authBtn");

  const toggleAuthBtn = $("toggleAuthBtn");

  const usernameField = $("usernameField");

  const nameField = $("nameField");

  const codeField = $("codeField");

  const codeInput = $("codeInput");



  if (authTitle) {

    authTitle.textContent = isRegister ? "" : "";

  }

  if (authBtn) {

    const btnText = authBtn.querySelector(".btn-text");

    if (btnText) btnText.textContent = isRegister ? "" : "";

  }

  if (toggleAuthBtn) {

    toggleAuthBtn.textContent = isRegister ? "  ?" : " ";

  }

  if (usernameField) {

    usernameField.classList.toggle("hidden", !isRegister);

  }

  if (nameField) {

    nameField.classList.toggle("hidden", !isRegister);

  }

  if (codeField) {

    codeField.classList.add("hidden");

  }

  if (codeInput) {

    codeInput.value = "";

  }

}





function normalizeChatItem(item) {

  const chatId = item.id || item.username || item.chat_id || item.chatId;

  const type = item.type

    || (chatId && String(chatId).startsWith("group_") ? "group" : null)

    || (chatId && String(chatId).startsWith("channel_") ? "channel" : null)

    || "user";

  const isonline = typeof item.is_online === "boolean" ? item.is_online : item.isonline;
  const avatar = item.avatar || item.avatar_url || item.photo || item.avatarUrl || "";

  return { ...item, chatId, type, isonline, username: item.username || chatId, avatar };

}

async function loadChats({ silent = false, force = false } = {}) {

  if (!state.session) return;
  if (state.chatSearchActive && !force) return;

  try {
    const username = state.session.username || state.session.user || state.session.login || "";
    const token = state.session.token;

    if (!username) {
      throw new Error("Missing username in session");
    }

    const data = await apiFetch(
      `/get_chats?username=${encodeURIComponent(username)}&token=${encodeURIComponent(token)}&version=1.0`,
      {},
      { silent }
    );

    const rawList = Array.isArray(data)
      ? data
      : (Array.isArray(data?.chats) ? data.chats : (Array.isArray(data?.items) ? data.items : []));

    const list = [];
    const seen = new Set();
    rawList.forEach((item) => {
      const normalized = normalizeChatItem(item);
      let baseId = normalized.chatId || normalized.username;
      const rawName = String(normalized.name || "");
      const supportAliases = new Set(["support", "supports", "@support", "@supports"]);
      const supportName = "\u041F\u043E\u0434\u0434\u0435\u0440\u0436\u043A\u0430";
      const isSupport =
        (baseId && supportAliases.has(String(baseId).toLowerCase())) ||
        (normalized.username && supportAliases.has(String(normalized.username).toLowerCase())) ||
        rawName.toLowerCase().includes(supportName.toLowerCase()) ||
        rawName.includes("\u0420\u045F\u0420\u00BE\u0420\u00B4\u0420\u00B4\u0420\u00B5\u0420\u00C0\u0420\u00B6\u0420\u00BA\u0420\u00B0");

      if (isSupport) {
        normalized.chatId = "supports";
        normalized.username = "supports";
        normalized.name = supportName;
        normalized.type = "user";
        baseId = "supports";
      }

      const type = normalized.type || "user";
      const key = baseId ? `${String(baseId)}::${type}` : "";
      if (!baseId || baseId === FAVORITES_CHAT_ID) return;
      if (seen.has(key)) return;
      seen.add(key);
      list.push(normalized);
    });
    const supportSeen = Array.from(seen).some((k) => k.startsWith("supports::"));
    if (!supportSeen) {
      list.unshift({
        chatId: "supports",
        username: "supports",
        name: "Поддержка",
        type: "user",
        isonline: false
      });
    }
    state.chatList = list;

    state.chatIndex = {};

    list.forEach((u) => {
      if (u.chatId) {
        state.chatIndex[String(u.chatId)] = {
          type: u.type || "user",
          name: u.name || u.username || u.chatId,
          members: u.members || [],
          avatar: u.avatar || "",
          owner: u.owner || "",
        };
      }
    });

    renderChatList(list);

  } catch (err) {
    if (!silent) toast("Не удалось загрузить чаты");
  }

}



function appendUnreadBadge(headerEl, count) {

  if (!headerEl || !count) return;

  const badge = document.createElement("div");

  badge.className = "chat-item-badge";

  badge.textContent = count > 99 ? "99+" : String(count);

  headerEl.appendChild(badge);

}

async function deleteChatRemote(chatId, type = "user") {
  if (!state.session || !chatId) return;
  const token = state.session.token;
  const username = state.session.username;
  const payload = { token, username, chat_id: chatId };
  const attempts = [
    { path: "/chats/delete", method: "POST", body: payload },
    { path: "/delete_chat", method: "POST", body: payload },
    { path: "/delete_dialog", method: "POST", body: payload },
    { path: "/delete_conversation", method: "POST", body: payload },
  ];
  for (const attempt of attempts) {
    try {
      await apiFetch(attempt.path, {
        method: attempt.method,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(attempt.body),
      }, { silent: true });
      return;
    } catch {
    }
  }
}

function confirmDeleteChat(chatId, type = "user") {
  if (!chatId || chatId === FAVORITES_CHAT_ID) return;
  const ok = confirm("Удалить чат?");
  if (!ok) return;
  state.chatList = (state.chatList || []).filter((c) => String(c.chatId || c.username) !== String(chatId));
  renderChatList(state.chatList);
  if (state.activeTarget === chatId) {
    state.activeTarget = null;
    state.messages = [];
    state.messagesLoaded = false;
    renderMessages([]);
    showEmptyState(DEFAULT_EMPTY_TITLE, DEFAULT_EMPTY_SUBTITLE);
  }
  deleteChatRemote(chatId, type);
}

function bindChatContextMenu() {
  if (state.chatContextBound) return;
  state.chatContextBound = true;
  document.addEventListener("click", (e) => {
    const menu = $("chatContextMenu");
    if (!menu || menu.classList.contains("hidden")) return;
    if (menu.contains(e.target)) return;
    closeChatContextMenu();
  });
  document.addEventListener("scroll", () => closeChatContextMenu(), true);
  window.addEventListener("resize", () => closeChatContextMenu());
  const deleteBtn = $("chatCtxDelete");
  if (deleteBtn) {
    deleteBtn.addEventListener("click", () => {
      if (!state.chatContextTarget) return;
      const { chatId, type } = state.chatContextTarget;
      closeChatContextMenu();
      confirmDeleteChat(chatId, type);
    });
  }
}

function openChatContextMenu(e, chatId, type = "user") {
  const menu = $("chatContextMenu");
  if (!menu) return;
  bindChatContextMenu();
  state.chatContextTarget = { chatId, type };
  const padding = 8;
  const maxX = window.innerWidth - menu.offsetWidth - padding;
  const maxY = window.innerHeight - menu.offsetHeight - padding;
  const x = Math.min(e.clientX, maxX);
  const y = Math.min(e.clientY, maxY);
  menu.style.left = `${Math.max(padding, x)}px`;
  menu.style.top = `${Math.max(padding, y)}px`;
  menu.classList.remove("hidden");
}

function closeChatContextMenu() {
  const menu = $("chatContextMenu");
  if (!menu) return;
  menu.classList.add("hidden");
  state.chatContextTarget = null;
}

async function ensureUserInfo(username) {
  if (!username) return;
  pruneUserInfoCache();
  if (state.userInfoCache[username] || state.userInfoPending[username]) return;
  if (!state.session?.token) return;
  state.userInfoPending[username] = true;
  try {
    const data = await apiFetch(
      `/get_user_info?username=${encodeURIComponent(username)}&token=${encodeURIComponent(state.session.token)}&my_username=${encodeURIComponent(state.session.username)}`,
      {},
      { silent: true }
    );
    if (data && (data.name || data.username)) {
      state.userInfoCache[username] = data;
      state.userInfoTimestamps[username] = Date.now();
      saveUserInfoCache();
      if (Array.isArray(state.chatList)) {
        state.chatList = state.chatList.map((c) => {
          const key = String(c.chatId || c.username);
          if (key === String(username)) {
            return { ...c, name: data.name || c.name || username, username: data.username || c.username || username };
          }
          return c;
        });
      }
      if (state.activeTarget === username && state.activeChatType === "user") {
        const title = $("chatTitle");
        if (title) title.textContent = data.name || username;
      }
      const safeKey = (window.CSS && CSS.escape) ? CSS.escape(String(username)) : String(username);
      const item = document.querySelector(`.chat-item[data-username="${safeKey}"]`);
      if (item) {
        const nameEl = item.querySelector(".chat-item-name");
        const badge = getBadgeData(data, data);
        renderNameWithBadge(nameEl, data.name || username, badge);
        const avatarEl = item.querySelector(".chat-item-avatar");
        if (avatarEl) updateChatAvatar(avatarEl, { ...data, username });
      } else {
        renderChatList(state.chatList || []);
      }
    }
  } catch {
  } finally {
    delete state.userInfoPending[username];
  }
}



function renderChatList(chats) {

  const list = $("chatList");

  const empty = $("chatEmpty");

  if (!list || !empty) return;



  list.querySelectorAll(".skeleton-item").forEach(el => el.remove());

  list.innerHTML = "";



  if (!Array.isArray(chats)) chats = [];

  empty.classList.add("hidden");

  const favoritesItem = document.createElement("div");
  favoritesItem.className = "chat-item chat-favorites";
  favoritesItem.dataset.username = FAVORITES_CHAT_ID;
  if (state.activeTarget === FAVORITES_CHAT_ID) favoritesItem.classList.add("active");

  const favoritesAvatar = document.createElement("div");
  favoritesAvatar.className = "chat-item-avatar";
  favoritesAvatar.style.background = "linear-gradient(135deg, #fbbf24, #f97316)";
  favoritesAvatar.textContent = "★";

  const favoritesContent = document.createElement("div");
  favoritesContent.className = "chat-item-content";

  const favoritesHeader = document.createElement("div");
  favoritesHeader.className = "chat-item-header";

  const favoritesName = document.createElement("div");
  favoritesName.className = "chat-item-name";
  favoritesName.textContent = "Сохранённые сообщения";
  favoritesHeader.appendChild(favoritesName);

  const favoritesMessage = document.createElement("div");
  favoritesMessage.className = "chat-item-message";
  favoritesMessage.textContent = "Личный чат";

  favoritesContent.appendChild(favoritesHeader);
  favoritesContent.appendChild(favoritesMessage);

  favoritesItem.appendChild(favoritesAvatar);
  favoritesItem.appendChild(favoritesContent);
  favoritesItem.addEventListener("click", openFavoritesChat);

  list.appendChild(favoritesItem);

  const pinnedChats = [];
  const regularChats = [];
  chats.forEach((u) => {
    const chatId = u.chatId || u.username;
    if (isChatPinned(chatId)) {
      pinnedChats.push(u);
    } else {
      regularChats.push(u);
    }
  });
  const orderedChats = [...pinnedChats, ...regularChats];

  orderedChats.forEach((u) => {

    const item = document.createElement("div");

    item.className = "chat-item";

    item.dataset.username = u.chatId || u.username;
    if (isChatPinned(u.chatId || u.username)) item.classList.add("chat-pinned");



    if ((u.chatId || u.username) === state.activeTarget) item.classList.add("active");

    item.addEventListener("contextmenu", (e) => {
      e.preventDefault();
      openChatContextMenu(e, u.chatId || u.username, u.type || "user");
    });



    const avatar = document.createElement("div");

    avatar.className = "chat-item-avatar";

    updateChatAvatar(avatar, u);



    const content = document.createElement("div");

    content.className = "chat-item-content";



    const header = document.createElement("div");

    header.className = "chat-item-header";



    const name = document.createElement("div");

    name.className = "chat-item-name";

    const lookupKey = u.username || u.chatId;
    const cached = lookupKey ? state.userInfoCache[lookupKey] : null;
    const displayName = u.name || cached?.name || lookupKey || "";
    const badge = u.type === "user" ? getBadgeData(u, cached) : null;
    renderNameWithBadge(name, displayName, badge);



    header.appendChild(name);
    if (isChatPinned(u.chatId || u.username)) {
      const pin = document.createElement("span");
      pin.className = "chat-item-pin";
      pin.innerHTML = "&#128204;";
      header.appendChild(pin);
    }

    const unreadCount = state.chatSearchActive
      ? 0
      : Number(u.unread_count ?? u.unread ?? 0);

    appendUnreadBadge(header, unreadCount);



    const message = document.createElement("div");

    message.className = "chat-item-message";

    const listSubtitle = u.type === "group"
      ? "??????"
      : u.type === "channel"
        ? "?????"
        : (u.last_seen_text || (u.isonline ? "? ????" : "?? ? ????"));
    message.textContent = listSubtitle;



    content.appendChild(header);

    content.appendChild(message);



    if (u.type === "user" && u.isonline) {

      const indicator = document.createElement("div");

      indicator.className = "status-indicator online";

      avatar.appendChild(indicator);

    }

    if (u.type === "user" && lookupKey && !u.name) {
      ensureUserInfo(lookupKey);
    }



    item.appendChild(avatar);

    item.appendChild(content);



    item.addEventListener("click", () => selectChat(u));

    list.appendChild(item);

  });

}



function openFavoritesChat() {
  closeMessageSearch();
  cancelReply();
  cancelEdit();
  state.serverSearchActive = false;
  state.serverSearchCache = null;

  state.activeTarget = FAVORITES_CHAT_ID;
  state.activeChatType = "favorites";
  state.lastMsgId = -1;
  state.messages = [];
  state.messagesLoaded = false;

  $("chatTitle").textContent = "\u0421\u043e\u0445\u0440\u0430\u043d\u0451\u043d\u043d\u044b\u0435 \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u044f";
  $("chatSubtitle").textContent = "\u041b\u0438\u0447\u043d\u044b\u0439 \u0447\u0430\u0442";
  $("chatSubtitle").classList.remove("online");

  $("chatAvatar").style.backgroundImage = "";
  $("chatAvatar").style.background = "linear-gradient(135deg, #fbbf24, #f97316)";
  $("chatAvatar").textContent = "\u2605";

  resetMessagesEmptyText();
  $("messagesEmpty").classList.remove("hidden");
  $("messageList").innerHTML = "";

  const inputWrapper = document.querySelector(".message-input-wrapper");
  if (inputWrapper) inputWrapper.style.display = "flex";

  if ($("messageInput")) $("messageInput").disabled = false;
  if ($("sendBtn")) $("sendBtn").disabled = false;
  if ($("attachBtn")) $("attachBtn").disabled = false;
  if ($("emojiBtn")) $("emojiBtn").disabled = false;
  if ($("voiceBtn")) $("voiceBtn").disabled = false;
  if ($("scheduleBtn")) $("scheduleBtn").disabled = false;
  if ($("pollBtn")) $("pollBtn").disabled = false;
  if ($("ttlBtn")) $("ttlBtn").disabled = false;
  if ($("profileBtn")) $("profileBtn").disabled = true;
  if ($("inviteBtn")) $("inviteBtn").disabled = true;
  if ($("searchMessagesBtn")) $("searchMessagesBtn").disabled = false;
  if ($("mediaGalleryBtn")) $("mediaGalleryBtn").disabled = false;

  document.querySelectorAll(".chat-item").forEach(item => {
    item.classList.toggle("active", item.dataset.username === FAVORITES_CHAT_ID);
  });
  setMobileChatOpen(true);

  if ($("profilePanel")?.classList.contains("show")) {
    toggleProfile(false);
  }

  updatePinChatButton();
  if (typeof renderPinnedBar === "function") {
    renderPinnedBar();
  }

  setTimeout(() => $("messageInput")?.focus(), 100);
  loadMessages({ silent: false });
}

function renderFavoritesMessages() {

  const list = $("messageList");

  if (!list) return;

  list.innerHTML = "";



  const data = Object.values(state.favoritesData || {});
  state.messages = data.map((item) => item.message || item).filter(Boolean);

  if (data.length === 0) {

    $("messagesEmpty")?.classList.remove("hidden");

    if ($("messagesEmptyTitle")) $("messagesEmptyTitle").textContent = "\u0421\u043e\u0445\u0440\u0430\u043d\u0451\u043d\u043d\u044b\u0445 \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0439 \u043d\u0435\u0442";

    if ($("messagesEmptySubtitle")) $("messagesEmptySubtitle").textContent = "\u0414\u043e\u0431\u0430\u0432\u044c\u0442\u0435 \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435 \u0432 \u0438\u0437\u0431\u0440\u0430\u043d\u043d\u043e\u0435 \u0447\u0435\u0440\u0435\u0437 \u043c\u0435\u043d\u044e";

    return;

  }



  $("messagesEmpty")?.classList.add("hidden");

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



  if ($("chatSubtitle")) $("chatSubtitle").textContent = `\u0421\u043e\u0445\u0440\u0430\u043d\u0451\u043d\u043d\u044b\u0445 \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0439: ${data.length}`;

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

  restoreMessageSearchCache();
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

function restoreMessageSearchCache() {
  if (!state.serverSearchActive) return;
  const cached = Array.isArray(state.serverSearchCache) ? state.serverSearchCache : [];
  state.serverSearchActive = false;
  state.serverSearchCache = null;
  state.serverSearchResults = [];
  state.messages = cached;
  renderMessages(cached);
}

function highlightSearchInDom(q) {
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

async function fetchServerSearchResults(query) {
  if (!state.session || !state.activeTarget) return null;
  const params = new URLSearchParams({
    chat_id: state.activeTarget,
    q: query,
    username: state.session.username,
    token: state.session.token,
  });
  if (state.activeChatType && state.activeChatType !== "user") {
    params.set("chat_type", state.activeChatType);
  }
  try {
    const data = await apiFetch(`/search_messages?${params.toString()}`, {}, { silent: true });
    const list = Array.isArray(data) ? data : Array.isArray(data?.results) ? data.results : [];
    return list.length ? list : null;
  } catch {
    return null;
  }
}

async function runMessageSearch() {
  const q = $("messageSearchInput").value.trim().toLowerCase();
  state.messageSearchQuery = q;

  if (!q) {
    restoreMessageSearchCache();
    clearMessageSearchHighlights();
    return;
  }

  let usedServer = false;
  const serverResults = await fetchServerSearchResults(q);
  if (Array.isArray(serverResults) && serverResults.length) {
    if (!state.serverSearchActive) {
      state.serverSearchCache = Array.isArray(state.messages) ? [...state.messages] : [];
    }
    state.serverSearchActive = true;
    state.serverSearchResults = serverResults;
    state.messages = serverResults;
    renderMessages(serverResults);
    usedServer = true;
  }

  if (!usedServer && state.serverSearchActive) {
    restoreMessageSearchCache();
  }

  highlightSearchInDom(q);
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

  cancelReply();

  cancelEdit();
  state.serverSearchActive = false;
  state.serverSearchCache = null;



  const chatId = u.chatId || u.username;

  const chatType = u.type

    || (chatId && String(chatId).startsWith("group_") ? "group" : null)

    || (chatId && String(chatId).startsWith("channel_") ? "channel" : null)

    || "user";



  state.activeTarget = chatId;

  state.activeChatType = chatType;

    state.lastMsgId = -1;

    state.messages = [];

    state.messagesLoaded = false;

    const list = $("messageList");
    if (list) {
      list.classList.remove("chat-enter");
      list.classList.add("chat-switching");
      requestAnimationFrame(() => {
        list.classList.add("chat-enter");
        list.classList.remove("chat-switching");
      });
    }



    const baseUsername = u.username || chatId;
  const cached = baseUsername ? state.userInfoCache[baseUsername] : null;
  const displayName = u.name || cached?.name || baseUsername || chatId || "Чат";
  const titleBadge = chatType === "user" ? getBadgeData(u, cached) : null;
  renderNameWithBadge($("chatTitle"), displayName, titleBadge);

  if (chatType === "user") {

    $("chatSubtitle").textContent = u.last_seen_text || (u.isonline ? "? ????" : "?? ? ????");

    if (u.isonline) {

      $("chatSubtitle").classList.add("online");

    } else {

      $("chatSubtitle").classList.remove("online");

    }

  } else {

    $("chatSubtitle").textContent = chatType === "group" ? "Группа" : "Канал";

    $("chatSubtitle").classList.remove("online");

  }



  $("chatAvatar").style.background = "";
  updateChatAvatar($("chatAvatar"), u);



  const meta = getChatMeta(chatId);

  if (meta?.description && chatType !== "user") {

    $("chatSubtitle").textContent = meta.description;

  }



  resetMessagesEmptyText();

  $("messagesEmpty").classList.remove("hidden");

  $("messageList").innerHTML = "";



  const inputWrapper = document.querySelector(".message-input-wrapper");

  inputWrapper.style.display = "flex";



  const canSendChannel = chatType !== "channel" || !u.owner || u.owner === state.session.username;

  $("messageInput").disabled = !canSendChannel;

  $("sendBtn").disabled = !canSendChannel;

  $("attachBtn").disabled = !canSendChannel;

  $("emojiBtn").disabled = !canSendChannel;

  if ($("voiceBtn")) $("voiceBtn").disabled = !canSendChannel;
  if ($("scheduleBtn")) $("scheduleBtn").disabled = !canSendChannel;
  if ($("pollBtn")) $("pollBtn").disabled = !canSendChannel;
  if ($("ttlBtn")) $("ttlBtn").disabled = !canSendChannel;

  $("profileBtn").disabled = chatType !== "user";

  if ($("inviteBtn")) $("inviteBtn").disabled = chatType === "user";

  $("searchMessagesBtn").disabled = false;

  if ($("mediaGalleryBtn")) $("mediaGalleryBtn").disabled = false;



  document.querySelectorAll(".chat-item").forEach(item => {

    item.classList.toggle("active", item.dataset.username === chatId);

  });

  setMobileChatOpen(true);

  if (chatType !== "user") {

    markCollectiveRead(chatId);

  } else {
    markDirectRead(chatId);
  }



  if ($("profilePanel").classList.contains("show")) {

    toggleProfile(false);

  }



  loadDraft();

  updatePinChatButton();
  if (typeof renderPinnedBar === "function") {
    renderPinnedBar();
  }
  if (chatType === "user" && baseUsername && !u.name) {
    ensureUserInfo(baseUsername);
  }



  setTimeout(() => $("messageInput").focus(), 100);



  await loadMessages({ silent: false });

}

function saveDraft() {

  if (!state.activeTarget) return;

  if (state.settings.draftsEnabled === false) return;



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

  if (state.settings.draftsEnabled === false) return;



  const drafts = JSON.parse(localStorage.getItem("niosmess_drafts") || "{}");

  const draft = drafts[state.activeTarget] || "";



  $("messageInput").value = draft;

  autoResize($("messageInput"));

}



function clearDraft() {

  if (!state.activeTarget) return;

  if (state.settings.draftsEnabled === false) return;



  const drafts = JSON.parse(localStorage.getItem("niosmess_drafts") || "{}");

  delete drafts[state.activeTarget];

  localStorage.setItem("niosmess_drafts", JSON.stringify(drafts));

}
const avatarCache = {
    data: {},
    timestamps: {},

    get(username) {
        const cached = this.data[username];
        const timestamp = this.timestamps[username];
        if (cached && timestamp && (Date.now() - timestamp < 5 * 60 * 1000)) {
            return cached;
        }
        return null;
    },

    set(username, url) {
        this.data[username] = url;
        this.timestamps[username] = Date.now();
    },

    clear(username) {
        if (username) {
            delete this.data[username];
            delete this.timestamps[username];
        } else {
            this.data = {};
            this.timestamps = {};
        }
    }
};

const avatarObjectUrlCache = new Map();

function getAvatarCacheKey(username) {
    return `${state.apiBase}/__avatar_cache__/${encodeURIComponent(username)}`;
}

async function getCachedAvatarUrl(username) {
    if (!username) return null;
    const cached = avatarObjectUrlCache.get(username);
    if (cached) return cached;
    if (!("caches" in window)) return null;
    try {
        const cache = await caches.open(AVATAR_CACHE_NAME);
        const res = await cache.match(getAvatarCacheKey(username));
        if (!res) return null;
        const blob = await res.blob();
        const objUrl = URL.createObjectURL(blob);
        avatarObjectUrlCache.set(username, objUrl);
        return objUrl;
    } catch {
        return null;
    }
}

async function putAvatarInCache(username, blob) {
    if (!("caches" in window)) return;
    try {
        const cache = await caches.open(AVATAR_CACHE_NAME);
        await cache.put(getAvatarCacheKey(username), new Response(blob));
    } catch {}
}

async function clearAvatarCache() {
    if ("caches" in window) {
        try {
            await caches.delete(AVATAR_CACHE_NAME);
        } catch {}
    }
    avatarObjectUrlCache.forEach((url) => {
        try {
            URL.revokeObjectURL(url);
        } catch {}
    });
    avatarObjectUrlCache.clear();
    avatarCache.clear();
}

async function uploadAvatar(file) {
    if (!file || !state.session) {
        throw new Error('Файл или сессия отсутствуют');
    }

    const allowedTypes = ['image/png', 'image/jpeg', 'image/jpg'];
    if (!allowedTypes.includes(file.type)) {
        throw new Error('Допустимые форматы: PNG, JPG, JPEG');
    }

    const maxSize = 5 * 1024 * 1024;
    if (file.size > maxSize) {
        throw new Error('Максимальный размер: 5MB');
    }

    const form = new FormData();
    form.append('token', state.session.token);
    form.append('username', state.session.username);
    form.append('file', file);

    showLoading();
    try {
        const data = await apiFetch('/set_av', {
            method: 'POST',
            body: form
        });

        if (data.status === 'ok' && data.avatar) {
            return data.avatar;
        }
        throw new Error(data.error || 'Ошибка загрузки');
    } finally {
        hideLoading();
    }
}

async function fetchUserAvatar(username) {
    if (!username) return null;

    const cached = await getCachedAvatarUrl(username);
    if (cached) return cached;

    const form = new FormData();
    form.append('other', username);

    try {
        const response = await fetch(`${state.apiBase}/get_av`, {
            method: 'POST',
            body: form
        });

        if (!response.ok) return null;

        const blob = await response.blob();
        await putAvatarInCache(username, blob);
        const objUrl = URL.createObjectURL(blob);
        avatarObjectUrlCache.set(username, objUrl);
        return objUrl;
    } catch (err) {
        console.warn(`Avatar fetch failed for ${username}:`, err);
        return null;
    }
}

async function applyUserAvatar(el, username, fallbackInitial) {
    if (!el || !username) return;

    const cached = avatarCache.get(username);
    if (cached) {
        el.style.backgroundImage = `url(${cached})`;
        el.style.backgroundSize = 'cover';
        el.style.backgroundPosition = 'center';
        el.textContent = '';
        el.classList.add('has-image');
        return;
    }

    el.style.backgroundImage = '';
    el.textContent = fallbackInitial || '?';
    el.classList.remove('has-image');

    try {
        const avatarUrl = await fetchUserAvatar(username);
        if (avatarUrl) {
            avatarCache.set(username, avatarUrl);
            el.style.backgroundImage = `url(${avatarUrl})`;
            el.style.backgroundSize = 'cover';
            el.style.backgroundPosition = 'center';
            el.textContent = '';
            el.classList.add('has-image');
        }
    } catch (err) {
        console.warn('Avatar load error:', err);
    }
}

function updateChatAvatar(avatar, user) {
    const username = user.username || user.chatId;
    const displayName = user.name || username;
    const initial = (displayName ? String(displayName[0]) : '?').toUpperCase();

    if (user.type === 'user' && username) {
        applyUserAvatar(avatar, username, initial);
    } else if (user.avatar) {
        avatar.style.backgroundImage = `url(${user.avatar})`;
        avatar.style.backgroundSize = 'cover';
        avatar.style.backgroundPosition = 'center';
        avatar.classList.add('has-image');
        avatar.textContent = '';
    } else {
        avatar.textContent = initial;
    }
}



