import { motion, AnimatePresence } from "motion/react";
import { ArrowLeft, User, Palette, Bell, Lock, Settings as SettingsIcon, Download, ChevronLeft, ChevronRight } from "lucide-react";
import { Screen } from "../../App";
import { useState, useRef, useEffect } from "react";
import { useTheme } from "../ThemeProvider";
import { Session } from "../../lib/session";
import { getUserInfo, getAvatarUrl } from "../../lib/api";

interface SettingsScreenProps {
  onNavigate: (screen: Screen) => void;
  session: Session | null;
}

type Tab = "account" | "personalization" | "notifications" | "privacy" | "advanced";

type ProfileInfo = {
  name: string;
  username: string;
  email: string;
  about: string;
  regdate: string;
  avatarUrl: string;
};

const tabs = [
  { id: "account" as Tab, label: "", icon: User },
  { id: "personalization" as Tab, label: "", icon: Palette },
  { id: "notifications" as Tab, label: "", icon: Bell },
  { id: "privacy" as Tab, label: "", icon: Lock },
  { id: "advanced" as Tab, label: "", icon: SettingsIcon }
];

const themes = [
  { id: "dark", name: "", preview: "#9b59f5" },
  { id: "light", name: "", preview: "#9b59f5" },
  { id: "teal", name: "", preview: "#2dd4bf" },
  { id: "green", name: "", preview: "#22c55e" },
  { id: "pink", name: "", preview: "#ec4899" },
  { id: "orange", name: "", preview: "#f97316" },
  { id: "purple", name: "", preview: "#a855f7" }
];

function formatRegDate(value?: string | number | null) {
  if (!value) return "?";
  const raw = typeof value === "number" ? value : String(value);
  const numeric = Number(raw);
  if (!Number.isNaN(numeric) && raw.trim() !== "") {
    const ts = numeric > 1e12 ? numeric : numeric * 1000;
    const date = new Date(ts);
    if (!Number.isNaN(date.getTime())) {
      return date.toLocaleDateString("ru-RU", { year: "numeric", month: "long", day: "numeric" });
    }
  }
  const parsed = new Date(raw);
  if (!Number.isNaN(parsed.getTime())) {
    return parsed.toLocaleDateString("ru-RU", { year: "numeric", month: "long", day: "numeric" });
  }
  return String(value);
}

