import { useAppConfigStore } from '@/store/appConfigStore';

export function OverlayApp() {
  const { config, isLoading } = useAppConfigStore();

  if (isLoading) {
    return <div style={{ color: 'white', padding: 20 }}>Loading...</div>;
  }

  // Multi-condition check so debug styles render even when isDebug is not
  // reliably set by the Rust backend (e.g. serialisation mismatch).
  const isDevOverlay =
    config.isDebug === true ||
    import.meta.env.DEV === true ||
    window.location.search.includes('label=overlay');

  return (
    <div
      data-testid="overlay-root"
      style={{
        width: '100vw',
        height: '100vh',
        position: 'relative',
        overflow: 'hidden',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: 'rgba(255,255,255,0.9)',
        fontSize: 14,
        fontFamily: 'system-ui, sans-serif',
        userSelect: 'none',

        // Dev overlay: ultra-visible borders so the overlay bounding box
        // is unmistakable during manual verification.
        ...(isDevOverlay
          ? ({
              border: '6px solid #ff0000',
              outline: '4px solid #ffff00',
              outlineOffset: '-10px',
              background: 'rgba(255, 0, 0, 0.22)',
              boxSizing: 'border-box',
              borderRadius: 4,
            } satisfies React.CSSProperties)
          : { background: 'transparent' }),
      }}
      data-tauri-drag-region
    >
      {/* Fixed DEBUG OVERLAY label — always visible in dev / overlay context */}
      {isDevOverlay && (
        <div
          data-testid="debug-overlay-label"
          style={{
            position: 'absolute',
            top: 6,
            left: 6,
            background: '#ff0000',
            color: '#ffffff',
            fontWeight: 800,
            fontSize: 12,
            padding: '2px 6px',
            zIndex: 9999,
            pointerEvents: 'none',
          }}
        >
          DEBUG OVERLAY
        </div>
      )}

      {/* Center content */}
      <div>
        <div style={{ textAlign: 'center' }}>{config.appName || 'CodexPet'} Nest</div>
        <div style={{ textAlign: 'center', fontSize: 11, opacity: 0.5 }}>v{config.version}</div>
        {isDevOverlay && (
          <div
            data-testid="debug-platform-label"
            style={{
              textAlign: 'center',
              fontSize: 10,
              fontWeight: 700,
              color: '#ff0000',
              marginTop: 4,
              background: 'rgba(0,0,0,0.6)',
              padding: '1px 6px',
              borderRadius: 3,
            }}
          >
            DEBUG — {config.platform || 'unknown'}
          </div>
        )}
      </div>
    </div>
  );
}
