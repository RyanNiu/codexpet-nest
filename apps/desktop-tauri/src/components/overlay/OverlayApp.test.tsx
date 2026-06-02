import { describe, it, expect, beforeEach, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import { invoke } from '@tauri-apps/api/core';
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';
import { createDefaultSettings } from '@codexpet/core';
import { OverlayApp } from './OverlayApp';
import { useAppConfigStore } from '@/store/appConfigStore';
import { builtInNestRegistryEntries, useRegistryStore } from '@/store/registryStore';
import { useSettingsStore } from '@/store/settingsStore';
import { FALLBACK_CONFIG } from '@/config';

describe('OverlayApp', () => {
  const registry = { schemaVersion: 1, packages: builtInNestRegistryEntries };

  beforeEach(() => {
    // Reset store to loading state before each test.
    useAppConfigStore.setState({
      config: FALLBACK_CONFIG,
      isLoading: true,
      error: null,
    });
    useRegistryStore.setState({
      registry,
      isLoading: true,
      isSaving: false,
      error: null,
    });
    useSettingsStore.setState({
      settings: createDefaultSettings(),
      isLoading: true,
      isSaving: false,
      error: null,
    });
  });

  it('should show loading state', () => {
    render(<OverlayApp />);
    expect(screen.getByText('Loading...')).toBeInTheDocument();
  });

  it('should render app name, version, and nest render model when config is loaded', async () => {
    useAppConfigStore.getState().setConfig({
      ...FALLBACK_CONFIG,
      appName: 'CodexPet',
      isDebug: false, // explicitly false to test non-debug path
    });
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<OverlayApp />);
    expect(screen.getByTestId('nest-render-model')).toBeInTheDocument();
    expect(screen.getByTestId('widget-slot-clock')).toBeInTheDocument();
    expect(screen.getByText(/Usage 68%/)).toBeInTheDocument();
    expect(screen.getByTestId('quick-actions')).toBeInTheDocument();
    expect(screen.getByText(/v0.1.12/)).toBeInTheDocument();
    expect(await screen.findByText(/standalone fallback/)).toBeInTheDocument();
  });

  it('should execute quick action and show result', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<OverlayApp />);

    fireEvent.click(screen.getByRole('button', { name: 'Open Docs' }));

    expect(await screen.findByText(/Action: mocked: Action completed in test/)).toBeInTheDocument();
    expect(vi.mocked(invoke)).toHaveBeenCalledWith(
      'execute_quick_action',
      expect.objectContaining({
        action: expect.objectContaining({ id: 'open-codexpet-docs', type: 'url' }),
      }),
    );
  });

  it('should require confirmation before running confirm actions', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<OverlayApp />);
    expect(await screen.findByText(/standalone fallback/)).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'Open Codex Path' }));

    expect(screen.getByText(/Action: Confirm Open Codex Path to run/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Confirm Open Codex Path' })).toBeInTheDocument();
    expect(vi.mocked(invoke)).not.toHaveBeenCalledWith(
      'execute_quick_action',
      expect.objectContaining({
        action: expect.objectContaining({ id: 'open-codex-path' }),
      }),
    );
  });

  it('should render debug overlay elements when isDebug is true', async () => {
    useAppConfigStore.getState().setConfig({
      ...FALLBACK_CONFIG,
      isDebug: true,
    });
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<OverlayApp />);

    // Debug elements must be visible.
    expect(screen.getByTestId('overlay-root')).toBeInTheDocument();
    expect(screen.getByTestId('debug-overlay-label')).toBeInTheDocument();
    expect(screen.getByTestId('debug-overlay-label')).toHaveTextContent('DEBUG OVERLAY');
    expect(screen.getByTestId('debug-platform-label')).toBeInTheDocument();
    expect(screen.getByTestId('overlay-drag-region')).toHaveAttribute('data-tauri-drag-region');
    expect(screen.getByText('Drag Overlay')).toBeInTheDocument();
    expect(await screen.findByText(/standalone fallback/)).toBeInTheDocument();
  });

  it('should render debug overlay elements in DEV mode even if isDebug is not set', async () => {
    // Simulate Vite DEV mode: isDevOverlay falls back to import.meta.env.DEV.
    useAppConfigStore.getState().setConfig({
      ...FALLBACK_CONFIG,
      isDebug: undefined as unknown as boolean, // simulate missing field
    });
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<OverlayApp />);

    // import.meta.env.DEV is true in vitest, so debug elements must render.
    expect(screen.getByTestId('debug-overlay-label')).toBeInTheDocument();
    expect(screen.getByTestId('debug-platform-label')).toBeInTheDocument();
    expect(await screen.findByText(/standalone fallback/)).toBeInTheDocument();
  });

  it('should switch built-in nest fixture in the overlay', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<OverlayApp />);

    fireEvent.click(screen.getByRole('button', { name: 'capacity-orbit' }));

    expect(await screen.findByText('capacity-orbit-nest')).toBeInTheDocument();
    expect(await screen.findByTestId('metric-gauge-quota-ring')).toBeInTheDocument();
    expect(await screen.findByText(/standalone fallback/)).toBeInTheDocument();
  });

  it('should render saved built-in nest and overlay mode', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({
      settings: {
        ...createDefaultSettings(),
        activeNestId: 'basket-pomodoro-nest',
        overlayMode: 'standalone-fixed',
      },
      isLoading: false,
    });

    render(<OverlayApp />);

    expect(screen.getByText('basket-pomodoro-nest')).toBeInTheDocument();
    expect(screen.getByText(/mode: standalone-fixed/)).toBeInTheDocument();
    expect(await screen.findByText(/standalone-fixed from local settings/)).toBeInTheDocument();
  });

  it('should fallback to default when saved active nest is not in registry', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({
      settings: {
        ...createDefaultSettings(),
        activeNestId: 'missing-nest',
      },
      isLoading: false,
    });

    render(<OverlayApp />);

    expect(screen.getAllByText('default').length).toBeGreaterThan(0);
    expect(screen.getByText(/Registry fallback: missing-nest -> default/)).toBeInTheDocument();
    expect(
      await screen.findByText(/registry fallback missing-nest -> default/),
    ).toBeInTheDocument();
  });

  it('should render imported nest issue when local asset is missing', async () => {
    const importedNest = {
      ...builtInNestRegistryEntries[0]!,
      id: 'imported-nest',
      name: 'Imported Nest',
      manifestPath: '/tmp/imported/codexpet-package.json',
      assetRoot: '/tmp/imported',
    };
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({
      registry: { schemaVersion: 1, packages: [...builtInNestRegistryEntries, importedNest] },
      isLoading: false,
    });
    useSettingsStore.setState({
      settings: {
        ...createDefaultSettings(),
        activeNestId: 'imported-nest',
      },
      isLoading: false,
    });
    vi.mocked(invoke).mockImplementation((command) => {
      if (command === 'load_local_nest_package') {
        return Promise.resolve({
          nestLayout: {
            schemaVersion: '1.0.0',
            canvas: { width: 100, height: 80 },
            layers: [
              {
                id: 'missing',
                type: 'image',
                src: 'assets/missing.png',
                frame: { x: 0, y: 0, width: 100, height: 80 },
              },
            ],
          },
          missingAssets: ['assets/missing.png'],
        });
      }
      if (command === 'get_codex_state') {
        return Promise.resolve({
          overlay_bounds: null,
          avatar_overlay_open: true,
          state_available: true,
          diagnostic: 'test',
          codex_home: '/tmp/.codex',
        });
      }
      if (command === 'set_overlay_click_through') return Promise.resolve(undefined);
      return Promise.reject(new Error(`Unhandled invoke command: ${String(command)}`));
    });

    render(<OverlayApp />);

    expect(
      await screen.findByText(/Missing local assets: assets\/missing.png/),
    ).toBeInTheDocument();
    expect(screen.getByTestId('nest-render-model')).toBeInTheDocument();
  });

  it('should receive pointer events on drag bar and start manual fallback drag', async () => {
    vi.mocked(getCurrentWebviewWindow).mockReturnValueOnce({
      startDragging: vi.fn().mockRejectedValueOnce(new Error('native drag unavailable')),
    } as unknown as ReturnType<typeof getCurrentWebviewWindow>);
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    useRegistryStore.setState({ registry, isLoading: false });
    useSettingsStore.setState({ settings: createDefaultSettings(), isLoading: false });
    render(<OverlayApp />);

    const pointerDown = new MouseEvent('pointerdown', {
      bubbles: true,
      cancelable: true,
      button: 0,
      screenX: 120,
      screenY: 140,
    });
    Object.defineProperty(pointerDown, 'pointerId', { value: 1 });

    fireEvent(screen.getByTestId('overlay-drag-region'), pointerDown);

    expect(await screen.findByText('mouse down: 1')).toBeInTheDocument();
    expect(await screen.findByText('mode: manual-fallback')).toBeInTheDocument();
    expect(vi.mocked(invoke)).toHaveBeenCalledWith('get_overlay_position');
  });
});
