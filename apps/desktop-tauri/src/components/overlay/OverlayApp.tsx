import { useAppConfigStore } from '@/store/appConfigStore';

export function OverlayApp() {
  const { config, isLoading } = useAppConfigStore();

  if (isLoading) {
    return <div style={{ color: 'white', padding: 20 }}>Loading...</div>;
  }

  return (
    <div
      style={{
        width: '100vw',
        height: '100vh',
        background: 'transparent',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: 'rgba(255,255,255,0.9)',
        fontSize: 14,
        fontFamily: 'system-ui, sans-serif',
        userSelect: 'none',
      }}
      data-tauri-drag-region
    >
      <div>
        <div style={{ textAlign: 'center' }}>{config.appName} Nest</div>
        <div style={{ textAlign: 'center', fontSize: 11, opacity: 0.5 }}>v{config.version}</div>
      </div>
    </div>
  );
}