export function SettingsScreen({ onNavigate, session }: SettingsScreenProps) {
  const [activeTab, setActiveTab] = useState<Tab>("personalization");
  const [slideDirection, setSlideDirection] = useState<"left" | "right">("right");
  const [profile, setProfile] = useState<ProfileInfo>({
    name: "",
    username: "",
    email: "",
    about: "",
    regdate: "",
    avatarUrl: ""
  });
  const [loadingProfile, setLoadingProfile] = useState(false);

  useEffect(() => {
    if (!session) return;
    let active = true;

    const loadProfile = async () => {
      setLoadingProfile(true);
      try {
        const info = await getUserInfo({
          username: session.username,
          myUsername: session.username,
          token: session.token
        });
        if (!active) return;
        setProfile({
          name: info?.name || session.name || session.username,
          username: info?.username || session.username,
          email: info?.email || "",
          about: info?.about || info?.bio || "",
          regdate: info?.regdate || info?.reg_date || "",
          avatarUrl: getAvatarUrl(session.username)
        });
      } catch {
        if (!active) return;
        setProfile({
          name: session.name || session.username,
          username: session.username,
          email: "",
          about: "",
          regdate: "",
          avatarUrl: getAvatarUrl(session.username)
        });
      } finally {
        if (active) setLoadingProfile(false);
      }
    };

    loadProfile();
    return () => {
      active = false;
    };
  }, [session]);

  const handleTabChange = (newTab: Tab) => {
    const currentIndex = tabs.findIndex((t) => t.id === activeTab);
    const newIndex = tabs.findIndex((t) => t.id === newTab);
    setSlideDirection(newIndex > currentIndex ? "right" : "left");
    setActiveTab(newTab);
  };

  return (
    <div className="w-full h-full flex flex-col md:flex-row" style={{ background: "var(--nm-bg)" }}>
      <div
        className="w-full md:w-64 border-r"
        style={{
          background: "var(--nm-surface)",
          borderColor: "var(--nm-border)"
        }}
      >
        <div className="p-4 border-b" style={{ borderColor: "var(--nm-border)" }}>
          <button
            onClick={() => onNavigate("main")}
            className="flex items-center gap-2 mb-4 transition-all duration-200 hover:gap-3"
            style={{ color: "var(--nm-text-secondary)" }}
          >
            <ArrowLeft className="w-5 h-5" />
            <span></span>
          </button>
          <h2 className="text-2xl font-bold" style={{ color: "var(--nm-text)" }}>
            
          </h2>
        </div>

        <div className="p-2">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            return (
              <motion.button
                key={tab.id}
                onClick={() => handleTabChange(tab.id)}
                whileHover={{ x: 4 }}
                whileTap={{ scale: 0.98 }}
                className="w-full flex items-center gap-3 px-4 py-3 rounded-xl mb-1 transition-all duration-200"
                style={{
                  background: activeTab === tab.id ? "var(--nm-surface-hover)" : "transparent",
                  color: activeTab === tab.id ? "var(--nm-accent)" : "var(--nm-text)"
                }}
              >
                <Icon className="w-5 h-5" />
                <span className="font-medium">{tab.label}</span>
              </motion.button>
            );
          })}
        </div>
      </div>

      <div className="flex-1 overflow-y-auto">
        <div className="max-w-3xl mx-auto p-6 md:p-8">
          <AnimatePresence mode="wait">
            <motion.div
              key={activeTab}
              initial={{ opacity: 0, x: slideDirection === "right" ? 50 : -50 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: slideDirection === "right" ? -50 : 50 }}
              transition={{ duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
            >
              {activeTab === "account" && <AccountTab profile={profile} loading={loadingProfile} />}
              {activeTab === "personalization" && <PersonalizationTab />}
              {activeTab === "notifications" && <NotificationsTab />}
              {activeTab === "privacy" && <PrivacyTab />}
              {activeTab === "advanced" && <AdvancedTab />}
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
}

function AccountTab({ profile, loading }: { profile: ProfileInfo; loading: boolean }) {
  const displayName = profile.name || profile.username || "";
  const displayUsername = profile.username ? `@${profile.username}` : "@username";
  const regDate = formatRegDate(profile.regdate);

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2" style={{ color: "var(--nm-text)" }}>
          
        </h3>
        <p style={{ color: "var(--nm-text-secondary)" }}>
            ?  
        </p>
      </div>

      <div
        className="p-6 rounded-2xl"
        style={{
          background: "var(--nm-surface)",
          border: "1px solid var(--nm-border)"
        }}
      >
        <div className="flex items-center gap-4 mb-6">
          <div
            className="w-20 h-20 rounded-full flex items-center justify-center text-4xl overflow-hidden"
            style={{ background: "var(--nm-surface-hover)" }}
          >
            {profile.avatarUrl ? (
              <img src={profile.avatarUrl} alt={displayName} className="w-full h-full object-cover" />
            ) : (
              displayName.charAt(0).toUpperCase()
            )}
          </div>
          <div className="flex-1">
            <h4 className="text-xl font-bold mb-1" style={{ color: "var(--nm-text)" }}>
              {displayName}
            </h4>
            <p style={{ color: "var(--nm-text-secondary)" }}>{displayUsername}</p>
            <p className="text-sm mt-1" style={{ color: "var(--nm-text-secondary)" }}>
              : {regDate}
            </p>
          </div>
          <button
            className="px-4 py-2 rounded-xl transition-all duration-200 hover:scale-105"
            style={{
              background: "var(--nm-accent)",
              color: "white"
            }}
          >
            
          </button>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: "var(--nm-text)" }}>
               
            </label>
            <input
              type="text"
              value={displayName}
              readOnly
              className="w-full px-4 py-3 rounded-xl border outline-none"
              style={{
                background: "var(--nm-bg)",
                color: "var(--nm-text)",
                borderColor: "var(--nm-border)"
              }}
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: "var(--nm-text)" }}>
              Email
            </label>
            <input
              type="email"
              value={profile.email || ""}
              readOnly
              placeholder="mail@example.com"
              className="w-full px-4 py-3 rounded-xl border outline-none"
              style={{
                background: "var(--nm-bg)",
                color: "var(--nm-text)",
                borderColor: "var(--nm-border)"
              }}
            />
          </div>

          <div>
            <label className="block text-sm font-medium mb-2" style={{ color: "var(--nm-text)" }}>
              ? 
            </label>
            <textarea
              value={profile.about || ""}
              readOnly
              placeholder=" ? ..."
              rows={3}
              className="w-full px-4 py-3 rounded-xl border outline-none resize-none"
              style={{
                background: "var(--nm-bg)",
                color: "var(--nm-text)",
                borderColor: "var(--nm-border)"
              }}
            />
          </div>
        </div>
      </div>

      <button
        disabled={loading}
        className="w-full px-6 py-4 rounded-xl font-medium transition-all duration-200 hover:scale-[1.02] disabled:opacity-60"
        style={{
          background: "var(--nm-accent)",
          color: "white",
          boxShadow: `0 8px 32px var(--nm-shadow)`
        }}
      >
         
      </button>
    </div>
  );
}

