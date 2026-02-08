import { motion } from 'motion/react';
import { ArrowLeft, User, Mail, Lock, Eye, EyeOff } from 'lucide-react';
import { useState } from 'react';
import { Screen } from '../../App';

interface RegisterScreenProps {
  onNavigate: (screen: Screen) => void;
}

export function RegisterScreen({ onNavigate }: RegisterScreenProps) {
  const [showPassword, setShowPassword] = useState(false);

  return (
    <div className="w-full h-full flex items-center justify-center" style={{ background: 'var(--nm-bg)' }}>
      <motion.div
        initial={{ opacity: 0, x: 20 }}
        animate={{ opacity: 1, x: 0 }}
        exit={{ opacity: 0, x: -20 }}
        transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
        className="w-full max-w-md px-8"
      >
        {/* Back button */}
        <button
          onClick={() => onNavigate('welcome')}
          className="flex items-center gap-2 mb-8 transition-all duration-200 hover:gap-3"
          style={{ color: 'var(--nm-text-secondary)' }}
        >
          <ArrowLeft className="w-5 h-5" />
          <span>Назад</span>
        </button>

        {/* Fox mascot - smaller */}
        <div className="flex justify-center mb-6">
          <div className="text-6xl">🦊</div>
        </div>

        <h2 className="text-3xl font-bold text-center mb-2" style={{ color: 'var(--nm-text)' }}>
          Регистрация
        </h2>
        <p className="text-center mb-8" style={{ color: 'var(--nm-text-secondary)' }}>
          Создайте свой аккаунт в NiosMess
        </p>

        <div className="flex flex-col gap-4">
          {/* Username */}
          <div>
            <label className="block mb-2 text-sm font-medium" style={{ color: 'var(--nm-text)' }}>
              Имя пользователя
            </label>
            <div className="relative">
              <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5" style={{ color: 'var(--nm-text-secondary)' }} />
              <input
                type="text"
                placeholder="Введите имя пользователя"
                className="w-full pl-12 pr-4 py-3 rounded-xl border-2 transition-all duration-200 outline-none focus:border-[var(--nm-accent)]"
                style={{
                  background: 'var(--nm-surface)',
                  color: 'var(--nm-text)',
                  borderColor: 'var(--nm-border)'
                }}
              />
            </div>
          </div>

          {/* Email */}
          <div>
            <label className="block mb-2 text-sm font-medium" style={{ color: 'var(--nm-text)' }}>
              Email
            </label>
            <div className="relative">
              <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5" style={{ color: 'var(--nm-text-secondary)' }} />
              <input
                type="email"
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

          {/* Password */}
          <div>
            <label className="block mb-2 text-sm font-medium" style={{ color: 'var(--nm-text)' }}>
              Пароль
            </label>
            <div className="relative">
              <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5" style={{ color: 'var(--nm-text-secondary)' }} />
              <input
                type={showPassword ? 'text' : 'password'}
                placeholder="Минимум 8 символов"
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

          {/* Register button */}
          <button
            onClick={() => onNavigate('main')}
            className="w-full mt-4 px-8 py-4 rounded-xl font-medium transition-all duration-300 hover:scale-[1.02] active:scale-[0.98]"
            style={{
              background: 'var(--nm-accent)',
              color: 'white',
              boxShadow: `0 8px 32px var(--nm-shadow)`
            }}
          >
            Зарегистрироваться
          </button>

          {/* Login link */}
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
