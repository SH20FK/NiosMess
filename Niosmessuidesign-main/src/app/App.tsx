import { useState } from 'react';
import { Menu } from 'lucide-react';
import { WelcomeScreen } from './components/onboarding/WelcomeScreen';
import { RegisterScreen } from './components/onboarding/RegisterScreen';
import { LoginScreen } from './components/onboarding/LoginScreen';
import { FrozenAccountScreen } from './components/onboarding/FrozenAccountScreen';
import { MainScreen } from './components/main/MainScreen';
import { ChatScreen } from './components/chat/ChatScreen';
import { SettingsScreen } from './components/settings/SettingsScreen';
import { CreateGroupScreen } from './components/modals/CreateGroupScreen';
import { MediaViewer } from './components/media/MediaViewer';
import { ThemeProvider } from './components/ThemeProvider';
import { LoadingState } from './components/states/LoadingState';
import { ErrorState } from './components/states/ErrorState';
import { DemoNav } from './components/DemoNav';
import { DemoShowcase } from './components/DemoShowcase';

export type Screen = 
  | 'showcase'
  | 'welcome'
  | 'register' 
  | 'login'
  | 'frozen'
  | 'main'
  | 'chat'
  | 'settings'
  | 'create-group'
  | 'media-viewer'
  | 'loading'
  | 'error';

export default function App() {
  const [currentScreen, setCurrentScreen] = useState<Screen>('showcase');
  const [selectedChat, setSelectedChat] = useState<any>(null);
  const [selectedMedia, setSelectedMedia] = useState<any>(null);
  const [showDemoNav, setShowDemoNav] = useState(false);

  const navigateTo = (screen: Screen, data?: any) => {
    if (screen === 'chat' && data) {
      setSelectedChat(data);
    }
    if (screen === 'media-viewer' && data) {
      setSelectedMedia(data);
    }
    setCurrentScreen(screen);
    setShowDemoNav(false);
  };

  const renderScreen = () => {
    switch (currentScreen) {
      case 'showcase':
        return <DemoShowcase />;
      case 'welcome':
        return <WelcomeScreen onNavigate={navigateTo} />;
      case 'register':
        return <RegisterScreen onNavigate={navigateTo} />;
      case 'login':
        return <LoginScreen onNavigate={navigateTo} />;
      case 'frozen':
        return <FrozenAccountScreen onNavigate={navigateTo} />;
      case 'main':
        return <MainScreen onNavigate={navigateTo} />;
      case 'chat':
        return <ChatScreen chat={selectedChat} onNavigate={navigateTo} />;
      case 'settings':
        return <SettingsScreen onNavigate={navigateTo} />;
      case 'create-group':
        return <CreateGroupScreen onNavigate={navigateTo} />;
      case 'media-viewer':
        return <MediaViewer media={selectedMedia} onNavigate={navigateTo} />;
      case 'loading':
        return <LoadingState />;
      case 'error':
        return <ErrorState onRetry={() => navigateTo('main')} />;
      default:
        return <DemoShowcase />;
    }
  };

  return (
    <ThemeProvider>
      <div className="w-full h-screen overflow-hidden relative">
        {renderScreen()}
        
        {/* Demo navigation toggle */}
        <button
          onClick={() => setShowDemoNav(!showDemoNav)}
          className="fixed top-4 right-4 p-3 rounded-xl z-50 transition-all duration-200 hover:scale-110 active:scale-95"
          style={{
            background: 'var(--nm-accent)',
            color: 'white',
            boxShadow: `0 8px 32px var(--nm-shadow)`
          }}
        >
          <Menu className="w-5 h-5" />
        </button>

        {/* Demo navigation panel */}
        {showDemoNav && (
          <DemoNav 
            currentScreen={currentScreen} 
            onNavigate={navigateTo}
            onClose={() => setShowDemoNav(false)}
          />
        )}
      </div>
    </ThemeProvider>
  );
}