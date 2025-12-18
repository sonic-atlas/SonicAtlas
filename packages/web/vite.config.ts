import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { visualizer } from 'rollup-plugin-visualizer';

export default defineConfig({
    plugins: [sveltekit(), visualizer({ filename: 'stats.html' })],
    build: {
        chunkSizeWarningLimit: 500,
        rollupOptions: {
            output: {
                manualChunks(id) {
                    if (id.includes('node_modules')) {
                        const pkg = id.split('node_modules/')[1].split('/')[0];
                        return pkg;
                    }
                }
            }
        }
    }
});
