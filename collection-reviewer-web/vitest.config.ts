import { defineConfig } from 'vitest/config';
import path from 'path';

// Node environment (these are server-side lib/route unit tests, no DOM). The `@/`
// alias mirrors tsconfig `paths` so route/lib modules resolve the same way Next does.
export default defineConfig({
  resolve: {
    alias: {
      '@': path.resolve(__dirname, '.'),
    },
  },
  test: {
    environment: 'node',
    include: ['**/*.test.ts'],
    exclude: ['node_modules/**', '.next/**'],
  },
});
