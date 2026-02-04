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

  if ($("messageList")) $("messageList").innerHTML = "";
  if ($("messagesEmpty")) $("messagesEmpty").classList.remove("hidden");

  const inputWrapper = document.querySelector(".message-input-wrapper");
  if (inputWrapper) inputWrapper.style.display = "none";

  loadChats({ silent: false });
  ping();
  if (typeof initRealtime === "function") initRealtime();

  stopTimers();
  state.syncTimer = setInterval(async () => {
    await ping();
    if (!state.chatSearchActive) {
      await loadChats({ silent: true });
    }
    if (state.activeTarget) {
      await loadMessages({ silent: true });
    }
  }, 5000);
}

function initEvents() {

  $("authBtn")?.addEventListener("click", loginOrRegister);
  $("toggleAuthBtn")?.addEventListener("click", () => setAuthMode(!state.isRegister));

  [$("emailInput"), $("passwordInput"), $("usernameInput"), $("nameInput"), $("codeInput")].forEach(input => {
    input?.addEventListener("keydown", (e) => {
      if (e.key === "Enter") loginOrRegister();
    });
  });

  $("sendBtn")?.addEventListener("click", sendMessage);
  $("mobileBackBtn")?.addEventListener("click", () => {
    setMobileChatOpen(false);
  });
  const chatActions = $("chatActions");
  const chatActionsToggle = $("chatActionsToggle");
  if (chatActions && chatActionsToggle) {
    chatActionsToggle.addEventListener("click", (e) => {
      e.stopPropagation();
      chatActions.classList.toggle("open");
    });
    chatActions.querySelector(".chat-actions-menu")?.addEventListener("click", (e) => {
      e.stopPropagation();
    });
    document.addEventListener("click", () => {
      chatActions.classList.remove("open");
    });
  }
  $("messageInput")?.addEventListener("input", (e) => {
    saveDraft();
    autoResize(e.target);
    if (state.typingTimer) clearTimeout(state.typingTimer);
    if (e.target.value.trim()) {
      if (typeof sendTypingEvent === "function") {
        sendTypingEvent(true);
        state.typingTimer = setTimeout(() => sendTypingEvent(false), 1200);
      }
    } else {
      if (typeof sendTypingEvent === "function") sendTypingEvent(false);
    }
  });

  $("messageInput")?.addEventListener("keydown", (e) => {
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

  $("attachBtn")?.addEventListener("click", (e) => {
    const btn = $("attachBtn");
    if (btn?.disabled) return;
    const menu = $("attachMenu");
    if (!menu) return;
    e.stopPropagation();
    menu.classList.toggle("hidden");
  });
  $("fileInput")?.addEventListener("change", (e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (file) uploadFile(file);
  });
  $("attachFileBtn")?.addEventListener("click", () => {
    $("attachMenu")?.classList.add("hidden");
    $("fileInput")?.click();
  });
  $("attachLocationBtn")?.addEventListener("click", () => {
    $("attachMenu")?.classList.add("hidden");
    openLocationModal();
  });
  $("attachContactBtn")?.addEventListener("click", () => {
    $("attachMenu")?.classList.add("hidden");
    openContactModal();
  });

  $("voiceBtn")?.addEventListener("click", toggleVoiceRecording);
  $("mediaGalleryBtn")?.addEventListener("click", openMediaGallery);
  $("mediaViewerClose")?.addEventListener("click", closeMediaViewer);
  $("mediaViewer")?.addEventListener("click", (e) => {
    if (e.target.classList.contains("media-viewer-backdrop")) closeMediaViewer();
  });
  $("mediaGalleryClose")?.addEventListener("click", closeMediaGallery);
  $("mediaGallery")?.addEventListener("click", (e) => {
    if (e.target.classList.contains("media-gallery-backdrop")) closeMediaGallery();
  });
  $("exportSessionBtn")?.addEventListener("click", exportDeviceProfile);
  $("clearMediaCacheBtn")?.addEventListener("click", () => {
    if (typeof clearMediaCache === "function") clearMediaCache();
  });
  $("refreshCacheStatsBtn")?.addEventListener("click", () => {
    if (typeof refreshCacheStats === "function") refreshCacheStats();
  });
  if (typeof refreshCacheStats === "function") {
    refreshCacheStats();
  }

  $("searchInput")?.addEventListener("input", () => {
    if (state.searchTimer) clearTimeout(state.searchTimer);
    state.searchTimer = setTimeout(searchUsers, 300);
  });

  $("clearSearch")?.addEventListener("click", () => {
    if ($("searchInput")) $("searchInput").value = "";
    $("clearSearch")?.classList.add("hidden");
    loadChats({ silent: true });
  });

  $("emojiBtn")?.addEventListener("click", (e) => {
    e.stopPropagation();
    toggleEmojiPicker();
  });
  $("scheduleBtn")?.addEventListener("click", openScheduleModal);
  $("pollBtn")?.addEventListener("click", openPollModal);
  $("ttlBtn")?.addEventListener("click", openTtlModal);

  $("ctxCopy")?.addEventListener("click", copyMessage);
  $("ctxReply")?.addEventListener("click", () => {
    if (state.contextMenuTarget) setReplyTo(state.contextMenuTarget.data);
    hideContextMenu();
  });
  $("ctxForward")?.addEventListener("click", () => {
    if (state.contextMenuTarget) openForwardModal(state.contextMenuTarget.data);
    hideContextMenu();
  });
  $("ctxEdit")?.addEventListener("click", () => {
    if (state.contextMenuTarget) setEditingMessage(state.contextMenuTarget.data);
    hideContextMenu();
  });
  document.querySelectorAll(".context-reaction").forEach((btn) => {
    btn.addEventListener("click", () => {
      if (!state.contextMenuTarget) return;
      const emoji = btn.dataset.emoji;
      const msgId = String(state.contextMenuTarget.data.id || state.contextMenuTarget.data.temp_id);
      toggleReaction(msgId, emoji);
      updateMessageReactions(msgId);
      hideContextMenu();
    });
  });
  $("ctxFavorite")?.addEventListener("click", toggleFavorite);
  $("ctxPin")?.addEventListener("click", togglePinMessage);
  $("ctxScheduleCancel")?.addEventListener("click", cancelScheduledMessage);
  $("ctxDelete")?.addEventListener("click", deleteMessageForMe);
  $("ctxDeleteAll")?.addEventListener("click", deleteMessageForAll);
  $("ctxBold")?.addEventListener("click", () => applyFormatToSelection("bold"));
  $("ctxItalic")?.addEventListener("click", () => applyFormatToSelection("italic"));
  $("ctxCode")?.addEventListener("click", () => applyFormatToSelection("code"));

  $("pinnedClose")?.addEventListener("click", (e) => {
    e.stopPropagation();
    if (!state.activeTarget) return;
    clearPinnedMessage(state.activeTarget);
    renderPinnedBar();
    renderMessages(state.messages);
  });
  $("pinnedBar")?.addEventListener("click", () => {
    const bar = $("pinnedBar");
    if (!bar) return;
    const msgId = bar.dataset.msgId;
    if (msgId) scrollToMessageById(msgId);
  });

  $("forwardClose")?.addEventListener("click", closeForwardModal);
  $("forwardCancel")?.addEventListener("click", closeForwardModal);
  $("forwardModal")?.addEventListener("click", (e) => {
    if (e.target.classList.contains("modal-backdrop")) closeForwardModal();
  });
  $("forwardSearch")?.addEventListener("input", (e) => {
    renderForwardList(e.target.value);
  });
  $("forwardSubmit")?.addEventListener("click", submitForward);

  $("sessionsRefresh")?.addEventListener("click", () => loadSessions({ silent: false }));
  $("sessionsLogoutAll")?.addEventListener("click", logoutOtherSessions);

  document.addEventListener("click", (e) => {
    const contextMenu = $("contextMenu");
    if (contextMenu && !contextMenu.contains(e.target)) {
      hideContextMenu();
    }

    const picker = $("emojiPicker");
    const emojiBtn = $("emojiBtn");

    if (picker && emojiBtn && !picker.contains(e.target) && e.target !== emojiBtn && !emojiBtn.contains(e.target)) {
      picker.classList.add("hidden");
    }

    const attachMenu = $("attachMenu");
    const attachBtn = $("attachBtn");
    if (attachMenu && attachBtn && !attachMenu.contains(e.target) && !attachBtn.contains(e.target)) {
      attachMenu.classList.add("hidden");
    }
  });

  $("profileBtn")?.addEventListener("click", () => toggleProfile());
  $("closeProfileBtn")?.addEventListener("click", () => toggleProfile(false));
  $("chatAvatar")?.addEventListener("click", () => {
    const profileBtn = $("profileBtn");
    if (!profileBtn || profileBtn.disabled) return;
    toggleProfile(true);
  });

  $("searchMessagesBtn")?.addEventListener("click", () => {
    const bar = $("messageSearchBar");
    if (bar.classList.contains("hidden")) {
      openMessageSearch();
    } else {
      closeMessageSearch();
    }
  });
  $("messageSearchInput")?.addEventListener("input", runMessageSearch);
  $("messageSearchPrev")?.addEventListener("click", () => stepMessageSearch(-1));
  $("messageSearchNext")?.addEventListener("click", () => stepMessageSearch(1));
  $("messageSearchClose")?.addEventListener("click", closeMessageSearch);
  $("messageSearchClear")?.addEventListener("click", () => {
    $("messageSearchInput").value = "";
    runMessageSearch();
    $("messageSearchInput").focus();
  });

  $("helpModalClose")?.addEventListener("click", closeHelpModal);
  $("helpModal")?.addEventListener("click", (e) => {
    if (e.target.classList.contains("help-modal-backdrop")) {
      closeHelpModal();
    }
  });

  $("backFromProfileBtn")?.addEventListener("click", closeMyProfile);
  $("saveProfileBtn")?.addEventListener("click", saveMyProfile);
  $("changeAvatarBtn")?.addEventListener("click", () => $("avatarInput")?.click());
  $("avatarInput")?.addEventListener("change", (e) => {
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

  $("menuBtn")?.addEventListener("click", openSideMenu);
  $("menuUserBtn")?.addEventListener("click", () => openMyProfile("account"));
  $("menuProfileBtn")?.addEventListener("click", () => openMyProfile("account"));
  $("settingsMenuBtn")?.addEventListener("click", () => openMyProfile("account"));
  $("menuPersonalizationBtn")?.addEventListener("click", () => openMyProfile("personalization"));
  $("menuMusicBtn")?.addEventListener("click", () => {
    closeSideMenu();
    openMusicPlayer();
  });

  $("createGroupMenuBtn")?.addEventListener("click", () => {
    closeSideMenu();
    openCreateChatModal("group");
  });
  $("createChannelMenuBtn")?.addEventListener("click", () => {
    closeSideMenu();
    openCreateChatModal("channel");
  });
  $("createChatClose")?.addEventListener("click", closeCreateChatModal);
  $("createChatCancel")?.addEventListener("click", closeCreateChatModal);
  $("createChatSubmit")?.addEventListener("click", submitCreateChat);

  $("inviteBtn")?.addEventListener("click", openInviteModal);
  $("inviteClose")?.addEventListener("click", closeInviteModal);
  $("inviteCancel")?.addEventListener("click", closeInviteModal);
  $("inviteSubmit")?.addEventListener("click", submitInvite);
  $("inviteSearchInput")?.addEventListener("input", (e) => renderInviteSuggestions(e.target.value));
  $("inviteRefresh")?.addEventListener("click", renderMembersList);
  $("inviteAction")?.addEventListener("change", () => {
    state.inviteSelected = new Set();
    if ($("inviteMembers")) $("inviteMembers").value = "";
    if (typeof renderInviteSelected === "function") renderInviteSelected();
    renderInviteSuggestions($("inviteSearchInput")?.value || "");
  });

  $("createChatModal")?.addEventListener("click", (e) => {
    if (e.target.classList.contains("modal-backdrop")) closeCreateChatModal();
  });
  $("inviteModal")?.addEventListener("click", (e) => {
    if (e.target.classList.contains("modal-backdrop")) closeInviteModal();
  });

  $("createChatAvatarBtn")?.addEventListener("click", () => $("createChatAvatarInput")?.click());
  $("createChatAvatarInput")?.addEventListener("change", (e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    if (!file.type || !file.type.startsWith("image/")) {
      toast("Select an image");
      return;
    }
    state.pendingCreateAvatarFile = file;
    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = String(reader.result || "");
      if (!dataUrl) return;
      state.pendingCreateAvatar = dataUrl;
      const preview = $("createChatAvatarPreview");
      if (preview) {
        preview.style.backgroundImage = `url(${dataUrl})`;
        preview.classList.add("has-image");
        preview.textContent = "";
      }
    };
    reader.readAsDataURL(file);
  });

  $("favoritesMenuBtn")?.addEventListener("click", () => {
    closeSideMenu();
    openFavoritesChat();
  });

  $("pinChatBtn")?.addEventListener("click", () => {
    if (!state.activeTarget || state.activeTarget === FAVORITES_CHAT_ID) return;
    toggleChatPinned(state.activeTarget);
  });

  $("scheduleClose")?.addEventListener("click", closeScheduleModal);
  $("scheduleCancel")?.addEventListener("click", closeScheduleModal);
  $("scheduleSubmit")?.addEventListener("click", submitScheduleMessage);
  $("scheduleModal")?.addEventListener("click", (e) => {
    if (e.target.classList.contains("modal-backdrop")) closeScheduleModal();
  });

  $("pollClose")?.addEventListener("click", closePollModal);
  $("pollCancel")?.addEventListener("click", closePollModal);
  $("pollSubmit")?.addEventListener("click", submitPoll);
  $("pollAddOption")?.addEventListener("click", () => addPollOption());
  $("pollModal")?.addEventListener("click", (e) => {
    if (e.target.classList.contains("modal-backdrop")) closePollModal();
  });

  $("ttlClose")?.addEventListener("click", closeTtlModal);
  $("ttlCancel")?.addEventListener("click", closeTtlModal);
  $("ttlSubmit")?.addEventListener("click", submitTtlModal);
  $("ttlModal")?.addEventListener("click", (e) => {
    if (e.target.classList.contains("modal-backdrop")) closeTtlModal();
  });

  $("locationClose")?.addEventListener("click", closeLocationModal);
  $("locationCancel")?.addEventListener("click", closeLocationModal);
  $("locationSubmit")?.addEventListener("click", submitLocation);
  $("locationDetect")?.addEventListener("click", requestCurrentLocation);
  $("locationModal")?.addEventListener("click", (e) => {
    if (e.target.classList.contains("modal-backdrop")) closeLocationModal();
  });

  $("contactClose")?.addEventListener("click", closeContactModal);
  $("contactCancel")?.addEventListener("click", closeContactModal);
  $("contactSubmit")?.addEventListener("click", submitContact);
  $("contactModal")?.addEventListener("click", (e) => {
    if (e.target.classList.contains("modal-backdrop")) closeContactModal();
  });

  $("helpMenuBtn")?.addEventListener("click", () => {
    closeSideMenu();
    openHelpModal();
  });

  $("musicPlayerClose")?.addEventListener("click", closeMusicPlayer);
  $("musicPlayer")?.addEventListener("click", (e) => {
    if (e.target.classList.contains("music-player-backdrop")) closeMusicPlayer();
  });

  $("aboutMenuBtn")?.addEventListener("click", () => {
    closeSideMenu();
    toast("NiosMess Web v2.0 — Современный мессенджер 💬");
  });

  $("logoutBtn")?.addEventListener("click", () => {
    clearSession();
    window.location.href = "onboarding.html";
    toast("Вы вышли из аккаунта");
  });

  $("logoutMenuBtn")?.addEventListener("click", () => {
    clearSession();
    closeSideMenu();
    window.location.href = "onboarding.html";
    toast("До встречи! 👋");
  });

  const sideMenuEl = $("sideMenu");
  sideMenuEl?.addEventListener("click", (e) => {
    if (e.target.classList.contains("side-menu-backdrop") || e.target === sideMenuEl) {
      closeSideMenu();
    }
  });

  window.addEventListener("resize", () => {
    setMobileChatOpen(!!state.activeTarget);
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      closeSideMenu();
      hideContextMenu();
      $("emojiPicker")?.classList.add("hidden");
      closeMessageSearch();
      closeHelpModal();
      closeMediaViewer();
      closeMediaGallery();
      closeMusicPlayer();
      closeForwardModal();
      closeScheduleModal();
      closePollModal();
      closeTtlModal();
      closeLocationModal();
      closeContactModal();

      if ($("profilePanel")?.classList.contains("show")) {
        toggleProfile(false);
      }
    }
  });
}

async function boot() {
  showLoading();

  applySettings();
  initEvents();
  initSettingsTabs();
  initThemeCarousel();
  initSettingsToggles();
  initDragDrop();
  initEmojiPicker();
  updateTtlIndicator();
  startScheduledWorker();
  setView("auth");

  await checkSession();

  setTimeout(() => hideLoading(), 300);
}

boot();

