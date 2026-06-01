import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useGameStore } from "./store/useGameStore";
import { MenuPage } from "./pages/MenuPage";
import { GamePage } from "./pages/GamePage";
import { AdOverlay } from "./components/AdOverlay";

const queryClient = new QueryClient();

function AppContent() {
  const phase = useGameStore(s => s.phase);

  return (
    <div className="min-h-screen bg-black">
      {phase === "menu" ? <MenuPage /> : <GamePage />}
      <AdOverlay />
    </div>
  );
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AppContent />
    </QueryClientProvider>
  );
}

export default App;
