"use client"

import type { ScreenshotSlide } from "@/data/screenshots"

export default function PhoneMockup({ slide }: { slide: ScreenshotSlide }) {
  return (
    <div className="relative shrink-0 select-none">
      {/* glow */}
      <div className="absolute -inset-4 rounded-[48px] bg-primary/10 blur-2xl" />

      {/* body */}
      <div className="relative z-10 h-[580px] w-[280px] overflow-hidden rounded-[40px] border-4 border-zinc-800 bg-zinc-900 shadow-2xl shadow-primary/20">
        {/* notch */}
        <div className="absolute left-1/2 top-0 z-20 h-6 w-32 -translate-x-1/2 rounded-b-2xl bg-zinc-900" />
        <div className="absolute left-1/2 top-1.5 z-20 h-2.5 w-2.5 -translate-x-1/2 rounded-full bg-zinc-800" />

        {/* screen */}
        <div className="h-full w-full pt-8">
          <img
            src={slide.src}
            alt={slide.label}
            className="h-full w-full object-cover"
            draggable={false}
          />
        </div>

        {/* home indicator */}
        <div className="absolute bottom-2 left-1/2 z-20 h-1 w-28 -translate-x-1/2 rounded-full bg-zinc-700" />
      </div>
    </div>
  )
}
