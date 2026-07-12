import type { Metadata } from "next"
import "./globals.css"

export const metadata: Metadata = {
  title: "NiosMess",
  description: "Messenger with E2EE, channels, groups, and NiosGram",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="ru" className="h-full antialiased">
      <body className="min-h-full bg-zinc-50 font-sans text-zinc-900 dark:bg-black dark:text-zinc-50">
        {children}
      </body>
    </html>
  )
}
