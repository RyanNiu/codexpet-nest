import type { OverlayMode, StandalonePosition } from '../settings';

export interface OverlayRuntimeDecision {
  shouldFollowCodex: boolean;
  shouldUseStandalonePosition: boolean;
}

export interface OverlayTargetPosition {
  x: number;
  y: number;
  displayId?: string;
}

export function getOverlayRuntimeDecision(mode: OverlayMode): OverlayRuntimeDecision {
  return {
    shouldFollowCodex: mode === 'follow-codex',
    shouldUseStandalonePosition: mode !== 'follow-codex',
  };
}

export function persistStandalonePosition(
  mode: OverlayMode,
  position: OverlayTargetPosition,
): StandalonePosition | null {
  if (mode === 'follow-codex') return null;
  return normalizeStandalonePosition(position);
}

export function normalizeStandalonePosition(position: OverlayTargetPosition): StandalonePosition {
  return {
    x: finiteOrZero(position.x),
    y: finiteOrZero(position.y),
    displayId: position.displayId,
  };
}

function finiteOrZero(value: number): number {
  return Number.isFinite(value) ? value : 0;
}
