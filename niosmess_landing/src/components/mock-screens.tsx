"use client"

import { useState, useRef, useEffect } from "react"
import { motion, AnimatePresence } from "framer-motion"
import { CHATS, MESSAGES, CHANNEL_POSTS, NIOSGRAM_POSTS, USERS, ME } from "@/data/mock-data"

function Avatar({ color, name, size = 36 }: { color: string; name: string; size?: number }) {
  return (
    <div
      className="flex shrink-0 items-center justify-center rounded-full font-bold text-white"
      style={{ width: size, height: size, backgroundColor: color, fontSize: size * 0.4 }}
    >
      {name.charAt(0)}
    </div>
  )
}

function StatusBar() {
  return (
    <div className="flex h-10 items-center justify-between px-5 text-[10px] font-semibold text-white/70">
      <span>9:41</span>
      <div className="flex items-center gap-1">
        <div className="h-2.5 w-4 rounded-sm border border-white/50" />
        <svg className="h-3 w-3" viewBox="0 0 24 24" fill="currentColor"><path d="M1 9l2 2c4.97-4.97 13.03-4.97 18 0l2-2C16.93 2.93 7.08 2.93 1 9zm8 8l3 3 3-3c-1.65-1.66-4.34-1.66-6 0zm-4-4l2 2c2.76-2.76 7.24-2.76 10 0l2-2C15.14 9.14 8.87 9.14 5 13z" /></svg>
      </div>
    </div>
  )
}

function AppBar({ title, color, onBack, right }: { title: string; color: string; onBack?: () => void; right?: React.ReactNode }) {
  return (
    <div className="flex h-11 items-center gap-2 px-2" style={{ backgroundColor: color }}>
      {onBack && (
        <button onClick={onBack} className="flex h-8 w-8 items-center justify-center rounded-full text-white/90 hover:bg-white/10">
          <svg className="h-5 w-5" viewBox="0 0 24 24" fill="currentColor"><path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z" /></svg>
        </button>
      )}
      <span className="flex-1 truncate text-[14px] font-bold text-white">{title}</span>
      {right}
    </div>
  )
}

function BottomNav({ active, onTab }: { active: number; onTab?: (i: number) => void }) {
  const tabs = [
    { label: "Chats", icon: "M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z" },
    { label: "Gram", icon: "M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" },
    { label: "Profile", icon: "M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" },
  ]
  return (
    <div className="flex h-14 items-center justify-around border-t border-white/10 bg-zinc-900/95">
      {tabs.map((tab, i) => (
        <button key={tab.label} onClick={() => onTab?.(i)} className="flex flex-col items-center gap-0.5">
          <svg className="h-5 w-5" viewBox="0 0 24 24" fill={active === i ? "#6750a4" : "none"} stroke={active === i ? "#6750a4" : "rgba(255,255,255,0.4)"} strokeWidth={1.5}>
            <path d={tab.icon} />
          </svg>
          <span className="text-[9px]" style={{ color: active === i ? "#6750a4" : "rgba(255,255,255,0.4)" }}>{tab.label}</span>
        </button>
      ))}
    </div>
  )
}

