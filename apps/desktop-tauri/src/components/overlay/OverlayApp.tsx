import { useEffect, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { buildNestRenderModel, createMetricSnapshot } from '@codexpet/renderer';
import { builtInNestFixtures, getBuiltInNestFixture } from '@codexpet/renderer/fixtures/nests';
import type { OverlayMode } from '@codexpet/core';
import { useAppConfigStore } from '@/store/appConfigStore';
import type { CodexStateDebug, ConvertedPosition, ScreenInfo } from '@/store/debugStore';
import { NestOverlayView } from './NestOverlayView';

export function OverlayApp() {
  const { config, isLoading } = useAppConfigStore();
  const [selectedNestId, setSelectedNestId] = useState('default');
  const [overlayMode, setOverlayMode] = useState<OverlayMode>('follow-codex');
  const [runtimeStatus, setRuntimeStatus] = useState('Runtime: checking Codex state once...');

  useEffect(() => {
    if (isLoading) return;
    let cancelled = false;
    async function computeInitialPosition() {
      try {
        const codexState = await invoke<CodexStateDebug>('get_codex_state');
        const bounds = codexState.overlay_bounds;
        const mascot = bounds?.mascot;
        if (!bounds || !mascot) {
          if (!cancelled) {
            setOverlayMode('standalone-fixed');
            setRuntimeStatus('Runtime: standalone fallback (Codex mascot bounds unavailable)');
          }
          return;
        }

        const screens = await invoke<ScreenInfo[]>('get_screen_list');
        const converted = await invoke<ConvertedPosition>('convert_position', {
          codexX: bounds.x + mascot.left,
          codexY: bounds.y + mascot.top,
          codexWidth: mascot.width,
          codexHeight: mascot.height,
          screens,
          scale: screens[0]?.scale_factor ?? 1.0,
        });
        if (!cancelled) {
          setOverlayMode('follow-codex');
          setRuntimeStatus(
            `Runtime: follow-codex initial position x=${converted.x.toFixed(1)}, y=${converted.y.toFixed(1)} (continuous loop not enabled)`,
          );
        }
      } catch (error) {
        if (!cancelled) {
          setOverlayMode('standalone-fixed');
          setRuntimeStatus(`Runtime: standalone fallback (${String(error)})`);
        }
      }
    }

    computeInitialPosition();
    return () => {
      cancelled = true;
    };
  }, [isLoading]);

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

      <div style={{ position: 'absolute', top: 8, right: 8, zIndex: 20, display: 'flex', gap: 4 }}>
        {builtInNestFixtures.slice(0, 3).map((fixture) => (
          <button
            key={fixture.id}
            type="button"
            onClick={() => setSelectedNestId(fixture.id)}
            style={{
              fontSize: 9,
              border: '1px solid rgba(255,255,255,0.5)',
              borderRadius: 4,
              background: selectedNestId === fixture.id ? '#ffffff' : 'rgba(0,0,0,0.45)',
              color: selectedNestId === fixture.id ? '#111' : '#fff',
              padding: '2px 4px',
              cursor: 'pointer',
            }}
          >
            {fixture.id.replace('-nest', '')}
          </button>
        ))}
      </div>

      <div style={{ position: 'relative', zIndex: 5, textAlign: 'center' }}>
        <NestOverlayView
          model={createRenderModel(selectedNestId)}
          selectedNestId={selectedNestId}
        />
        <div style={{ textAlign: 'center', fontSize: 10, opacity: 0.82, marginTop: -4 }}>
          {config.appName || 'CodexPet'} v{config.version} · mode: {overlayMode}
        </div>
        <div style={{ textAlign: 'center', fontSize: 9, opacity: 0.72 }}>{runtimeStatus}</div>
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

function createRenderModel(selectedNestId: string) {
  const fixture = getBuiltInNestFixture(selectedNestId) ?? builtInNestFixtures[0];
  if (!fixture) {
    throw new Error('No built-in nest fixtures are available');
  }
  const metrics = createMetricSnapshot();
  return buildNestRenderModel({
    theme: fixture.nestLayout,
    metrics,
    resolveAsset: (path) => fixture.assets[path] ?? null,
  });
}
