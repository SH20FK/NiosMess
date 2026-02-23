function safeSetInnerHTML(element, html) {
  element.innerHTML = DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ["b", "i", "em", "strong", "code", "pre", "br", "p", "span", "div", "a"],
    ALLOWED_ATTR: ["href", "target", "class", "style"],
    ALLOW_DATA_ATTR: false,
  });
}

function escapeHTML(text) {
  const div = document.createElement("div");
  div.textContent = text;
  return div.innerHTML;
}

function parseMarkdownSafe(text) {
  let result = escapeHTML(text);

  result = result.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  result = result.replace(/\*(.+?)\*/g, "<em>$1</em>");
  result = result.replace(/`(.+?)`/g, "<code>$1</code>");
  result = result.replace(/\n/g, "<br>");

  result = result.replace(
    /(https?:\/\/[^\s]+)/g,
    '<a href="$1" target="_blank" rel="noopener noreferrer">$1</a>'
  );

  return DOMPurify.sanitize(result, {
    ALLOWED_TAGS: ["strong", "em", "code", "br", "a"],
    ALLOWED_ATTR: ["href", "target", "rel"],
  });
}

function renderContactSafe(label, value) {
  const row = document.createElement("div");
  row.className = "contact-row";

  const labelSpan = document.createElement("span");
  labelSpan.className = "contact-label";
  labelSpan.textContent = label;

  const valueSpan = document.createElement("span");
  valueSpan.className = "contact-value";
  valueSpan.textContent = value;

  row.appendChild(labelSpan);
  row.appendChild(valueSpan);

  return row;
}

function safeJSONParse(jsonString, defaultValue = null) {
  try {
    return JSON.parse(jsonString);
  } catch (error) {
    console.error("JSON parse error:", error);
    return defaultValue;
  }
}

function handleWebSocketMessage(event) {
  const data = safeJSONParse(event.data);
  if (!data) {
    console.error("Invalid WebSocket message");
    return;
  }

  if (typeof data !== "object") {
    console.error("WebSocket message is not an object");
    return;
  }

  if (data.text) {
    data.text = DOMPurify.sanitize(data.text);
  }

  processMessage(data);
}

function safeMerge(target, source) {
  const result = { ...target };

  for (const key in source) {
    if (Object.prototype.hasOwnProperty.call(source, key)) {
      if (key === "__proto__" || key === "constructor" || key === "prototype") {
        continue;
      }
      result[key] = source[key];
    }
  }

  return result;
}

function isValidURL(url) {
  try {
    const parsed = new URL(url);
    return ["http:", "https:"].includes(parsed.protocol);
  } catch (e) {
    return false;
  }
}

function safeOpenURL(url) {
  if (!isValidURL(url)) {
    console.error("Invalid URL:", url);
    return;
  }

  window.open(url, "_blank", "noopener,noreferrer");
}

class RateLimiter {
  constructor(maxAttempts = 5, windowMs = 60000) {
    this.maxAttempts = maxAttempts;
    this.windowMs = windowMs;
    this.attempts = new Map();
  }

  isAllowed(key) {
    const now = Date.now();
    const userAttempts = this.attempts.get(key) || [];

    const recentAttempts = userAttempts.filter(
      (timestamp) => now - timestamp < this.windowMs
    );

    if (recentAttempts.length >= this.maxAttempts) {
      return false;
    }

    recentAttempts.push(now);
    this.attempts.set(key, recentAttempts);
    return true;
  }

  reset(key) {
    this.attempts.delete(key);
  }
}

const messageLimiter = new RateLimiter(10, 10000);

class SecureStorage {
  static set(key, value) {
    try {
      if (key.includes("password") || key.includes("token")) {
        console.warn("Attempting to store sensitive data in localStorage");
        return false;
      }

      const serialized = JSON.stringify(value);
      localStorage.setItem(key, serialized);
      return true;
    } catch (error) {
      console.error("Storage error:", error);
      return false;
    }
  }

  static get(key, defaultValue = null) {
    try {
      const item = localStorage.getItem(key);
      return item ? safeJSONParse(item, defaultValue) : defaultValue;
    } catch (error) {
      console.error("Storage read error:", error);
      return defaultValue;
    }
  }

  static remove(key) {
    try {
      localStorage.removeItem(key);
      return true;
    } catch (error) {
      console.error("Storage remove error:", error);
      return false;
    }
  }
}

document.addEventListener("securitypolicyviolation", (e) => {
  console.error("CSP Violation:", {
    blockedURI: e.blockedURI,
    violatedDirective: e.violatedDirective,
    originalPolicy: e.originalPolicy,
  });

  fetch("/api/csp-report", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      blockedURI: e.blockedURI,
      violatedDirective: e.violatedDirective,
      timestamp: new Date().toISOString(),
    }),
  }).catch((err) => console.error("Failed to send CSP report:", err));
});

export {
  safeSetInnerHTML,
  escapeHTML,
  parseMarkdownSafe,
  renderContactSafe,
  safeJSONParse,
  handleWebSocketMessage,
  safeMerge,
  isValidURL,
  safeOpenURL,
  RateLimiter,
  SecureStorage,
  messageLimiter,
};
