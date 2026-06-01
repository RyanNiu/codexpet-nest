import { describe, it, expect, beforeEach, vi } from 'vitest';
import { fireEvent, render, screen } from '@testing-library/react';
import { invoke } from '@tauri-apps/api/core';
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';
import { OverlayApp } from './OverlayApp';
import { useAppConfigStore } from '@/store/appConfigStore';
import { FALLBACK_CONFIG } from '@/config';

describe('OverlayApp', () => {
  beforeEach(() => {
    // Reset store to loading state before each test.
    useAppConfigStore.setState({
      config: FALLBACK_CONFIG,
      isLoading: true,
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
    render(<OverlayApp />);
    expect(screen.getByTestId('nest-render-model')).toBeInTheDocument();
    expect(screen.getByTestId('widget-slot-clock')).toBeInTheDocument();
    expect(screen.getByText(/v0.1.12/)).toBeInTheDocument();
    expect(await screen.findByText(/standalone fallback/)).toBeInTheDocument();
  });

  it('should render debug overlay elements when isDebug is true', async () => {
    useAppConfigStore.getState().setConfig({
      ...FALLBACK_CONFIG,
      isDebug: true,
    });
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
    render(<OverlayApp />);

    // import.meta.env.DEV is true in vitest, so debug elements must render.
    expect(screen.getByTestId('debug-overlay-label')).toBeInTheDocument();
    expect(screen.getByTestId('debug-platform-label')).toBeInTheDocument();
    expect(await screen.findByText(/standalone fallback/)).toBeInTheDocument();
  });

  it('should switch built-in nest fixture in the overlay', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    render(<OverlayApp />);

    fireEvent.click(screen.getByRole('button', { name: 'capacity-orbit' }));

    expect(screen.getByText('capacity-orbit-nest')).toBeInTheDocument();
    expect(screen.getByTestId('metric-gauge-quota-ring')).toBeInTheDocument();
    expect(await screen.findByText(/standalone fallback/)).toBeInTheDocument();
  });

  it('should receive pointer events on drag bar and start manual fallback drag', async () => {
    vi.mocked(getCurrentWebviewWindow).mockReturnValueOnce({
      startDragging: vi.fn().mockRejectedValueOnce(new Error('native drag unavailable')),
    } as ReturnType<typeof getCurrentWebviewWindow>);
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
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