function PersonalizationTab() {
  const { theme, setTheme } = useTheme();
  const [currentThemeIndex, setCurrentThemeIndex] = useState(0);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const index = themes.findIndex((t) => t.id === theme);
    if (index !== -1) {
      setCurrentThemeIndex(index);
    }
  }, [theme]);

  const scrollToIndex = (index: number) => {
    if (scrollRef.current) {
      const itemWidth = 180;
      scrollRef.current.scrollTo({
        left: index * itemWidth - itemWidth,
        behavior: "smooth"
      });
    }
  };

  const handlePrevTheme = () => {
    const newIndex = Math.max(0, currentThemeIndex - 1);
    setCurrentThemeIndex(newIndex);
    scrollToIndex(newIndex);
  };

  const handleNextTheme = () => {
    const newIndex = Math.min(themes.length - 1, currentThemeIndex + 1);
    setCurrentThemeIndex(newIndex);
    scrollToIndex(newIndex);
  };

  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2" style={{ color: "var(--nm-text)" }}>
          
        </h3>
        <p style={{ color: "var(--nm-text-secondary)" }}>   </p>
      </div>

      <div
        className="p-6 rounded-2xl"
        style={{
          background: "var(--nm-surface)",
          border: "1px solid var(--nm-border)"
        }}
      >
        <h4 className="font-bold mb-4 flex items-center gap-2" style={{ color: "var(--nm-text)" }}>
          <Palette className="w-5 h-5" />
           
        </h4>

        <div className="relative">
          <button
            onClick={handlePrevTheme}
            disabled={currentThemeIndex === 0}
            className="absolute left-0 top-1/2 -translate-y-1/2 z-10 p-2 rounded-full transition-all duration-200 hover:scale-110 disabled:opacity-30 disabled:cursor-not-allowed"
            style={{
              background: "var(--nm-surface-hover)",
              color: "var(--nm-text)"
            }}
          >
            <ChevronLeft className="w-5 h-5" />
          </button>

          <div ref={scrollRef} className="flex gap-4 overflow-x-auto scrollbar-hide px-12 py-2" style={{ scrollbarWidth: "none" }}>
            {themes.map((t, index) => (
              <motion.button
                key={t.id}
                onClick={() => {
                  setTheme(t.id as any);
                  setCurrentThemeIndex(index);
                }}
                whileHover={{ scale: 1.05, y: -4 }}
                whileTap={{ scale: 0.95 }}
                className="flex-shrink-0 w-40 p-4 rounded-xl transition-all duration-200"
                style={{
                  background: theme === t.id ? "var(--nm-surface-hover)" : "var(--nm-bg)",
                  border: `2px solid ${theme === t.id ? t.preview : "var(--nm-border)"}`,
                  boxShadow: theme === t.id ? `0 8px 24px ${t.preview}33` : "none"
                }}
              >
                <div
                  className="w-full h-20 rounded-lg mb-3"
                  style={{
                    background: `linear-gradient(135deg, ${t.preview}, ${t.preview}aa)`
                  }}
                />
                <p className="font-medium text-center" style={{ color: "var(--nm-text)" }}>
                  {t.name}
                </p>
              </motion.button>
            ))}
          </div>

          <button
            onClick={handleNextTheme}
            disabled={currentThemeIndex === themes.length - 1}
            className="absolute right-0 top-1/2 -translate-y-1/2 z-10 p-2 rounded-full transition-all duration-200 hover:scale-110 disabled:opacity-30 disabled:cursor-not-allowed"
            style={{
              background: "var(--nm-surface-hover)",
              color: "var(--nm-text)"
            }}
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: "var(--nm-surface)",
          border: "1px solid var(--nm-border)"
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: "var(--nm-text)" }}>
          
        </h4>

        <ToggleOption
          label=" "
          description="  ? "
          defaultChecked={true}
        />

        <ToggleOption
          label=" "
          description="  ? "
          defaultChecked={false}
        />

        <ToggleOption
          label=" "
          description="  ?  "
          defaultChecked={true}
        />
      </div>
    </div>
  );
}

