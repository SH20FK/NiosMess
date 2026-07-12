import ScrollGallery from "@/components/scroll-gallery"

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col">
      <section className="flex h-screen flex-col items-center justify-center gap-6 px-4 text-center">
        <span className="text-sm font-semibold tracking-widest text-primary uppercase">
          NiosMess
        </span>
        <h1 className="max-w-2xl text-5xl font-bold leading-tight tracking-tight md:text-7xl">
          Your private
          <br />
          messaging hub
        </h1>
        <p className="max-w-md text-base text-zinc-500 dark:text-zinc-400">
          E2EE, channels, groups, voice, media sharing and NiosGram — everything in one app with Material You design.
        </p>
      </section>

      <ScrollGallery />

      <footer className="flex items-center justify-center py-12 text-sm text-zinc-400">
        &copy; {new Date().getFullYear()} NiosMess
      </footer>
    </main>
  )
}
