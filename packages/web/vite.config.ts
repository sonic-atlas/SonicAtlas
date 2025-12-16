import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
    plugins: [sveltekit()],
    // TODO: implement actual fix for one large bundle
    build: {
        chunkSizeWarningLimit: 1000
    }
});
