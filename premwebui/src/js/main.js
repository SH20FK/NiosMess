import gsap from 'gsap';
import { Chat } from './chat.js';

// Design System Initialization
console.log('NiosMess Premium WebUI Initialized');

window.addEventListener('DOMContentLoaded', () => {
    // Initialize Chat Logic
    const chatApp = new Chat();

    // Animate initial elements
    gsap.from('.chat-header', { y: -20, opacity: 0, duration: 0.5, delay: 0.2 });
    gsap.from('.chat-input-area', { y: 20, opacity: 0, duration: 0.5, delay: 0.2 });

    // Mock Data Population
    const chatList = document.getElementById('chat-list');
    const mockChats = [
        { name: 'NiosMess Team', time: '12:02', msg: 'Вау, выглядит просто потрясающе! 😍', active: true, color: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)' },
        { name: 'Александр', time: '11:45', msg: 'Нужно добавить больше анимаций', active: false, color: 'linear-gradient(135deg, #ff9a9e 0%, #fecfef 99%, #fecfef 100%)' },
        { name: 'Дизайн Чат', time: 'Вчера', msg: 'Скинь макеты, плиз', active: false, color: 'linear-gradient(135deg, #a18cd1 0%, #fbc2eb 100%)', online: true },
        { name: 'Memes Channel', time: 'Вчера', msg: 'Photo', active: false, color: 'linear-gradient(to top, #30cfd0 0%, #330867 100%)' },
        { name: 'Support', time: '10:00', msg: 'Ваш тикет #1234 обработан', active: false, color: 'linear-gradient(to right, #4facfe 0%, #00f2fe 100%)' }
    ];

    if (chatList) {
        mockChats.forEach((chat, index) => {
            const item = document.createElement('div');
            item.className = `chat-item ${chat.active ? 'active' : ''}`;
            item.innerHTML = `
                <div class="chat-item-avatar" style="background: ${chat.color}">
                    ${chat.name[0]}
                    ${chat.online ? '<div class="status-dot"></div>' : ''}
                </div>
                <div class="chat-item-content">
                    <div class="chat-item-header">
                        <span class="chat-item-name">${chat.name}</span>
                        <span class="chat-item-time">${chat.time}</span>
                    </div>
                    <div class="chat-item-last-msg">${chat.msg}</div>
                </div>
            `;
            chatList.appendChild(item);

            // Stagger animation
            gsap.from(item, {
                x: -30,
                opacity: 0,
                duration: 0.4,
                delay: 0.1 * index,
                ease: "power2.out"
            });
        });
    }

    // Sidebar Menu Toggle
    const menuBtn = document.querySelector('.menu-trigger');
    const menu = document.getElementById('sidebar-menu');
    if (menuBtn && menu) {
        menuBtn.addEventListener('click', () => {
            menu.classList.toggle('hidden');
            if (!menu.classList.contains('hidden')) {
                gsap.fromTo(menu.children,
                    { opacity: 0, x: -10 },
                    { opacity: 1, x: 0, duration: 0.3, stagger: 0.05 }
                );
            }
        });
    }

    // Chat Item Click Interaction (Demo)
    const emptyState = document.getElementById('empty-state');
    const chatContent = document.getElementById('chat-content');

    if (chatList && emptyState && chatContent) {
        chatList.addEventListener('click', (e) => {
            const item = e.target.closest('.chat-item');
            if (item) {
                // Remove active class from all
                document.querySelectorAll('.chat-item').forEach(el => el.classList.remove('active'));
                item.classList.add('active');

                // Switch View
                emptyState.style.display = 'none';
                chatContent.style.display = 'flex';

                // Animate content entry
                gsap.fromTo(chatContent,
                    { opacity: 0, y: 10 },
                    { opacity: 1, y: 0, duration: 0.3 }
                );

                // Update Header (Mock)
                const name = item.querySelector('.chat-item-name').textContent;
                document.querySelector('.chat-name').textContent = name;
                document.querySelector('.chat-avatar').textContent = name[0];
            }
        });
    }

});
