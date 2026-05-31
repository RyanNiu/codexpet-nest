import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { SettingsApp } from './SettingsApp';
import { useAppConfigStore } from '@/store/appConfigStore';
import { FALLBACK_CONFIG } from '@/config';

describe('SettingsApp', () => {
  it('should show loading state', () => {
    render(<SettingsApp />);
    expect(screen.getByText('Loading configuration...')).toBeInTheDocument();
  });

  it('should render config details when loaded', () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    render(<SettingsApp />);
    expect(screen.getByText(/Settings/i)).toBeInTheDocument();
    expect(screen.getByText(/Version: 0.1.12/)).toBeInTheDocument();
  });

  it('should show error state', () => {
    useAppConfigStore.getState().setError('Test error');
    render(<SettingsApp />);
    expect(screen.getByText(/Test error/)).toBeInTheDocument();
  });
});
