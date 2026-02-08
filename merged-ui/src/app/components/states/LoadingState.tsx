import { motion } from 'motion/react';

export function LoadingState() {
  return (
    <div className="w-full h-full flex items-center justify-center" style={{ background: 'var(--nm-bg)' }}>
      <div className="flex flex-col items-center">
        {/* Animated fox */}
        <motion.div
          animate={{
            scale: [1, 1.1, 1],
            rotate: [0, 5, -5, 0],
          }}
          transition={{
            duration: 2,
            repeat: Infinity,
            ease: "easeInOut"
          }}
          className="text-6xl mb-6"
        >
          🦊
        </motion.div>

        {/* Glow effect */}
        <motion.div
          className="absolute blur-3xl"
          style={{ background: 'var(--nm-glow)' }}
          animate={{
            opacity: [0.3, 0.6, 0.3],
            scale: [1, 1.5, 1],
          }}
          transition={{
            duration: 2,
            repeat: Infinity,
            ease: "easeInOut"
          }}
        />

        {/* Loading dots */}
        <div className="flex gap-2">
          {[0, 1, 2].map((i) => (
            <motion.div
              key={i}
              className="w-3 h-3 rounded-full"
              style={{ background: 'var(--nm-accent)' }}
              animate={{
                y: [0, -12, 0],
                opacity: [0.5, 1, 0.5],
              }}
              transition={{
                duration: 1,
                repeat: Infinity,
                delay: i * 0.2,
                ease: "easeInOut"
              }}
            />
          ))}
        </div>

        <p className="mt-6 text-lg" style={{ color: 'var(--nm-text-secondary)' }}>
          Загрузка...
        </p>
      </div>
    </div>
  );
}
