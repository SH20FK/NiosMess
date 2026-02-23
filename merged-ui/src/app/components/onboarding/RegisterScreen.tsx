import { motion } from 'motion/react';
import { ArrowLeft, Mail, Lock, User, Eye, EyeOff } from 'lucide-react';
import { useState } from 'react';
import { Screen } from '../../App';
import { register } from '../../lib/api';
import { Session } from '../../lib/session';

interface RegisterScreenProps {
  onNavigate: (screen: Screen, data?: any) => void;
  onRegister: (session: Session) => void;
}

export function RegisterScreen({ onNavigate, onRegister }: RegisterScreenProps) {
  const [showPassword, setShowPassword] = useState(false);
  const [name, setName] = useState('');
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    setError(null);
    if (!name || !username || !email || !password) {
      setError('Заполните все поля');
      return;
    }
    setLoading(true);
    try {
      const data = await register({ email, password, username, name, code: code || undefined });
      if (data?.status === 'wait_code') {
        setError('Нужен код подтверждения. Проверьте почту.');
        setLoading(false);
        return;
      }
      if (data?.token && data?.username) {
        onRegister({ token: data.token, username: data.username, name: data.name || name });
      } else {
        setError('Не удалось зарегистрироваться');
      }
    } catch (err: any) {
      setError(err?.detail || 'Ошибка регистрации');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="w-full h-full flex items-center justify-center" style={{ background: 'var(--nm-bg)' }}>
      <motion.div
        initial={{ opacity: 0, x: 20 }}
        animate={{ opacity: 1, x: 0 }}
        exit={{ opacity: 0, x: -20 }}
        transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
        className="w-full max-w-md px-8"
      >
        <button
          onClick={() => onNavigate('welcome')}
          className="flex items-center gap-2 mb-8 transition-all duration-200 hover:gap-3"
          style={{ color: 'var(--nm-text-secondary)' }}
        >
          <ArrowLeft className="w-5 h-5" />
          <span>Назад</span>
        </button>

        <div className="flex justify-center mb-6">
          <div className="text-6xl">??</div>
        </div>

        <h2 className="text-3xl font-bold text-center mb-2" style={{ color: 'var(--nm-text)' }}>
          Регистрация
        </h2>
        <p className="text-center mb-8" style={{ color: 'var(--nm-text-secondary)' }}>
          Создайте аккаунт и начните общение
        </p>

        <div className="flex flex-col gap-4">
          <div>
            <label className="block mb-2 text-sm font-medium" style={{ color: 'var(--nm-text)' }}>
              Имя
            </label>
            <div className="relative">
              <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5" style={{ color: 'var(--nm-text-secondary)' }} />
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Ваше имя"
                className="w-full pl-12 pr-4 py-3 rounded-xl border-2 transition-all duration-200 outline-none focus:border-[var(--nm-accent)]"
                style={{
                  background: 'var(--nm-surface)',
                  color: 'var(--nm-text)',
                  borderColor: 'var(--nm-border)'
                }}
              />
            </div>
          </div>

          <div>
            <label className="block mb-2 text-sm font-medium" style={{ color: 'var(--nm-text)' }}>
              Логин
            </label>
            <div className="relative">
              <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5" style={{ color: 'var(--nm-text-secondary)' }} />
              <input
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="username"
                className="w-full pl-12 pr-4 py-3 rounded-xl border-2 transition-all duration-200 outline-none focus:border-[var(--nm-accent)]"
                style={{
                  background: 'var(--nm-surface)',
                  color: 'var(--nm-text)',
                  borderColor: 'var(--nm-border)'
                }}
              />
            </div>
          </div>

          <div>
            <label className="block mb-2 text-sm font-medium" style={{ color: 'var(--nm-text)' }}>
              Email
            </label>
            <div className="relative">
              <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5" style={{ color: 'var(--nm-text-secondary)' }} />
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="your@email.com"
                className="w-full pl-12 pr-4 py-3 rounded-xl border-2 transition-all duration-200 outline-none focus:border-[var(--nm-accent)]"
                style={{
                  background: 'var(--nm-surface)',
                  color: 'var(--nm-text)',
                  borderColor: 'var(--nm-border)'
                }}
              />
            </div>
          </div>

          <div>
            <label className="block mb-2 text-sm font-medium" style={{ color: 'var(--nm-text)' }}>
              Пароль
            </label>
            <div className="relative">
              <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5" style={{ color: 'var(--nm-text-secondary)' }} />
              <input
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Введите пароль"
                className="w-full pl-12 pr-12 py-3 rounded-xl border-2 transition-all duration-200 outline-none focus:border-[var(--nm-accent)]"
                style={{
                  background: 'var(--nm-surface)',
                  color: 'var(--nm-text)',
                  borderColor: 'var(--nm-border)'
                }}
              />
              <button
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-4 top-1/2 -translate-y-1/2 transition-colors duration-200"
                style={{ color: 'var(--nm-text-secondary)' }}
              >
                {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
              </button>
            </div>
          </div>

          <div>
            <label className="block mb-2 text-sm font-medium" style={{ color: 'var(--nm-text)' }}>
              Код подтверждения (если требуется)
            </label>
            <input
              type="text"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder="123456"
              className="w-full px-4 py-3 rounded-xl border-2 transition-all duration-200 outline-none focus:border-[var(--nm-accent)]"
              style={{
                background: 'var(--nm-surface)',
                color: 'var(--nm-text)',
                borderColor: 'var(--nm-border)'
              }}
            />
          </div>

          {error && (
            <div className="text-sm px-4 py-3 rounded-xl" style={{ background: 'rgba(255,76,76,0.12)', color: '#ff7a7a' }}>
              {error}
            </div>
          )}

          <button
            onClick={handleSubmit}
            disabled={loading}
            className="w-full mt-2 px-8 py-4 rounded-xl font-medium transition-all duration-300 hover:scale-[1.02] active:scale-[0.98] disabled:opacity-60"
            style={{
              background: 'var(--nm-accent)',
              color: 'white',
              boxShadow: `0 8px 32px var(--nm-shadow)`
            }}
          >
            {loading ? 'Создание...' : 'Создать аккаунт'}
          </button>

          <p className="text-center mt-4" style={{ color: 'var(--nm-text-secondary)' }}>
            Уже есть аккаунт?{' '}
            <button
              onClick={() => onNavigate('login')}
              className="font-medium transition-colors duration-200"
              style={{ color: 'var(--nm-accent)' }}
            >
              Войти
            </button>
          </p>
        </div>
      </motion.div>
    </div>
  );
}

