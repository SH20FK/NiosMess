import { createContext, useContext, useState, ReactNode, useEffect } from 'react';

type Theme = 'dark' | 'light' | 'teal' | 'green' | 'pink' | 'orange' | 'purple';

interface ThemeContextType {
  theme: Theme;
  setTheme: (theme: Theme) => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState<Theme>('dark');

  useEffect(() => {
    // Remove all theme classes
    document.documentElement.classList.remove(
      'theme-dark',
      'theme-light',
      'theme-teal',
      'theme-green',
      'theme-pink',
      'theme-orange',
      'theme-purple'
    );
    
    // Add current theme class
    if (theme !== 'dark') {
      document.documentElement.classList.add(`theme-${theme}`);
    }
  }, [theme]);

  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within ThemeProvider');
  }
  return context;
}
