import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { OverlayApp } from './OverlayApp';
import { useAppConfigStore } from '@/store/appConfigStore';
import { FALLBACK_CONFIG } from '@/config';

describe('OverlayApp', () => {
  it('should show loading state', () => {
    render(<OverlayApp />);
    expect(screen.getByText('Loading...')).toBeInTheDocument();
  });

  it('should render app name when config is loaded', () => {
    useAppConfigStore.getState().setConfig(FALLBACK_CONFIG);
    render(<OverlayApp />);
    expect(screen.getByText(/CodexPet Nest Nest/i)).toBeInTheDocument();
    expect(screen.getByText(/v0.1.12/)).toBeInTheDocument();
  });
});
