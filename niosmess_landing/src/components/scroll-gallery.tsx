"use client"

import { useRef } from "react"
import { motion, useScroll, useTransform } from "framer-motion"

const SLIDES = [
  { id: "chats",    label: "Chats",     desc: "Чат-лист с последними сообщениями, поиском и фильтром." },
  { id: "messages", label: "Messages",  desc: "Живой диалог с текстом, E2EE и реакциями на сообщения." },
  { id: "group",    label: "Groups",    desc: "Групповой чат с участниками, ролями и управлением." },
  { id: "channel",  label: "Channels",  desc: "Канал с постами, комментариями и просмотрами." },
  { id: "niosgram", label: "NiosGram",  desc: "Лента постов с медиа, лайками и комментариями." },
  { id: "voice",    label: "Voice",     desc: "Голосовые сообщения и видеоплеер встроенные в чат." },
  { id: "themes",   label: "Themes",    desc: "Светлая, тёмная, AMOLED — Material You на выбор." },
  { id: "profile",  label: "Profile",   desc: "Профиль с аватаром, бейджами и настройками." },
]

const TOTAL = SLIDES.length
const INPUT = Array.from({ length: TOTAL }, (_, i) => i / (TOTAL - 1))
const OUTPUT = Array.from({ length: TOTAL }, (_, i) => i)

export default function ScrollGallery() {
  const containerRef = useRef<HTMLDivElement>(null!)

  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"],
  })

  const currentIndex = useTransform(scrollYProgress, INPUT, OUTPUT, { clamp: true })

  return (
    <section ref={containerRef} className="relative" style={{ height: `${TOTAL * 100}vh` }}>
      <div className="sticky top-0 flex h-screen items-center gap-10 overflow-hidden px-6 md:px-16 lg:px-24">

        {/* phone */}
        <div className="hidden shrink-0 md:block">
          <div className="relative h-[600px] w-[280px]">
            {/* glow */}
            <div className="absolute -inset-4 rounded-[48px] bg-[#6750a4]/10 blur-2xl" />
            {/* body */}
            <div className="relative z-10 h-full overflow-hidden rounded-[40px] border-4 border-zinc-800 bg-zinc-900 shadow-2xl shadow-[#6750a4]/20">
              <div className="absolute left-1/2 top-0 z-20 h-6 w-32 -translate-x-1/2 rounded-b-2xl bg-zinc-900" />
              <div className="absolute left-1/2 top-1.5 z-20 h-2.5 w-2.5 -translate-x-1/2 rounded-full bg-zinc-800" />
              <div className="h-full overflow-hidden rounded-[36px]">
                {SLIDES.map((slide, i) => (
                  <motion.img
                    key={slide.id}
                    src={`/screens/${slide.id}.png`}
                    alt={slide.label}
                    className="absolute inset-0 h-full w-full object-cover rounded-[36px]"
                    style={{ opacity: useTransform(currentIndex, [i - 0.5, i, i + 0.5], [0, 1, 0]) }}
                  />
                ))}
              </div>
              <div className="absolute bottom-2 left-1/2 z-20 h-1 w-28 -translate-x-1/2 rounded-full bg-zinc-700" />
            </div>
          </div>
        </div>

        {/* text */}
        <div className="flex flex-1 flex-col justify-center gap-14">
          {SLIDES.map((slide, i) => (
            <motion.div
              key={slide.id}
              className="flex flex-col gap-2"
              style={{
                opacity: useTransform(currentIndex, [i - 0.5, i, i + 0.5], [0.25, 1, 0.25]),
                scale: useTransform(currentIndex, [i - 0.5, i, i + 0.5], [0.96, 1, 0.96]),
              }}
            >
              <span className="text-sm font-semibold tracking-widest text-[#6750a4] uppercase">
                0{i + 1}
              </span>
              <h2 className="text-3xl font-bold tracking-tight md:text-4xl">
                {slide.label}
              </h2>
              <p className="max-w-md text-base leading-relaxed text-zinc-500 dark:text-zinc-400">
                {slide.desc}
              </p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}
