import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import adapter from '@sveltejs/adapter-node';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { visualizer } from 'rollup-plugin-visualizer';

export default defineConfig({
    plugins: [
        sveltekit({
            adapter: adapter(),
            env: {
                dir: '../../'
            },
            preprocess: vitePreprocess(),
            alias: {
                '$lib': 'src/lib'
            }
        }),
        visualizer({ filename: 'stats.html' })
    ],
    envDir: '../../',
    build: {
        chunkSizeWarningLimit: 500
    }
});
