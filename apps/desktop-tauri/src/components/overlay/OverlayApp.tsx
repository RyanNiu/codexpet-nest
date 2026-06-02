import { useEffect, useRef, useState } from 'react';
import type { PointerEvent } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';
import { buildNestRenderModel, createMetricSnapshot } from '@codexpet/renderer';
import { builtInNestFixtures, getBuiltInNestFixture } from '@codexpet/renderer/fixtures/nests';
import { useAppConfigStore } from '@/store/appConfigStore';
import {
  getEnabledNestEntries,
  resolveActiveNestEntry,
  useRegistryStore,
} from '@/store/registryStore';
import { useSettingsStore } from '@/store/settingsStore';
import type { CodexStateDebug, ConvertedPosition, ScreenInfo } from '@/store/debugStore';
import { NestOverlayView } from './NestOverlayView';

interface OverlayPosition {
  x: number;
  y: number;
}

interface DragDiagnostics {
  mouseDownCount: number;
  lastMousePosition: string;
  draggingActive: boolean;
  dragMode: 'idle' | 'native-attempted' | 'manual-fallback';
  lastDragError: string | null;
}

const initialDragDiagnostics: DragDiagnostics = {
  mouseDownCount: 0,
  lastMousePosition: 'none',
  draggingActive: false,
  dragMode: 'idle',
  lastDragError: null,
};

