import { describe, it, expect, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { invoke } from '@tauri-apps/api/core';
import { DebugPanel } from './DebugPanel';
import { useAppConfigStore } from '@/store/appConfigStore';
import { FALLBACK_CONFIG } from '@/config';

describe('DebugPanel', () => {
  it('calls backend overlay commands from Show/Hide buttons', async () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    render(<DebugPanel />);

    await waitFor(() => expect(invoke).toHaveBeenCalledWith('is_overlay_visible'));

    fireEvent.click(screen.getByRole('button', { name: 'Show Overlay' }));
    await waitFor(() => expect(invoke).toHaveBeenCalledWith('show_overlay'));

    fireEvent.click(screen.getByRole('button', { name: 'Hide Overlay' }));
    await waitFor(() => expect(invoke).toHaveBeenCalledWith('hide_overlay'));

    fireEvent.click(screen.getByRole('button', { name: 'Reset Overlay Position' }));
    await waitFor(() => expect(invoke).toHaveBeenCalledWith('reset_overlay_position'));

    fireEvent.click(screen.getByRole('button', { name: 'Resize Overlay for Debug' }));
    await waitFor(() => expect(invoke).toHaveBeenCalledWith('resize_overlay_debug'));

    fireEvent.click(screen.getByRole('button', { name: 'Refresh Position/Drag Diagnostics' }));
    await waitFor(() => expect(invoke).toHaveBeenCalledWith('get_overlay_position'));
  });

  it('shows overlay command errors in the panel', async () => {
    vi.mocked(invoke).mockImplementation((command) => {
      if (command === 'hide_overlay') {
        return Promise.reject(new Error('Overlay window not found'));
      }
      if (command === 'is_overlay_visible') {
        return Promise.resolve(true);
      }
      return Promise.resolve([]);
    });

    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    render(<DebugPanel />);

    fireEvent.click(screen.getByRole('button', { name: 'Hide Overlay' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('Overlay window not found');
  });

  it('shows overlay follow diagnostics from local debug state', async () => {
    window.localStorage.setItem(
      'codexpet.overlay.followDiagnostics',
      JSON.stringify({
        runtimeMode: 'follow-codex',
        lastCodexStateReadAt: '2026-06-02T00:00:00.000Z',
        lastTargetPosition: 'x=256, y=150',
        followLoopActive: true,
        lastMoveFailure: 'none',
      }),
    );
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);

    render(<DebugPanel />);

    expect(await screen.findByText('follow-codex')).toBeInTheDocument();
    expect(screen.getByText('2026-06-02T00:00:00.000Z')).toBeInTheDocument();
    expect(screen.getByText('x=256, y=150')).toBeInTheDocument();
    expect(screen.getByText(/Last follow move failure: none/)).toBeInTheDocument();
  });
});
