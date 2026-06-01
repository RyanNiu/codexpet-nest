import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
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

  it('should render app name and version when config is loaded', () => {
    useAppConfigStore.getState().setConfig({
      ...FALLBACK_CONFIG,
      appName: 'CodexPet',
      isDebug: false, // explicitly false to test non-debug path
    });
    render(<OverlayApp />);
    // Note: Outside DEV/vitest, isDevOverlay is false when isDebug is false
    //       and no label=overlay param — so only the Nest/version text renders.
    expect(screen.getByText(/Nest/)).toBeInTheDocument();
    expect(screen.getByText(/v0.1.12/)).toBeInTheDocument();
  });

  it('should render debug overlay elements when isDebug is true', () => {
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
  });

  it('should render debug overlay elements in DEV mode even if isDebug is not set', () => {
    // Simulate Vite DEV mode: isDevOverlay falls back to import.meta.env.DEV.
    useAppConfigStore.getState().setConfig({
      ...FALLBACK_CONFIG,
      isDebug: undefined as unknown as boolean, // simulate missing field
    });
    render(<OverlayApp />);

    // import.meta.env.DEV is true in vitest, so debug elements must render.
    expect(screen.getByTestId('debug-overlay-label')).toBeInTheDocument();
    expect(screen.getByTestId('debug-platform-label')).toBeInTheDocument();
  });
});
