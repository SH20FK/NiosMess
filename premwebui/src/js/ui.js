export class UI {
    constructor() {
        this.chatView = document.getElementById('chat-view');
        this.messagesContainer = document.getElementById('messages-container');
        this.chatInput = document.querySelector('.chat-input');

        this.initAutoResizeInput();
        this.scrollToBottom();
    }

    initAutoResizeInput() {
        if (!this.chatInput) return;

        this.chatInput.addEventListener('input', () => {
            this.chatInput.style.height = 'auto';
            this.chatInput.style.height = (this.chatInput.scrollHeight) + 'px';
        });
    }

    scrollToBottom() {
        if (this.messagesContainer) {
            this.messagesContainer.scrollTop = this.messagesContainer.scrollHeight;
        }
    }

    createMessageElement(text, type = 'own') {
        const msgDiv = document.createElement('div');
        msgDiv.className = `message-bubble ${type}`;
        msgDiv.textContent = text;

        const timeDiv = document.createElement('div');
        timeDiv.className = 'message-time';
        timeDiv.textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

        msgDiv.appendChild(timeDiv);
        return msgDiv;
    }

    appendMessage(element) {
        if (this.messagesContainer) {
            this.messagesContainer.appendChild(element);
            this.scrollToBottom();
        }
    }
}
