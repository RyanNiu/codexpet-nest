import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { SettingsApp } from './SettingsApp';
import { useAppConfigStore } from '@/store/appConfigStore';
import { FALLBACK_CONFIG } from '@/config';

vi.mock('@/components/debug/DebugPanel', () => ({
  DebugPanel: () => <div data-testid="debug-panel" />,
}));

describe('SettingsApp', () => {
  it('should show loading state', () => {
    render(<SettingsApp />);
    expect(screen.getByText('Loading configuration...')).toBeInTheDocument();
  });

  it('should render config details when loaded', () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    render(<SettingsApp />);
    expect(screen.getByRole('heading', { name: /Settings/i })).toBeInTheDocument();
    expect(screen.getByText(/Version: 0.1.12/)).toBeInTheDocument();
  });

  it('should show error state', () => {
    useAppConfigStore.getState().setError('Test error');
    render(<SettingsApp />);
    expect(screen.getByText(/Test error/)).toBeInTheDocument();
  });
});
