import { defineConfig } from "vite";

// Minimal Vite config for test module loading (ssrLoadModule).
// The web app has been removed; Setline is now iOS-first with a
// Cloudflare Worker API backend serving static public/ assets.
export default defineConfig({
  plugins: [],
});
