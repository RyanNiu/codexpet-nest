import { describe, expect, it } from 'vitest';
import { builtInNestFixtures } from '../../fixtures/nests';
import { loadNestTheme } from './loadNestTheme';

describe('loadNestTheme', () => {
  it('loads built-in nest fixtures through core validation', () => {
    for (const fixture of builtInNestFixtures) {
      const result = loadNestTheme(fixture);
      expect(result.ok, fixture.id).toBe(true);
    }
  });
});