export function MockChats() {
  return (
    <div className="flex h-full flex-col bg-zinc-900">
      <StatusBar />
      <AppBar title="NiosMess" color="#6750a4" right={<div className="flex gap-1">
        <svg className="h-5 w-5 text-white/80" viewBox="0 0 24 24" fill="currentColor"><path d="M15.5 14h-.79l-.28-.27A6.471 6.471 0 0016 9.5 6.5 6.5 0 109.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z" /></svg>
        <svg className="h-5 w-5 text-white/80" viewBox="0 0 24 24" fill="currentColor"><path d="M12 22c1.1 0 2-.9 2-2h-4c0 1.1.89 2 2 2zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2z" /></svg>
      </div>} />
      <div className="flex-1 overflow-y-auto">
        {CHATS.map((chat) => (
          <div key={chat.id} className="flex cursor-pointer items-center gap-3 px-4 py-3 transition-colors hover:bg-white/5">
            <div className="relative">
              <Avatar color={chat.user.color} name={chat.user.name} />
              {chat.user.online && <div className="absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full border-2 border-zinc-900 bg-green-500" />}
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex items-center justify-between">
                <span className="truncate text-[13px] font-semibold text-white">{chat.user.name}</span>
                <span className="shrink-0 text-[10px] text-zinc-500">{chat.time}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="truncate text-[12px] text-zinc-400">{chat.lastMessage}</span>
                {chat.unread > 0 && (
                  <span className="ml-2 flex h-4 min-w-4 items-center justify-center rounded-full bg-[#6750a4] px-1 text-[9px] font-bold text-white">
                    {chat.unread}
                  </span>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
      <BottomNav active={0} />
    </div>
  )
}

export function MockMessages() {
  const [messages, setMessages] = useState(MESSAGES[1])
  const [input, setInput] = useState("")
  const [sending, setSending] = useState(false)
  const bottomRef = useRef<HTMLDivElement>(null!)

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: "smooth" }) }, [messages])

  const send = () => {
    const text = input.trim()
    if (!text || sending) return
    setSending(true)
    setInput("")
    const optimistic: MockMessage = { id: Date.now(), senderId: 1, text, time: "только что", delivered: false }
    setMessages((prev) => [...prev, optimistic])
    setTimeout(() => {
      setMessages((prev) =>
        prev.map((m) => (m.id === optimistic.id ? { ...m, delivered: true } : m))
      )
      const reply: MockMessage = {
        id: Date.now() + 1,
        senderId: 2,
        text: getReply(text),
        time: "только что",
        delivered: true,
      }
      setMessages((prev) => [...prev, reply])
      setSending(false)
    }, 1200 + Math.random() * 800)
  }

  return (
    <div className="flex h-full flex-col bg-zinc-900">
      <StatusBar />
      <AppBar title="Alina" color="#e85d75" onBack={() => {}} right={
        <svg className="h-5 w-5 text-white/80" viewBox="0 0 24 24" fill="currentColor"><path d="M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z" /></svg>
      } />
      <div className="flex-1 space-y-1 overflow-y-auto p-3">
        {messages.map((msg) => (
          <motion.div
            key={msg.id}
            initial={{ opacity: 0, y: 10, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            className={`flex ${msg.senderId === 1 ? "justify-end" : "justify-start"}`}
          >
            <div
              className={`max-w-[75%] rounded-2xl px-3 py-2 text-[12px] leading-relaxed ${
                msg.senderId === 1
                  ? "rounded-br-md bg-[#6750a4] text-white"
                  : "rounded-bl-md bg-zinc-800 text-zinc-100"
              }`}
            >
              {msg.text}
              <div className={`mt-0.5 flex items-center justify-end gap-1 text-[9px] ${msg.senderId === 1 ? "text-white/60" : "text-zinc-500"}`}>
                {msg.time}
                {msg.senderId === 1 && (
                  <svg className="h-3 w-3" viewBox="0 0 24 24" fill={msg.delivered ? "#4fc3f7" : "currentColor"}>
                    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
                  </svg>
                )}
              </div>
            </div>
          </motion.div>
        ))}
        <div ref={bottomRef} />
      </div>
      <div className="flex items-center gap-2 border-t border-white/10 px-3 py-2">
        <button className="flex h-8 w-8 items-center justify-center text-zinc-400 hover:text-white">
          <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}><path d="M14 5l7 7m0 0l-7 7m7-7H3" /></svg>
        </button>
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && send()}
          placeholder="Message..."
          className="flex-1 rounded-full bg-zinc-800 px-4 py-2 text-[12px] text-white outline-none placeholder:text-zinc-500"
        />
        <button
          onClick={send}
          disabled={!input.trim() || sending}
          className="flex h-8 w-8 items-center justify-center rounded-full bg-[#6750a4] text-white disabled:opacity-40"
        >
          <svg className="h-4 w-4" viewBox="0 0 24 24" fill="currentColor"><path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z" /></svg>
        </button>
      </div>
    </div>
  )
}

function getReply(text: string): string {
  const replies = [
    "Ого, круто! 😊", "Понял, договорились", "Да, отличная идея!",
    "Хм, надо подумать 🤔", "Супер, так и сделаем!", "Согласен 👍",
    "Не уверен, давай обсудим", "Ок, я за!", "Интересно, расскажи подробнее",
  ]
  return replies[Math.floor(Math.random() * replies.length)]
}

export function MockGroup() {
  const members = USERS.slice(0, 5)
  return (
    <div className="flex h-full flex-col bg-zinc-900">
      <StatusBar />
      <AppBar title="Dev Chat" color="#00bcd4" onBack={() => {}} />
      <div className="flex-1 overflow-y-auto p-4">
        <div className="mb-4 flex flex-col items-center gap-2">
          <div className="flex -space-x-2">
            {members.map((u) => <Avatar key={u.id} color={u.color} name={u.name} size={32} />)}
          </div>
          <span className="text-[13px] font-semibold text-white">Dev Chat</span>
          <span className="text-[11px] text-zinc-500">8 members, 3 online</span>
        </div>
        <div className="space-y-3">
          {[
            { name: "Mike", color: "#4caf50", text: "Сделал рефакторинг модуля авторизации" },
            { name: "Alina", color: "#e85d75", text: "Отлично, Mike! Я посмотрю код" },
            { name: "Dmitry", color: "#4f8ef7", text: "Ребят, кто завтра деплой делает?" },
          ].map((m, i) => (
            <div key={i} className="flex gap-2">
              <Avatar color={m.color} name={m.name} size={28} />
              <div>
                <span className="text-[11px] font-semibold text-white">{m.name}</span>
                <p className="mt-0.5 text-[12px] leading-relaxed text-zinc-300">{m.text}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

export function MockChannel() {
  return (
    <div className="flex h-full flex-col bg-zinc-900">
      <StatusBar />
      <AppBar title="Tech News" color="#ff9100" onBack={() => {}} right={
        <svg className="h-5 w-5 text-white/80" viewBox="0 0 24 24" fill="currentColor"><path d="M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z" /></svg>
      } />
      <div className="flex-1 overflow-y-auto space-y-3 p-3">
        {CHANNEL_POSTS.map((post) => (
          <motion.div key={post.id} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="rounded-2xl bg-zinc-800/60 p-3">
            <h3 className="text-[13px] font-bold text-white">{post.title}</h3>
            <p className="mt-1 text-[11px] leading-relaxed text-zinc-400">{post.text}</p>
            <div className="mt-2 flex items-center gap-3 text-[10px] text-zinc-500">
              <span>👁 {post.views}</span>
              <span>💬 {post.comments}</span>
              <span className="ml-auto">{post.time}</span>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  )
}

export function MockNiosgram() {
  return (
    <div className="flex h-full flex-col bg-zinc-900">
      <StatusBar />
      <AppBar title="NiosGram" color="#e91e63" onBack={() => {}} right={
        <svg className="h-5 w-5 text-white/80" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}><path d="M12 5v14m-7-7h14" /></svg>
      } />
      <div className="flex-1 overflow-y-auto space-y-3 p-3">
        {NIOSGRAM_POSTS.map((post) => (
          <motion.div key={post.id} initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} className="rounded-2xl bg-zinc-800/60 p-3">
            <div className="flex items-center gap-2">
              <Avatar color={post.color} name={post.name} size={28} />
              <div>
                <span className="text-[12px] font-semibold text-white">{post.name}</span>
                <span className="ml-1 text-[10px] text-zinc-500">@{post.username}</span>
              </div>
            </div>
            <p className="mt-2 text-[12px] leading-relaxed text-zinc-200">{post.text}</p>
            <div className="mt-2 flex items-center gap-3 text-[10px] text-zinc-500">
              <span>❤️ {post.likes}</span>
              <span>💬 {post.comments}</span>
              <span className="ml-auto">{post.time}</span>
            </div>
          </motion.div>
        ))}
      </div>
      <BottomNav active={1} />
    </div>
  )
}

export function MockVoice() {
  return (
    <div className="flex h-full flex-col bg-zinc-900">
      <StatusBar />
      <AppBar title="Marina" color="#9b5de5" onBack={() => {}} />
      <div className="flex-1 overflow-y-auto p-4">
        <div className="flex flex-col items-center gap-4">
          <Avatar color="#9b5de5" name="M" size={64} />
          <span className="text-[13px] font-semibold text-white">Voice message</span>
          <span className="text-[11px] text-zinc-500">0:24 / 1:12</span>
          <div className="relative h-1 w-full rounded-full bg-zinc-700">
            <motion.div
              className="h-full w-1/3 rounded-full bg-[#9b5de5]"
              animate={{ width: ["33%", "45%", "38%", "52%"] }}
              transition={{ duration: 3, repeat: Infinity, ease: "linear" }}
            />
          </div>
          <div className="flex items-center gap-6">
            <button className="text-zinc-400"><svg className="h-5 w-5" viewBox="0 0 24 24" fill="currentColor"><path d="M6 6h2v12H6zm3.5 6l8.5 6V6z" /></svg></button>
            <button className="flex h-12 w-12 items-center justify-center rounded-full bg-[#9b5de5] text-white">
              <svg className="h-6 w-6" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z" /></svg>
            </button>
            <button className="text-zinc-400"><svg className="h-5 w-5" viewBox="0 0 24 24" fill="currentColor"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z" /></svg></button>
          </div>
        </div>
      </div>
    </div>
  )
}

const THEMES_DATA = [
  { name: "Light", bg: "#fef7ff", text: "#1d1b20", primary: "#6750a4", card: "#f3edf7" },
  { name: "Dark", bg: "#1c1b1f", text: "#e6e1e5", primary: "#d0bcff", card: "#2b2930" },
  { name: "AMOLED", bg: "#000000", text: "#e6e1e5", primary: "#bb86fc", card: "#121212" },
]

export function MockThemes() {
  const [active, setActive] = useState(0)
  const t = THEMES_DATA[active]
  return (
    <div className="flex h-full flex-col" style={{ backgroundColor: t.bg, color: t.text }}>
      <StatusBar />
      <div className="flex h-11 items-center justify-center gap-2 px-4">
        {THEMES_DATA.map((th, i) => (
          <button key={th.name} onClick={() => setActive(i)}
            className={`rounded-full px-3 py-1 text-[10px] font-semibold transition-all ${i === active ? "shadow-sm" : "opacity-60"}`}
            style={{ backgroundColor: i === active ? t.primary : "transparent", color: i === active ? "#fff" : t.text, border: `1px solid ${t.primary}40` }}
          >
            {th.name}
          </button>
        ))}
      </div>
      <div className="flex-1 p-3 space-y-2">
        {[1, 2, 3].map((i) => (
          <motion.div key={i} layout className="rounded-2xl p-3" style={{ backgroundColor: t.card }}>
            <div className="flex items-center gap-2">
              <div className="h-8 w-8 rounded-full" style={{ backgroundColor: t.primary }} />
              <div>
                <div className="h-2 w-20 rounded-full" style={{ backgroundColor: t.text }} />
                <div className="mt-1 h-1.5 w-14 rounded-full" style={{ backgroundColor: `${t.text}60` }} />
              </div>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  )
}

export function MockProfile() {
  const user = USERS[0]
  return (
    <div className="flex h-full flex-col bg-zinc-900">
      <StatusBar />
      <AppBar title="Profile" color="#1565c0" />
      <div className="flex-1 overflow-y-auto p-4">
        <div className="flex flex-col items-center gap-2">
          <Avatar color={user.color} name={user.name} size={56} />
          <span className="text-[15px] font-bold text-white">{user.name}</span>
          <span className="text-[11px] text-zinc-500">@{user.username}</span>
        </div>
        <div className="mt-4 space-y-2">
          {[
            { icon: "M5.121 17.804A9 9 0 0112 15c2.21 0 4.21.9 5.66 2.34M15 11a3 3 0 11-6 0 3 3 0 016 0z", label: "Appearance" },
            { icon: "M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z", label: "Privacy" },
            { icon: "M9 12h6m-3-3v6m-7 4h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z", label: "Storage" },
            { icon: "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z", label: "About" },
          ].map((item, i) => (
            <motion.div key={i} whileTap={{ scale: 0.98 }} className="flex cursor-pointer items-center gap-3 rounded-xl bg-zinc-800/60 px-4 py-3">
              <svg className="h-5 w-5 text-zinc-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.5}><path d={item.icon} /></svg>
              <span className="text-[13px] text-white">{item.label}</span>
              <svg className="ml-auto h-4 w-4 text-zinc-600" viewBox="0 0 24 24" fill="currentColor"><path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z" /></svg>
            </motion.div>
          ))}
        </div>
      </div>
      <BottomNav active={2} />
    </div>
  )
}
