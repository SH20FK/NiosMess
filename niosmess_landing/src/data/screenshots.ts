export interface ScreenshotSlide {
  id: string
  src: string
  label: string
  description: string
}

const SCREENS: ScreenshotSlide[] = [
  {
    id: "chats",
    src: "/screens/shot-chats.png",
    label: "Chats",
    description: "Чат-лист с последними сообщениями, поиском и фильтром по каналам и группам.",
  },
  {
    id: "messages",
    src: "/screens/shot-messages.png",
    label: "Messages",
    description: "Живой диалог с текстом, медиа, E2EE и реакциями на сообщения.",
  },
  {
    id: "group",
    src: "/screens/shot-group.png",
    label: "Groups",
    description: "Групповой чат с участниками, ролями и управлением.",
  },
  {
    id: "channel",
    src: "/screens/shot-channel.png",
    label: "Channels",
    description: "Канал с постами, комментариями и просмотрами.",
  },
  {
    id: "niosgram",
    src: "/screens/shot-niosgram.png",
    label: "NiosGram",
    description: "Лента постов с медиа, лайками и комментариями.",
  },
  {
    id: "voice",
    src: "/screens/shot-voice.png",
    label: "Voice & Media",
    description: "Голосовые сообщения, видеоплеер и галерея встроенные в чат.",
  },
  {
    id: "themes",
    src: "/screens/shot-themes.png",
    label: "Themes",
    description: "Настраиваемая тема: светлая, тёмная, AMOLED, Dynamic — Material You.",
  },
  {
    id: "profile",
    src: "/screens/shot-profile.png",
    label: "Profile",
    description: "Профиль пользователя с аватаром, бейджами и настройками.",
  },
]

export default SCREENS