function NotificationsTab() {
  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2" style={{ color: "var(--nm-text)" }}>
          
        </h3>
        <p style={{ color: "var(--nm-text-secondary)" }}>  ? </p>
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: "var(--nm-surface)",
          border: "1px solid var(--nm-border)"
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: "var(--nm-text)" }}>
           
        </h4>

        <ToggleOption
          label="Push-"
          description="  ?  "
          defaultChecked={true}
        />

        <ToggleOption
          label=" "
          description="    "
          defaultChecked={true}
        />

        <ToggleOption
          label=" "
          description="   ? "
          defaultChecked={true}
        />
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: "var(--nm-surface)",
          border: "1px solid var(--nm-border)"
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: "var(--nm-text)" }}>
           ? 
        </h4>

        <ToggleOption
          label="  "
          description="    "
          defaultChecked={true}
        />

        <ToggleOption
          label=""
          description="   "
          defaultChecked={false}
        />
      </div>
    </div>
  );
}

function PrivacyTab() {
  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2" style={{ color: "var(--nm-text)" }}>
          
        </h3>
        <p style={{ color: "var(--nm-text-secondary)" }}>  ? </p>
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: "var(--nm-surface)",
          border: "1px solid var(--nm-border)"
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: "var(--nm-text)" }}>
           
        </h4>

        <SelectOption label=" " options={["", "", ""]} defaultValue="" />
        <SelectOption label=" " options={["", "", ""]} defaultValue="" />
        <SelectOption label="" options={["", "", ""]} defaultValue="" />
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: "var(--nm-surface)",
          border: "1px solid var(--nm-border)"
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: "var(--nm-text)" }}>
          
        </h4>

        <ToggleOption
          label=" "
          description="  "
          defaultChecked={true}
        />

        <ToggleOption
          label=" "
          description=" ?   ? "
          defaultChecked={true}
        />
      </div>
    </div>
  );
}

