import { UI } from './ui.js';
import gsap from 'gsap';

export class Chat {
    constructor() {
        this.ui = new UI();
        this.bindEvents();
    }

    bindEvents() {
        const sendBtn = document.querySelector('.btn-primary');
        const input = document.querySelector('.chat-input');

        if (sendBtn && input) {
            sendBtn.addEventListener('click', () => this.sendMessage());
            input.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    this.sendMessage();
                }
            });
        }
    }

    sendMessage() {
        const input = document.querySelector('.chat-input');
        const text = input.value.trim();

        if (text) {
            const msgElement = this.ui.createMessageElement(text, 'own');

            // Animate entry
            gsap.fromTo(msgElement,
                { opacity: 0, scale: 0.8, x: 20 },
                { opacity: 1, scale: 1, x: 0, duration: 0.3, ease: "back.out(1.7)" }
            );

            this.ui.appendMessage(msgElement);
            input.value = '';
            input.style.height = 'auto'; // Reset height
        }
    }
}
