import { describe, expect, it } from 'vitest';
import {
  getOverlayRuntimeDecision,
  normalizeStandalonePosition,
  persistStandalonePosition,
} from './index';

describe('overlay runtime mode boundaries', () => {
  it('uses Codex bounds only in follow-codex mode', () => {
    expect(getOverlayRuntimeDecision('follow-codex')).toEqual({
      shouldFollowCodex: true,
      shouldUseStandalonePosition: false,
    });
    expect(getOverlayRuntimeDecision('standalone-fixed')).toEqual({
      shouldFollowCodex: false,
      shouldUseStandalonePosition: true,
    });
  });

  it('does not overwrite manual position while following Codex', () => {
    expect(persistStandalonePosition('follow-codex', { x: 10, y: 20 })).toBeNull();
    expect(persistStandalonePosition('standalone-fixed', { x: 10, y: 20 })).toEqual({
      x: 10,
      y: 20,
    });
  });

  it('normalizes invalid manual coordinates before persistence', () => {
    expect(normalizeStandalonePosition({ x: Number.NaN, y: Number.POSITIVE_INFINITY })).toEqual({
      x: 0,
      y: 0,
    });
  });
});