function AdvancedTab() {
  return (
    <div className="space-y-6">
      <div>
        <h3 className="text-2xl font-bold mb-2" style={{ color: "var(--nm-text)" }}>
          
        </h3>
        <p style={{ color: "var(--nm-text-secondary)" }}>  ?  </p>
      </div>

      <div
        className="p-6 rounded-2xl"
        style={{
          background: "var(--nm-surface)",
          border: "1px solid var(--nm-border)"
        }}
      >
        <div className="flex items-start gap-4">
          <div
            className="w-12 h-12 rounded-xl flex items-center justify-center flex-shrink-0"
            style={{ background: "var(--nm-accent)" }}
          >
            <Download className="w-6 h-6 text-white" />
          </div>
          <div className="flex-1">
            <h4 className="font-bold mb-2" style={{ color: "var(--nm-text)" }}>
               
            </h4>
            <p className="text-sm mb-4" style={{ color: "var(--nm-text-secondary)" }}>
                ,  ?  
            </p>
            <div className="flex gap-2">
              <button
                className="px-4 py-2 rounded-xl transition-all duration-200 hover:scale-105"
                style={{
                  background: "var(--nm-accent)",
                  color: "white"
                }}
              >
                
              </button>
              <button
                className="px-4 py-2 rounded-xl transition-all duration-200 hover:scale-105"
                style={{
                  background: "var(--nm-surface-hover)",
                  color: "var(--nm-text)",
                  border: "1px solid var(--nm-border)"
                }}
              >
                 
              </button>
            </div>
          </div>
        </div>
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: "var(--nm-surface)",
          border: "1px solid var(--nm-border)"
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: "var(--nm-text)" }}>
          
        </h4>

        <div className="space-y-2">
          <div className="flex justify-between text-sm">
            <span style={{ color: "var(--nm-text-secondary)" }}></span>
            <span style={{ color: "var(--nm-text)" }}>2.4   15 </span>
          </div>
          <div className="h-2 rounded-full overflow-hidden" style={{ background: "var(--nm-bg)" }}>
            <div className="h-full rounded-full" style={{ width: "16%", background: "var(--nm-accent)" }} />
          </div>
        </div>

        <button
          className="w-full mt-4 px-4 py-3 rounded-xl transition-all duration-200 hover:scale-[1.02]"
          style={{
            background: "var(--nm-surface-hover)",
            color: "var(--nm-text)",
            border: "1px solid var(--nm-border)"
          }}
        >
           
        </button>
      </div>

      <div
        className="p-6 rounded-2xl space-y-4"
        style={{
          background: "var(--nm-surface)",
          border: "1px solid var(--nm-border)"
        }}
      >
        <h4 className="font-bold mb-4" style={{ color: "var(--nm-text)" }}>
          ? 
        </h4>

        <div className="space-y-2 text-sm">
          <div className="flex justify-between">
            <span style={{ color: "var(--nm-text-secondary)" }}></span>
            <span style={{ color: "var(--nm-text)" }}>1.0.0</span>
          </div>
          <div className="flex justify-between">
            <span style={{ color: "var(--nm-text-secondary)" }}></span>
            <span style={{ color: "var(--nm-text)" }}>Web</span>
          </div>
        </div>
      </div>
    </div>
  );
}

function ToggleOption({ label, description, defaultChecked }: any) {
  const [checked, setChecked] = useState(defaultChecked);

  return (
    <div className="flex items-center justify-between py-2">
      <div className="flex-1">
        <p className="font-medium mb-1" style={{ color: "var(--nm-text)" }}>
          {label}
        </p>
        <p className="text-sm" style={{ color: "var(--nm-text-secondary)" }}>
          {description}
        </p>
      </div>
      <button
        onClick={() => setChecked(!checked)}
        className="relative w-12 h-6 rounded-full transition-all duration-300"
        style={{
          background: checked ? "var(--nm-accent)" : "var(--nm-border)"
        }}
      >
        <motion.div
          className="absolute top-0.5 w-5 h-5 rounded-full bg-white"
          animate={{
            left: checked ? "calc(100% - 22px)" : "2px"
          }}
          transition={{ type: "spring", stiffness: 500, damping: 30 }}
        />
      </button>
    </div>
  );
}

function SelectOption({ label, options, defaultValue }: any) {
  const [value, setValue] = useState(defaultValue);

  return (
    <div className="py-2">
      <p className="font-medium mb-3" style={{ color: "var(--nm-text)" }}>
        {label}
      </p>
      <div className="flex gap-2">
        {options.map((option: string) => (
          <button
            key={option}
            onClick={() => setValue(option)}
            className="px-4 py-2 rounded-xl transition-all duration-200 hover:scale-105"
            style={{
              background: value === option ? "var(--nm-accent)" : "var(--nm-surface-hover)",
              color: value === option ? "white" : "var(--nm-text)",
              border: value === option ? "none" : "1px solid var(--nm-border)"
            }}
          >
            {option}
          </button>
        ))}
      </div>
    </div>
  );
}
