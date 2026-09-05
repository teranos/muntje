import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

// base './' so every asset reference in dist/index.html is relative: the
// bucket behind a.muntje.sbvh.nl serves it from the root, a local `open
// dist/index.html` works too, and nothing assumes a host.
export default defineConfig({
  base: './',
  plugins: [svelte()],
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    sourcemap: false,
  },
})
