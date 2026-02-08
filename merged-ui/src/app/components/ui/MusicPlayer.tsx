import { motion } from 'motion/react';
import { Play, Pause, SkipBack, SkipForward, Volume2, Sparkles } from 'lucide-react';
import { useState } from 'react';

export function MusicPlayer() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState(35);

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="relative"
    >
      {/* Mini player in chat */}
      <div
        className="p-5 rounded-2xl relative overflow-hidden"
        style={{
          background: 'var(--nm-surface)',
          border: '1px solid var(--nm-border)',
          boxShadow: `0 8px 32px var(--nm-shadow)`
        }}
      >
        {/* Background gradient */}
        <div
          className="absolute inset-0 opacity-10"
          style={{
            background: `linear-gradient(135deg, var(--nm-accent), transparent)`
          }}
        />

        {/* Content */}
        <div className="relative">
          <div className="flex items-center gap-4 mb-4">
            {/* Album art */}
            <div
              className="w-16 h-16 rounded-xl flex items-center justify-center text-3xl relative overflow-hidden"
              style={{ background: 'var(--nm-surface-hover)' }}
            >
              🎵
              
              {/* Particles around play button when playing */}
              {isPlaying && (
                <motion.div
                  className="absolute inset-0"
                  animate={{
                    rotate: [0, 360],
                  }}
                  transition={{
                    duration: 8,
                    repeat: Infinity,
                    ease: "linear"
                  }}
                >
                  <Sparkles 
                    className="absolute top-1 left-1 w-3 h-3" 
                    style={{ color: 'var(--nm-accent)' }} 
                  />
                  <Sparkles 
                    className="absolute top-1 right-1 w-2 h-2" 
                    style={{ color: 'var(--nm-accent)' }} 
                  />
                  <Sparkles 
                    className="absolute bottom-1 left-1 w-2 h-2" 
                    style={{ color: 'var(--nm-accent)' }} 
                  />
                  <Sparkles 
                    className="absolute bottom-1 right-1 w-3 h-3" 
                    style={{ color: 'var(--nm-accent)' }} 
                  />
                </motion.div>
              )}

              {/* Glow effect when playing */}
              {isPlaying && (
                <motion.div
                  className="absolute inset-0 -z-10 blur-xl"
                  style={{ background: 'var(--nm-glow)' }}
                  animate={{
                    opacity: [0.3, 0.6, 0.3],
                    scale: [1, 1.3, 1],
                  }}
                  transition={{
                    duration: 2,
                    repeat: Infinity,
                    ease: "easeInOut"
                  }}
                />
              )}
            </div>

            {/* Track info */}
            <div className="flex-1 min-w-0">
              <h4 className="font-medium truncate mb-1" style={{ color: 'var(--nm-text)' }}>
                Midnight Dreams
              </h4>
              <p className="text-sm truncate" style={{ color: 'var(--nm-text-secondary)' }}>
                Dream Walker
              </p>
            </div>
          </div>

          {/* Progress bar */}
          <div className="mb-3">
            <div
              className="h-1.5 rounded-full mb-2 cursor-pointer"
              style={{ background: 'var(--nm-surface-hover)' }}
              onClick={(e) => {
                const rect = e.currentTarget.getBoundingClientRect();
                const x = e.clientX - rect.left;
                const percentage = (x / rect.width) * 100;
                setProgress(percentage);
              }}
            >
              <motion.div
                className="h-full rounded-full relative"
                style={{
                  width: `${progress}%`,
                  background: 'var(--nm-accent)'
                }}
                layoutId="progress"
              >
                {/* Glow on progress bar */}
                <div
                  className="absolute right-0 top-1/2 -translate-y-1/2 w-3 h-3 rounded-full"
                  style={{
                    background: 'var(--nm-accent)',
                    boxShadow: `0 0 12px var(--nm-glow)`
                  }}
                />
              </motion.div>
            </div>
            <div className="flex justify-between text-xs" style={{ color: 'var(--nm-text-secondary)' }}>
              <span>1:23</span>
              <span>3:45</span>
            </div>
          </div>

          {/* Controls */}
          <div className="flex items-center justify-center gap-3">
            <motion.button
              whileHover={{ scale: 1.1 }}
              whileTap={{ scale: 0.95 }}
              className="p-2 rounded-lg transition-colors duration-200"
              style={{
                color: 'var(--nm-text-secondary)'
              }}
            >
              <SkipBack className="w-5 h-5" />
            </motion.button>

            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={() => setIsPlaying(!isPlaying)}
              className="p-4 rounded-full transition-all duration-200 relative"
              style={{
                background: 'var(--nm-accent)',
                color: 'white',
                boxShadow: `0 4px 16px var(--nm-shadow)`
              }}
            >
              {isPlaying ? (
                <Pause className="w-6 h-6" />
              ) : (
                <Play className="w-6 h-6 ml-0.5" />
              )}
            </motion.button>

            <motion.button
              whileHover={{ scale: 1.1 }}
              whileTap={{ scale: 0.95 }}
              className="p-2 rounded-lg transition-colors duration-200"
              style={{
                color: 'var(--nm-text-secondary)'
              }}
            >
              <SkipForward className="w-5 h-5" />
            </motion.button>

            <motion.button
              whileHover={{ scale: 1.1 }}
              whileTap={{ scale: 0.95 }}
              className="p-2 rounded-lg transition-colors duration-200"
              style={{
                color: 'var(--nm-text-secondary)'
              }}
            >
              <Volume2 className="w-5 h-5" />
            </motion.button>
          </div>
        </div>
      </div>
    </motion.div>
  );
}
