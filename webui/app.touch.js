(function () {
  "use strict";

  const RIPPLE_SELECTORS =
    ".icon-btn, .btn-primary, .chat-item, .tg-menu-item, .context-item, .attach-item, .emoji-tab";

  // Риппл-эффект просто приятная хуета хз работает нет.
  function addRipple(e) {
    const host = e.currentTarget;
    host.classList.add("ripple-host");

    const rect = host.getBoundingClientRect();
    const size = Math.max(rect.width, rect.height) * 2;
    const circle = document.createElement("span");
    circle.className = "ripple-circle";
    circle.style.width = circle.style.height = size + "px";
    circle.style.left = e.clientX - rect.left - size / 2 + "px";
    circle.style.top = e.clientY - rect.top - size / 2 + "px";

    host.appendChild(circle);
    circle.addEventListener("animationend", () => circle.remove());
  }

  document.addEventListener("click", (e) => {
    const target = e.target.closest(RIPPLE_SELECTORS);
    if (target) addRipple(e);
  });

  // Список чатов с анимашкй.
  function assignStagger() {
    const items = document.querySelectorAll(".chat-item");
    items.forEach((el, i) => el.style.setProperty("--i", Math.min(i, 15)));
  }

  const chatList = document.getElementById("chatList") || document.querySelector(".chat-list");
  if (chatList) {
    const obs = new MutationObserver(() => assignStagger());
    obs.observe(chatList, { childList: true });
  }

  // Кнопка вниз: если улетел нахуй вверх .
  function initScrollFab() {
    const container = document.querySelector(".messages-container");
    if (!container) return;

    const fab = document.createElement("button");
    fab.className = "scroll-fab";
    fab.title = "Вниз";
    fab.innerHTML =
      '<svg viewBox="0 0 24 24" fill="none"><path d="M12 5v14M5 12l7 7 7-7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
    container.style.position = "relative";
    container.appendChild(fab);

    let ticking = false;
    container.addEventListener("scroll", () => {
      if (ticking) return;
      requestAnimationFrame(() => {
        const distFromBottom = container.scrollHeight - container.scrollTop - container.clientHeight;
        fab.classList.toggle("visible", distFromBottom > 300);
        ticking = false;
      });
      ticking = true;
    });

    fab.addEventListener("click", () => {
      container.scrollTo({ top: container.scrollHeight, behavior: "smooth" });
    });
  }

  const SWIPE_THRESHOLD = 60;

  // Свайпы: ответ по сообщению + жест для меню да костыль но вроде бля работает.
  function initSwipeGestures() {
    const msgList = document.getElementById("messageList");
    if (!msgList) return;

    let startX = 0;
    let startY = 0;
    let swiping = null;
    let hasMoved = false;

    msgList.addEventListener(
      "touchstart",
      (e) => {
        const msg = e.target.closest(".message");
        if (!msg) return;
        const touch = e.touches[0];
        startX = touch.clientX;
        startY = touch.clientY;
        swiping = msg;
        hasMoved = false;
      },
      { passive: true }
    );

    msgList.addEventListener(
      "touchmove",
      (e) => {
        if (!swiping) return;
        const touch = e.touches[0];
        const dx = touch.clientX - startX;
        const dy = Math.abs(touch.clientY - startY);

        if (dy > 30 && !hasMoved) {
          swiping = null;
          return;
        }

        if (dx > 10) {
          hasMoved = true;
          swiping.classList.add("swiping");
          swiping.style.transform = `translateX(${Math.min(dx, 100)}px)`;
        }
      },
      { passive: true }
    );

    msgList.addEventListener("touchend", () => {
      if (!swiping) return;
      const msg = swiping;
      swiping = null;

      const dx = parseFloat(msg.style.transform.replace(/[^0-9.-]/g, "")) || 0;
      msg.classList.remove("swiping");
      msg.style.transform = "";

      if (dx >= SWIPE_THRESHOLD) {
        const msgId = msg.dataset.id || msg.getAttribute("data-message-id");
        if (typeof setReplyTarget === "function" && msgId) {
          setReplyTarget(msgId);
        }
      }
    });

    document.addEventListener(
      "touchstart",
      (e) => {
        const touch = e.touches[0];
        if (touch.clientX < 20) {
          document.body._edgeSwipeStart = touch.clientX;
        }
      },
      { passive: true }
    );

    document.addEventListener("touchend", (e) => {
      if (document.body._edgeSwipeStart === undefined) return;
      const touch = e.changedTouches[0];
      const dx = touch.clientX - document.body._edgeSwipeStart;
      delete document.body._edgeSwipeStart;
      if (dx > 80 && typeof toggleSideMenu === "function") {
        toggleSideMenu();
      }
    });
  }

  // Pull-to-refresh для мобилы: тянешь — обновляешь. Ну короче стандарт.
  function initPullRefresh() {
    const container = document.querySelector(".messages-container");
    if (!container) return;

    let pullStartY = 0;
    let pulling = false;

    const indicator = document.createElement("div");
    indicator.className = "pull-indicator";
    indicator.innerHTML = '<span class="pull-spinner"></span> Обновление...';
    container.prepend(indicator);

    container.addEventListener(
      "touchstart",
      (e) => {
        if (container.scrollTop === 0) {
          pullStartY = e.touches[0].clientY;
          pulling = true;
        }
      },
      { passive: true }
    );

    container.addEventListener(
      "touchmove",
      (e) => {
        if (!pulling) return;
        const dy = e.touches[0].clientY - pullStartY;
        if (dy > 30) {
          indicator.classList.add("visible");
        }
      },
      { passive: true }
    );

    container.addEventListener("touchend", () => {
      if (!pulling) return;
      pulling = false;
      if (indicator.classList.contains("visible")) {
        if (typeof loadMessages === "function") {
          loadMessages({ silent: false });
        }
        setTimeout(() => indicator.classList.remove("visible"), 1200);
      }
    });
  }

  // Инициализация: запускаем всё это хозяйство после готовности DOM.
  function init() {
    assignStagger();
    initScrollFab();
    initSwipeGestures();
    initPullRefresh();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