export function OverlayApp() {
  const { config, isLoading } = useAppConfigStore();
  const { registry, isLoading: registryLoading } = useRegistryStore();
  const { settings, isLoading: settingsLoading, update: updateSettings } = useSettingsStore();
  const registryNests = getEnabledNestEntries(registry);
  const { entry: selectedNestEntry, fallback: nestFallback } = resolveActiveNestEntry(
    registry,
    settings.activeNestId,
  );
  const selectedNestId = selectedNestEntry?.id ?? builtInNestFixtures[0]?.id ?? 'default';
  const overlayMode = settings.overlayMode;
  const [runtimeStatus, setRuntimeStatus] = useState('Runtime: checking Codex state once...');
  const [dragDiagnostics, setDragDiagnostics] = useState<DragDiagnostics>(initialDragDiagnostics);
  const dragStartRef = useRef<{
    pointerX: number;
    pointerY: number;
    windowX: number;
    windowY: number;
  } | null>(null);
  const pendingPositionRef = useRef<OverlayPosition | null>(null);
  const animationFrameRef = useRef<number | null>(null);

  useEffect(() => {
    writeDragDiagnostics(dragDiagnostics);
  }, [dragDiagnostics]);

  useEffect(() => {
    if (isLoading || settingsLoading || registryLoading) return;
    invoke('set_overlay_click_through', { enabled: settings.clickThrough }).catch(() => undefined);
  }, [isLoading, registryLoading, settings.clickThrough, settingsLoading]);

  useEffect(() => {
    if (isLoading || settingsLoading || registryLoading) return;
    if (nestFallback && settings.activeNestId) {
      setRuntimeStatus(`Runtime: registry fallback ${settings.activeNestId} -> ${selectedNestId}`);
      return;
    }
    if (settings.overlayMode === 'standalone-fixed') {
      setRuntimeStatus('Runtime: standalone-fixed from local settings');
      return;
    }

    let cancelled = false;
    async function computeInitialPosition() {
      try {
        const codexState = await invoke<CodexStateDebug>('get_codex_state');
        const bounds = codexState.overlay_bounds;
        const mascot = bounds?.mascot;
        if (!bounds || !mascot) {
          if (!cancelled) {
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
          setRuntimeStatus(
            `Runtime: follow-codex initial position x=${converted.x.toFixed(1)}, y=${converted.y.toFixed(1)} (continuous loop not enabled)`,
          );
        }
      } catch (error) {
        if (!cancelled) {
          setRuntimeStatus(`Runtime: standalone fallback (${String(error)})`);
        }
      }
    }

    computeInitialPosition();
    return () => {
      cancelled = true;
    };
  }, [
    isLoading,
    nestFallback,
    registryLoading,
    selectedNestId,
    settings.activeNestId,
    settings.overlayMode,
    settingsLoading,
  ]);

  if (isLoading || settingsLoading || registryLoading) {
    return <div style={{ color: 'white', padding: 20 }}>Loading...</div>;
  }

  // Multi-condition check so debug styles render even when isDebug is not
  // reliably set by the Rust backend (e.g. serialisation mismatch).
  const isDevOverlay =
    config.isDebug === true ||
    import.meta.env.DEV === true ||
    window.location.search.includes('label=overlay');

  const updateDragDiagnostics = (patch: Partial<DragDiagnostics>) => {
    setDragDiagnostics((current) => ({ ...current, ...patch }));
  };

  const flushPendingPosition = () => {
    animationFrameRef.current = null;
    const nextPosition = pendingPositionRef.current;
    if (!nextPosition) return;
    invoke('set_overlay_position', { x: nextPosition.x, y: nextPosition.y }).catch((error) => {
      updateDragDiagnostics({ lastDragError: String(error) });
    });
  };

  const scheduleOverlayPosition = (position: OverlayPosition) => {
    pendingPositionRef.current = position;
    if (animationFrameRef.current !== null) return;
    animationFrameRef.current = window.requestAnimationFrame(flushPendingPosition);
  };

  const startManualFallbackDrag = (pointerX: number, pointerY: number) => {
    invoke<OverlayPosition>('get_overlay_position')
      .then((position) => {
        dragStartRef.current = {
          pointerX,
          pointerY,
          windowX: position.x,
          windowY: position.y,
        };
        updateDragDiagnostics({ dragMode: 'manual-fallback' });
      })
      .catch((error) => {
        updateDragDiagnostics({
          draggingActive: false,
          lastDragError: `manual drag init failed: ${String(error)}`,
        });
      });
  };

  const handleDragPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (event.button !== 0) return;
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);

    const pointerX = event.screenX;
    const pointerY = event.screenY;
    const point = `${Math.round(pointerX)}, ${Math.round(pointerY)}`;
    setDragDiagnostics((current) => ({
      ...current,
      mouseDownCount: current.mouseDownCount + 1,
      lastMousePosition: point,
      draggingActive: true,
      dragMode: 'native-attempted',
      lastDragError: null,
    }));

    getCurrentWebviewWindow()
      .startDragging()
      .catch((error) => {
        updateDragDiagnostics({ lastDragError: `native startDragging failed: ${String(error)}` });
        startManualFallbackDrag(pointerX, pointerY);
      });
  };

  const handleDragPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const start = dragStartRef.current;
    if (!start) return;
    event.preventDefault();
    const scale = window.devicePixelRatio || 1;
    const dx = Math.round((event.screenX - start.pointerX) * scale);
    const dy = Math.round((event.screenY - start.pointerY) * scale);
    const next = { x: start.windowX + dx, y: start.windowY + dy };
    updateDragDiagnostics({
      lastMousePosition: `${Math.round(event.screenX)}, ${Math.round(event.screenY)}`,
      dragMode: 'manual-fallback',
    });
    scheduleOverlayPosition(next);
  };

  const stopManualDrag = (event: PointerEvent<HTMLDivElement>) => {
    if (event.currentTarget.hasPointerCapture(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
    dragStartRef.current = null;
    updateDragDiagnostics({ draggingActive: false });
  };

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

      <div
        data-testid="overlay-drag-region"
        data-tauri-drag-region
        onPointerDown={handleDragPointerDown}
        onPointerMove={handleDragPointerMove}
        onPointerUp={stopManualDrag}
        onPointerCancel={stopManualDrag}
        style={{
          position: 'absolute',
          top: 8,
          left: 92,
          right: 178,
          height: 24,
          zIndex: 25,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          borderRadius: 999,
          border: '1px solid rgba(255,255,255,0.45)',
          background: 'rgba(0,0,0,0.45)',
          color: '#ffffff',
          fontSize: 11,
          fontWeight: 800,
          letterSpacing: 0.4,
          cursor: 'move',
        }}
      >
        Drag Overlay
      </div>

      <div
        data-testid="overlay-drag-diagnostics"
        style={{
          position: 'absolute',
          left: 8,
          bottom: 8,
          zIndex: 30,
          maxWidth: 220,
          padding: '3px 6px',
          borderRadius: 6,
          background: 'rgba(0,0,0,0.55)',
          color: '#ffffff',
          fontSize: 9,
          lineHeight: 1.25,
          textAlign: 'left',
          pointerEvents: 'none',
        }}
      >
        <div>mouse down: {dragDiagnostics.mouseDownCount}</div>
        <div>last pointer: {dragDiagnostics.lastMousePosition}</div>
        <div>dragging: {String(dragDiagnostics.draggingActive)}</div>
        <div>mode: {dragDiagnostics.dragMode}</div>
        {dragDiagnostics.lastDragError && <div>error: {dragDiagnostics.lastDragError}</div>}
      </div>

      <div style={{ position: 'absolute', top: 8, right: 8, zIndex: 20, display: 'flex', gap: 4 }}>
        {registryNests.slice(0, 3).map((entry) => (
          <button
            key={entry.id}
            type="button"
            onClick={() => updateSettings({ activeNestId: entry.id }).catch(() => undefined)}
            style={{
              fontSize: 9,
              border: '1px solid rgba(255,255,255,0.5)',
              borderRadius: 4,
              background: selectedNestId === entry.id ? '#ffffff' : 'rgba(0,0,0,0.45)',
              color: selectedNestId === entry.id ? '#111' : '#fff',
              padding: '2px 4px',
              cursor: 'pointer',
            }}
          >
            {entry.id.replace('-nest', '')}
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
        {nestFallback && settings.activeNestId && (
          <div style={{ textAlign: 'center', fontSize: 9, color: '#ffcc00', opacity: 0.9 }}>
            Registry fallback: {settings.activeNestId} {'->'} {selectedNestId}
          </div>
        )}
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

function writeDragDiagnostics(diagnostics: DragDiagnostics) {
  window.localStorage.setItem('codexpet.overlay.dragDiagnostics', JSON.stringify(diagnostics));
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
