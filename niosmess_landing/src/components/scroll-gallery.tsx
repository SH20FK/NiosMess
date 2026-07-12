"use client"

import { useRef } from "react"
import { motion, useScroll, useTransform } from "framer-motion"
import PhoneMockup from "@/components/phone-mockup"
import SCREENS from "@/data/screenshots"

const TOTAL_SLIDES = SCREENS.length

const INPUT = Array.from({ length: TOTAL_SLIDES }, (_, i) => i / (TOTAL_SLIDES - 1))
const OUTPUT = Array.from({ length: TOTAL_SLIDES }, (_, i) => i)

export default function ScrollGallery() {
  const containerRef = useRef<HTMLDivElement>(null!)

  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"],
  })

  const currentIndex = useTransform(scrollYProgress, INPUT, OUTPUT, {
    clamp: true,
  })

  return (
    <section
      ref={containerRef}
      className="relative"
      style={{ height: `${TOTAL_SLIDES * 100}vh` }}
    >
      <div className="sticky top-0 flex h-screen items-center gap-12 overflow-hidden px-8 md:px-16 lg:px-24">
        {/* phone */}
        <div className="hidden shrink-0 md:block">
          <motion.div
            initial={{ opacity: 0, y: 40 }}
            whileInView={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease: "easeOut" }}
          >
            {SCREENS.map((slide, i) => (
              <motion.div
                key={slide.id}
                className="absolute inset-0 flex items-center justify-center"
                style={{ opacity: useTransform(currentIndex, [i - 0.5, i, i + 0.5], [0, 1, 0]) }}
              >
                <PhoneMockup slide={slide} />
              </motion.div>
            ))}

            <div style={{ visibility: "hidden" }}>
              <PhoneMockup slide={SCREENS[0]} />
            </div>
          </motion.div>
        </div>

        {/* text */}
        <div className="flex flex-1 flex-col justify-center gap-16">
          {SCREENS.map((slide, i) => (
            <motion.div
              key={slide.id}
              className="flex flex-col gap-2"
              style={{
                opacity: useTransform(currentIndex, [i - 0.5, i, i + 0.5], [0.25, 1, 0.25]),
                scale: useTransform(currentIndex, [i - 0.5, i, i + 0.5], [0.96, 1, 0.96]),
              }}
            >
              <span className="text-sm font-semibold tracking-widest text-primary uppercase">
                0{i + 1}
              </span>
              <h2 className="text-3xl font-bold tracking-tight md:text-4xl">
                {slide.label}
              </h2>
              <p className="max-w-md text-base leading-relaxed text-zinc-500 dark:text-zinc-400">
                {slide.description}
              </p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}
