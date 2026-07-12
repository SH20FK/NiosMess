export interface MockUser {
  id: number
  name: string
  username: string
  color: string
  online: boolean
}

export interface MockChat {
  id: number
  user: MockUser
  lastMessage: string
  time: string
  unread: number
  pinned: boolean
}

export interface MockMessage {
  id: number
  senderId: number
  text: string
  time: string
  delivered: boolean
}

export const ME: MockUser = {
  id: 1,
  name: "You",
  username: "me",
  color: "#6750a4",
  online: true,
}

export const USERS: MockUser[] = [
  { id: 2, name: "Alina", username: "alina", color: "#e85d75", online: true },
  { id: 3, name: "Dmitry", username: "dmitry", color: "#4f8ef7", online: false },
  { id: 4, name: "Sofia", username: "sofia", color: "#f4a261", online: true },
  { id: 5, name: "Vlad", username: "vlad", color: "#2ec4b6", online: true },
  { id: 6, name: "Marina", username: "marina", color: "#9b5de5", online: false },
  { id: 7, name: "Alex", username: "alex", color: "#ff6b6b", online: true },
]

export const CHATS: MockChat[] = [
  { id: 1, user: USERS[0], lastMessage: "Да, завтра в 18:00", time: "14:42", unread: 2, pinned: true },
  { id: 2, user: USERS[1], lastMessage: "Кинул ссылку в канал", time: "13:15", unread: 0, pinned: false },
  { id: 3, user: USERS[2], lastMessage: "Фото с выставки 😍", time: "11:30", unread: 5, pinned: true },
  { id: 4, user: USERS[3], lastMessage: "Го в CS завтра?", time: "10:02", unread: 0, pinned: false },
  { id: 5, user: USERS[4], lastMessage: "Спасибо за помощь!", time: "08:44", unread: 1, pinned: false },
  { id: 6, user: USERS[5], lastMessage: "Новый альбом — огонь 🔥", time: "Вчера", unread: 0, pinned: false },
  { id: 7, user: { id: 8, name: "Dev Chat", username: "dev", color: "#00bcd4", online: true }, lastMessage: "Mike: Сделал рефакторинг", time: "Вчера", unread: 3, pinned: true },
  { id: 8, user: { id: 9, name: "Tech News", username: "tech", color: "#ff9100", online: false }, lastMessage: "Вышел Flutter 4.0 🎉", time: "15:20", unread: 0, pinned: false },
]

export const MESSAGES: Record<number, MockMessage[]> = {
  1: [
    { id: 1, senderId: 1, text: "Привет! Во сколько встреча завтра?", time: "14:30", delivered: true },
    { id: 2, senderId: 2, text: "Привет! В 18:00, как обычно", time: "14:35", delivered: true },
    { id: 3, senderId: 1, text: "Ок, у центрального входа?", time: "14:38", delivered: true },
    { id: 4, senderId: 2, text: "Да, завтра в 18:00", time: "14:42", delivered: true },
  ],
  2: [
    { id: 1, senderId: 3, text: "Смотрел новый фильм?", time: "13:00", delivered: true },
    { id: 2, senderId: 1, text: "Нет еще, стоит?", time: "13:05", delivered: true },
    { id: 3, senderId: 3, text: "Кинул ссылку в канал", time: "13:15", delivered: true },
  ],
  3: [
    { id: 1, senderId: 4, text: "Мы на выставке, фотки 🔥", time: "11:00", delivered: true },
    { id: 2, senderId: 4, text: "Фото с выставки 😍", time: "11:30", delivered: true },
  ],
}

export const CHANNEL_POSTS = [
  { id: 1, title: "Релиз Flutter 4.0", text: "Google анонсировала Flutter 4.0 с нативной компиляцией под iOS и Android, улучшенной производительностью и новым движком рендеринга.", views: 1240, comments: 18, time: "2ч назад" },
  { id: 2, title: "Material You обновление", text: "Новые компоненты Material Design 3: карточки с адаптивной формой, улучшенная типографика и динамические цвета.", views: 856, comments: 7, time: "5ч назад" },
  { id: 3, title: "Open Source недели", text: "Проект NiosMess — messenger с E2EE шифрованием, каналами, группами и встроенной социальной сетью NiosGram.", views: 2341, comments: 42, time: "1д назад" },
]

export const NIOSGRAM_POSTS = [
  { id: 1, username: "alina", name: "Alina Petrova", color: "#e85d75", text: "Закат на озере 🏔️", likes: 42, comments: 8, time: "3ч назад" },
  { id: 2, username: "dm", name: "Dmitry Volkov", color: "#4f8ef7", text: "Собрал новый ПК, полет нормальный 🚀", likes: 28, comments: 15, time: "5ч назад" },
  { id: 3, username: "sofia", name: "Sofia Kim", color: "#f4a261", text: "Мой новый арт — процесс занял 2 недели 🎨", likes: 156, comments: 34, time: "8ч назад" },
]
