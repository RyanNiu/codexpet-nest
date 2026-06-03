import { useEffect, useState, useCallback } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { useDebugStore } from '@/store/debugStore';
import type { CodexStateDebug, ScreenInfo, ConvertedPosition } from '@/store/debugStore';
import { useAppConfigStore } from '@/store/appConfigStore';

interface OverlayPosition {
  x: number;
  y: number;
}

interface OverlayDragDiagnostics {
  mouseDownCount: number;
  lastMousePosition: string;
  draggingActive: boolean;
  dragMode: string;
  lastDragError: string | null;
}

interface OverlayFollowDiagnostics {
  runtimeMode: string;
  lastCodexStateReadAt: string | null;
  lastTargetPosition: string | null;
  followLoopActive: boolean;
  lastMoveFailure: string | null;
}

const FOLLOW_DIAGNOSTICS_KEY = 'codexpet.overlay.followDiagnostics';

export function DebugPanel() {
  const {
    codexState,
    codexStateLoading,
    codexStateError,
    screens,
    screensLoading,
    screensError,
    convertedPosition,
    clickThrough,
    setCodexState,
    setCodexStateError,
    setScreens,
    setScreensError,
    setConvertedPosition,
    setClickThrough,
  } = useDebugStore();

  const config = useAppConfigStore((s) => s.config);

  const [overlayVisible, setOverlayVisible] = useState(true);
  const [overlayControlError, setOverlayControlError] = useState<string | null>(null);
  const [overlayPosition, setOverlayPosition] = useState<OverlayPosition | null>(null);
  const [dragDiagnostics, setDragDiagnostics] = useState<OverlayDragDiagnostics | null>(null);
  const [followDiagnostics, setFollowDiagnostics] = useState<OverlayFollowDiagnostics | null>(null);

  const refreshDragDiagnostics = useCallback(() => {
    const raw = window.localStorage.getItem('codexpet.overlay.dragDiagnostics');
    if (!raw) return;
    try {
      setDragDiagnostics(JSON.parse(raw) as OverlayDragDiagnostics);
    } catch {
      setDragDiagnostics({
        mouseDownCount: 0,
        lastMousePosition: 'parse-error',
        draggingActive: false,
        dragMode: 'unknown',
        lastDragError: raw,
      });
    }
  }, []);

  const refreshFollowDiagnostics = useCallback(() => {
    const raw = window.localStorage.getItem(FOLLOW_DIAGNOSTICS_KEY);
    if (!raw) return;
    try {
      setFollowDiagnostics(JSON.parse(raw) as OverlayFollowDiagnostics);
    } catch {
      setFollowDiagnostics({
        runtimeMode: 'parse-error',
        lastCodexStateReadAt: null,
        lastTargetPosition: null,
        followLoopActive: false,
        lastMoveFailure: raw,
      });
    }
  }, []);

  const refreshOverlayPosition = useCallback(() => {
    invoke<OverlayPosition>('get_overlay_position')
      .then((position) => {
        setOverlayPosition(position);
        setOverlayControlError(null);
      })
      .catch((e) => setOverlayControlError(String(e)));
    refreshDragDiagnostics();
    refreshFollowDiagnostics();
  }, [refreshDragDiagnostics, refreshFollowDiagnostics]);

  const refreshOverlayVisible = useCallback(() => {
    invoke<boolean>('is_overlay_visible')
      .then((visible) => {
        setOverlayVisible(visible);
        setOverlayControlError(null);
        refreshOverlayPosition();
      })
      .catch((e) => setOverlayControlError(String(e)));
  }, [refreshOverlayPosition]);

  const fetchCodexState = useCallback(() => {
    useDebugStore.setState({ codexStateLoading: true });
    invoke<CodexStateDebug>('get_codex_state')
      .then(setCodexState)
      .catch((e) => setCodexStateError(String(e)));
  }, [setCodexState, setCodexStateError]);

  const fetchScreens = useCallback(() => {
    useDebugStore.setState({ screensLoading: true });
    invoke<ScreenInfo[]>('get_screen_list')
      .then(setScreens)
      .catch((e) => setScreensError(String(e)));
  }, [setScreens, setScreensError]);

  const testCoordinateConversion = useCallback(() => {
    if (!codexState?.overlay_bounds || screens.length === 0) return;
    const b = codexState.overlay_bounds;
    invoke<ConvertedPosition>('convert_position', {
      codexX: b.x,
      codexY: b.y,
      codexWidth: b.width,
      codexHeight: b.height,
      screens,
      scale: screens[0]?.scale_factor ?? 1.0,
    })
      .then(setConvertedPosition)
      .catch(console.error);
  }, [codexState, screens, setConvertedPosition]);

  const toggleClickThrough = useCallback(() => {
    const next = !clickThrough;
    invoke('set_overlay_click_through', { enabled: next })
      .then(() => {
        setClickThrough(next);
        setOverlayControlError(null);
      })
      .catch((e) => setOverlayControlError(String(e)));
  }, [clickThrough, setClickThrough]);

  const setClickThroughMode = useCallback(
    (enabled: boolean) => {
      invoke('set_overlay_click_through', { enabled })
        .then(() => {
          setClickThrough(enabled);
          setOverlayControlError(null);
        })
        .catch((e) => setOverlayControlError(String(e)));
    },
    [setClickThrough],
  );

  const showOverlay = useCallback(() => {
    invoke('show_overlay')
      .then(refreshOverlayVisible)
      .catch((e) => setOverlayControlError(String(e)));
  }, [refreshOverlayVisible]);

  const hideOverlay = useCallback(() => {
    invoke('hide_overlay')
      .then(refreshOverlayVisible)
      .catch((e) => setOverlayControlError(String(e)));
  }, [refreshOverlayVisible]);

  const handleRefreshOverlayVisible = useCallback(() => {
    refreshOverlayVisible();
  }, [refreshOverlayVisible]);

  const resetOverlayPosition = useCallback(() => {
    invoke('reset_overlay_position')
      .then(() => {
        refreshOverlayVisible();
        refreshOverlayPosition();
      })
      .catch((e) => setOverlayControlError(String(e)));
  }, [refreshOverlayPosition, refreshOverlayVisible]);

  const resizeOverlayForDebug = useCallback(() => {
    invoke('resize_overlay_debug')
      .then(() => {
        refreshOverlayVisible();
        refreshOverlayPosition();
      })
      .catch((e) => setOverlayControlError(String(e)));
  }, [refreshOverlayPosition, refreshOverlayVisible]);

  // Auto-fetch on mount
  useEffect(() => {
    fetchCodexState();
    fetchScreens();
    refreshOverlayVisible();
    refreshOverlayPosition();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const style = {
    container: {
      marginTop: 16,
      padding: 12,
      background: '#f5f5f5',
      borderRadius: 8,
      fontSize: 13,
      fontFamily: 'monospace',
    } as React.CSSProperties,
    section: {
      marginBottom: 12,
      padding: 8,
      background: '#fff',
      borderRadius: 4,
      border: '1px solid #e0e0e0',
    } as React.CSSProperties,
    header: {
      fontSize: 14,
      fontWeight: 700,
      marginBottom: 4,
      color: '#333',
    } as React.CSSProperties,
    label: { color: '#666' } as React.CSSProperties,
    value: { color: '#000' } as React.CSSProperties,
    button: {
      marginRight: 8,
      marginTop: 4,
      padding: '4px 12px',
      fontSize: 12,
      cursor: 'pointer',
    } as React.CSSProperties,
    pre: {
      whiteSpace: 'pre-wrap' as const,
      wordBreak: 'break-all' as const,
      fontSize: 11,
      color: '#555',
    },
    row: {
      display: 'flex',
      gap: 8,
      flexWrap: 'wrap' as const,
    },
  };

  return (
    <div style={style.container}>
      <h2 style={{ fontSize: 16, marginBottom: 8 }}>Development Diagnostics</h2>
      <p style={{ margin: '0 0 12px', color: '#555', fontSize: 12, fontFamily: 'system-ui' }}>
        This area is for release checks and troubleshooting. Normal overlay settings are available
        above without opening this panel.
      </p>

      {/* 0. App Info */}
      <div style={style.section}>
        <div style={style.header}>0. App Info</div>
        <div style={{ fontSize: 12 }}>
          <p>
            <span style={style.label}>App: </span>
            <span style={style.value}>{config.appName}</span>
          </p>
          <p>
            <span style={style.label}>Version: </span>
            <span style={style.value}>{config.version}</span>
          </p>
          <p>
            <span style={style.label}>Platform: </span>
            <span style={style.value}>{config.platform}</span>
          </p>
          <p>
            <span style={style.label}>Debug: </span>
            <span style={style.value}>{String(config.isDebug)}</span>
          </p>
          <p>
            <span style={style.label}>Data Dir: </span>
            <span style={style.value}>{config.dataDirectory}</span>
          </p>
          {/* Display raw config JSON AND snake_case fallback keys so the
               user can instantly see field-name mismatches. */}
          <details style={{ marginTop: 8 }}>
            <summary style={{ fontSize: 12, fontWeight: 600, cursor: 'pointer', color: '#333' }}>
              Raw Config JSON
            </summary>
            <pre
              style={{
                fontSize: 11,
                whiteSpace: 'pre-wrap',
                wordBreak: 'break-all',
                margin: 0,
                padding: 8,
                background: '#222',
                color: '#0f0',
                borderRadius: 4,
              }}
            >
              {JSON.stringify(config, null, 2)}
            </pre>
          </details>
          <details style={{ marginTop: 4 }}>
            <summary style={{ fontSize: 12, fontWeight: 600, cursor: 'pointer', color: '#999' }}>
              snake_case fallback keys
            </summary>
            <pre
              style={{
                fontSize: 11,
                margin: 0,
                padding: 8,
                background: '#333',
                color: '#fc0',
                borderRadius: 4,
              }}
            >
              is_debug: {JSON.stringify((config as unknown as Record<string, unknown>).is_debug)}
              {'\n'}
              app_name: {JSON.stringify((config as unknown as Record<string, unknown>).app_name)}
              {'\n'}
              api_base_url:{' '}
              {JSON.stringify((config as unknown as Record<string, unknown>).api_base_url)}
              {'\n'}
              data_directory:{' '}
              {JSON.stringify((config as unknown as Record<string, unknown>).data_directory)}
              {'\n'}
              bundle_id: {JSON.stringify((config as unknown as Record<string, unknown>).bundle_id)}
            </pre>
          </details>
        </div>
      </div>

      {/* 1. Overlay Control — primary manual verification controls */}
      <div style={style.section}>
        <div style={style.header}>1. Overlay Control</div>
        <div style={{ fontSize: 12, marginBottom: 4 }}>
          <span style={style.label}>Overlay Visible: </span>
          <span style={{ color: overlayVisible ? 'green' : 'red', fontWeight: 700 }}>
            {overlayVisible ? 'YES' : 'NO'}
          </span>
        </div>
        <div style={{ fontSize: 12, marginBottom: 4 }}>
          <span style={style.label}>Click-through: </span>
          <span style={{ color: clickThrough ? 'green' : 'red', fontWeight: 700 }}>
            {clickThrough ? 'ON (mouse events pass through)' : 'OFF (overlay captures mouse)'}
          </span>
        </div>
        <div style={{ fontSize: 12, marginBottom: 4 }}>
          <span style={style.label}>Overlay Position: </span>
          <span style={style.value}>
            {overlayPosition ? `x=${overlayPosition.x}, y=${overlayPosition.y}` : 'unknown'}
          </span>
        </div>
        <div style={{ fontSize: 12, marginBottom: 4 }}>
          <span style={style.label}>Drag Mode: </span>
          <span style={style.value}>{dragDiagnostics?.dragMode ?? 'unknown'}</span>
          <span style={style.label}> | Active: </span>
          <span style={style.value}>{String(dragDiagnostics?.draggingActive ?? false)}</span>
        </div>
        <div style={{ fontSize: 12, marginBottom: 4 }}>
          <span style={style.label}>Runtime Mode: </span>
          <span style={style.value}>{followDiagnostics?.runtimeMode ?? 'unknown'}</span>
          <span style={style.label}> | Follow Loop: </span>
          <span style={style.value}>{String(followDiagnostics?.followLoopActive ?? false)}</span>
        </div>
        <div style={{ fontSize: 12, marginBottom: 4 }}>
          <span style={style.label}>Last Codex Read: </span>
          <span style={style.value}>{followDiagnostics?.lastCodexStateReadAt ?? 'none'}</span>
        </div>
        <div style={{ fontSize: 12, marginBottom: 4 }}>
          <span style={style.label}>Last Target Position: </span>
          <span style={style.value}>{followDiagnostics?.lastTargetPosition ?? 'none'}</span>
        </div>
        {followDiagnostics?.lastMoveFailure && (
          <p style={{ color: 'red', fontSize: 12, margin: '4px 0' }}>
            Last follow move failure: {followDiagnostics.lastMoveFailure}
          </p>
        )}
        <div style={{ fontSize: 12, marginBottom: 4 }}>
          <span style={style.label}>Mouse Down Count: </span>
          <span style={style.value}>{dragDiagnostics?.mouseDownCount ?? 0}</span>
          <span style={style.label}> | Last Mouse: </span>
          <span style={style.value}>{dragDiagnostics?.lastMousePosition ?? 'none'}</span>
        </div>
        {dragDiagnostics?.lastDragError && (
          <p style={{ color: 'red', fontSize: 12, margin: '4px 0' }}>
            Last drag error: {dragDiagnostics.lastDragError}
          </p>
        )}
        <div style={style.row}>
          <button style={style.button} onClick={showOverlay}>
            Show Overlay
          </button>
          <button style={style.button} onClick={hideOverlay}>
            Hide Overlay
          </button>
          <button style={style.button} onClick={handleRefreshOverlayVisible}>
            Refresh Visibility
          </button>
          <button style={style.button} onClick={refreshOverlayPosition}>
            Refresh Position/Drag Diagnostics
          </button>
        </div>
        <div style={style.row}>
          <button style={style.button} onClick={resetOverlayPosition}>
            Reset Overlay Position
          </button>
          <button style={style.button} onClick={resizeOverlayForDebug}>
            Resize Overlay for Debug
          </button>
        </div>
        {overlayControlError && (
          <p role="alert" style={{ color: 'red', fontSize: 12, margin: '4px 0' }}>
            Overlay control error: {overlayControlError}
          </p>
        )}
        <div style={style.row}>
          <button
            style={style.button}
            onClick={() => setClickThroughMode(true)}
            disabled={clickThrough}
          >
            Enable Click-Through
          </button>
          <button
            style={style.button}
            onClick={() => setClickThroughMode(false)}
            disabled={!clickThrough}
          >
            Disable Click-Through
          </button>
          <button style={style.button} onClick={toggleClickThrough}>
            Toggle Click-Through
          </button>
        </div>
      </div>

      {/* 2. Codex State */}
      <div style={style.section}>
        <div style={style.header}>2. Codex Pet State</div>
        <div style={{ marginBottom: 4 }}>
          <button style={style.button} onClick={fetchCodexState}>
            Refresh Codex State
          </button>
        </div>
        {codexStateLoading && <p>Loading...</p>}
        {codexStateError && <p style={{ color: 'red' }}>Error: {codexStateError}</p>}
        {codexState && (
          <div style={{ fontSize: 12 }}>
            <p>
              <span style={style.label}>State Available: </span>
              <span style={{ color: codexState.state_available ? 'green' : 'red' }}>
                {String(codexState.state_available)}
              </span>
            </p>
            <p>
              <span style={style.label}>Avatar Overlay Open: </span>
              <span style={style.value}>{String(codexState.avatar_overlay_open)}</span>
            </p>
            <p>
              <span style={style.label}>CODEX_HOME: </span>
              <span style={style.value}>{codexState.codex_home}</span>
            </p>
            <p>
              <span style={style.label}>Diagnostic: </span>
              <span style={style.value}>{codexState.diagnostic}</span>
            </p>
            {codexState.overlay_bounds && (
              <div>
                <p style={{ marginTop: 4 }}>
                  <span style={style.label}>Overlay Bounds: </span>
                  <span style={style.value}>
                    x={codexState.overlay_bounds.x}, y={codexState.overlay_bounds.y}, w=
                    {codexState.overlay_bounds.width}, h={codexState.overlay_bounds.height}
                  </span>
                </p>
                <p>
                  <span style={style.label}>Display Bounds: </span>
                  <span style={style.value}>
                    x={codexState.overlay_bounds.display_x}, y={codexState.overlay_bounds.display_y}
                    , w={codexState.overlay_bounds.display_width}, h=
                    {codexState.overlay_bounds.display_height}
                    (id={codexState.overlay_bounds.display_id})
                  </span>
                </p>
                {codexState.overlay_bounds.mascot && (
                  <p>
                    <span style={style.label}>Mascot/Pet Bounds: </span>
                    <span style={style.value}>
                      left={codexState.overlay_bounds.mascot.left}, top=
                      {codexState.overlay_bounds.mascot.top}, w=
                      {codexState.overlay_bounds.mascot.width}, h=
                      {codexState.overlay_bounds.mascot.height}
                    </span>
                  </p>
                )}
              </div>
            )}
          </div>
        )}
      </div>

      {/* 3. Screen Info */}
      <div style={style.section}>
        <div style={style.header}>
          3. Screen Info ({screens.length} monitor{screens.length !== 1 ? 's' : ''})
        </div>
        <div style={{ marginBottom: 4 }}>
          <button style={style.button} onClick={fetchScreens}>
            Refresh Screen List
          </button>
        </div>
        {screensLoading && <p>Loading...</p>}
        {screensError && <p style={{ color: 'red' }}>Error: {screensError}</p>}
        {screens.map((s, i) => (
          <pre key={i} style={style.pre}>
            [{i}] {s.is_primary ? '(Primary)' : '(Secondary)'}: x={s.x}, y={s.y}, {s.width}x
            {s.height} @ {Math.round(s.scale_factor * 100)}% DPI
          </pre>
        ))}
        <button
          style={style.button}
          onClick={testCoordinateConversion}
          disabled={!codexState?.overlay_bounds || screens.length === 0}
        >
          Convert Current Position
        </button>
        {convertedPosition && (
          <pre style={style.pre}>
            Nest position: x={convertedPosition.x.toFixed(1)}, y={convertedPosition.y.toFixed(1)} on
            screen[{convertedPosition.display_index}] @{' '}
            {Math.round(convertedPosition.scale_factor * 100)}% DPI
          </pre>
        )}
      </div>

      {/* 4. Tray */}
      <div style={style.section}>
        <div style={style.header}>4. Tray Status</div>
        <p style={{ fontSize: 12, color: '#666' }}>
          Tray icon and menu are managed by Rust (src-tauri/src/tray/builder.rs). macOS: check menu
          bar for CodexPet Nest icon. Right-click for menu. Windows/Linux: check system tray.
        </p>
        <p style={{ fontSize: 12, color: '#999', marginTop: 4 }}>
          Menu items: Show Overlay | Hide Overlay | Open Settings (Cmd+,) | Quit
        </p>
      </div>
    </div>
  );
}
