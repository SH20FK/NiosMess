import { useEffect, useState } from 'react';
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
import { checkSession } from './lib/api';
import { Session, useSessionState } from './lib/session';

export type Screen = 
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
  const { session, setSession } = useSessionState();
  const [currentScreen, setCurrentScreen] = useState<Screen>('loading');
  const [selectedChat, setSelectedChat] = useState<any>(null);
  const [selectedMedia, setSelectedMedia] = useState<any>(null);
  const [frozenReason, setFrozenReason] = useState<string | null>(null);

  const navigateTo = (screen: Screen, data?: any) => {
    if (screen === 'chat' && data) {
      setSelectedChat(data);
    }
    if (screen === 'media-viewer' && data) {
      setSelectedMedia(data);
    }
    if (screen === 'frozen' && data?.reason) {
      setFrozenReason(data.reason);
    }
    setCurrentScreen(screen);
  };

  useEffect(() => {
    let active = true;

    const boot = async () => {
      if (!session) {
        setCurrentScreen('welcome');
        return;
      }
      setCurrentScreen('loading');
      try {
        await checkSession({ token: session.token, username: session.username });
        if (active) setCurrentScreen('main');
      } catch {
        if (!active) return;
        setSession(null);
        setCurrentScreen('welcome');
      }
    };

    boot();
    return () => {
      active = false;
    };
  }, [session, setSession]);

  const handleLogin = (nextSession: Session) => {
    setSession(nextSession);
    setCurrentScreen('main');
  };

  const renderScreen = () => {
    switch (currentScreen) {
      case 'welcome':
        return <WelcomeScreen onNavigate={navigateTo} />;
      case 'register':
        return <RegisterScreen onNavigate={navigateTo} onRegister={handleLogin} />;
      case 'login':
        return <LoginScreen onNavigate={navigateTo} onLogin={handleLogin} />;
      case 'frozen':
        return <FrozenAccountScreen onNavigate={navigateTo} reason={frozenReason} />;
      case 'main':
        return <MainScreen onNavigate={navigateTo} session={session} />;
      case 'chat':
        return <ChatScreen chat={selectedChat} onNavigate={navigateTo} session={session} />;
      case 'settings':
        return <SettingsScreen onNavigate={navigateTo} session={session} />;
      case 'create-group':
        return <CreateGroupScreen onNavigate={navigateTo} session={session} />;
      case 'media-viewer':
        return <MediaViewer media={selectedMedia} onNavigate={navigateTo} />;
      case 'loading':
        return <LoadingState />;
      case 'error':
        return <ErrorState onRetry={() => navigateTo('main')} />;
      default:
        return <WelcomeScreen onNavigate={navigateTo} />;
    }
  };

  return (
    <ThemeProvider>
      <div className="w-full h-screen overflow-hidden relative">
        {renderScreen()}
      </div>
    </ThemeProvider>
  );
}
