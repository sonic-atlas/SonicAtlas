<script lang="ts">
    import { apiPost } from '$lib/api';

    interface Props {
        onUploaded?: () => void;
    }

    let { onUploaded }: Props = $props();

    let file = $state<File | null>(null);
    let uploading = $state(false);
    let error = $state<string | null>(null);
    let success = $state(false);

    async function handleSubmit(e: Event) {
        e.preventDefault();
        if (!file) return;

        uploading = true;
        error = null;
        success = false;

        const formData = new FormData();
        formData.append('audio', file);

        try {
            const res = await apiPost('/api/tracks/upload', formData);

            if (!res.ok) {
                const data = await res.json();
                throw new Error(data.message || 'Upload failed');
            }

            success = true;
            file = null;
            onUploaded?.();
        } catch (err) {
            error = err instanceof Error ? err.message : 'Upload failed';
        } finally {
            uploading = false;
        }
    }

    function handleFileChange(e: Event) {
        const target = e.target as HTMLInputElement;
        file = target.files?.[0] || null;
        success = false;
        error = null;
    }
</script>

<div class="uploadForm">
    <h2>Upload Audio</h2>

    <form onsubmit={handleSubmit}>
        <input
            type="file"
            accept="audio/flac,audio/mpeg,audio/wav,audio/aac"
            onchange={handleFileChange}
            disabled={uploading}
        />

        <button type="submit" disabled={!file || uploading}>
            {uploading ? 'Uploading...' : 'Upload'}
        </button>
    </form>

    {#if error}
        <div class="message error">{error}</div>
    {/if}

    {#if success}
        <div class="message success">Upload successful!</div>
    {/if}
</div>

<style>
    .uploadForm {
        border: 1px solid var(--text-secondary-color);
        padding: 20px;
        border-radius: 8px;
        margin-bottom: 20px;
    }

    h2 {
        margin-top: 0;
        color: var(--text-primary-color);
    }

    form {
        display: flex;
        gap: 10px;
        align-items: center;
    }

    button {
        padding: 8px 16px;
        cursor: pointer;
        background: var(--primary-color);
        color: var(--text-primary-color);
        border: none;
        border-radius: 4px;
        transition: opacity 0.2s;
    }

    button:hover:not(:disabled) {
        opacity: 0.9;
    }

    button:disabled {
        opacity: 0.5;
        cursor: not-allowed;
    }

    .message {
        margin-top: 10px;
        padding: 10px;
        border-radius: 4px;
    }

    .error {
        background: #fee;
        color: #c00;
    }

    .success {
        background: #efe;
        color: #060;
    }
</style>
