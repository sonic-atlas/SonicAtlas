<script lang="ts">
    import { apiPostFormData } from '$lib/api';
    import { socket } from '$lib/stores/socket.svelte';

    let { onUploadComplete } = $props<{ onUploadComplete: (data: any) => void }>();

    let files: FileList | null = $state(null);
    let coverFile: File | null = $state(null);
    let releaseTitle = $state('');
    let primaryArtist = $state('');
    let year = $state(new Date().getFullYear().toString());
    let releaseType = $state('album');
    let extractAllCovers = $state(false);
    let uploading = $state(false);
    let error = $state<string | null>(null);

    async function handleSubmit(e: Event) {
        e.preventDefault();
        if (!files || files.length === 0) {
            error = 'Please select files';
            return;
        }

        uploading = true;
        error = null;

        const formData = new FormData();
        for (let i = 0; i < files.length; i++) {
            formData.append('files[]', files[i]);
        }
        if (coverFile) {
            formData.append('cover', coverFile);
        }
        formData.append('releaseTitle', releaseTitle);
        formData.append('primaryArtist', primaryArtist);
        formData.append('year', year);
        formData.append('releaseType', releaseType);
        formData.append('extractAllCovers', extractAllCovers.toString());

        if (socket.id) {
            formData.append('socketId', socket.id);
        }

        try {
            const res = await apiPostFormData('/api/releases/upload', formData);
            if (!res.ok) {
                const data = await res.json();
                throw new Error(data.message || 'Upload failed');
            }
            const data = await res.json();
            onUploadComplete(data);
        } catch (err: any) {
            error = err.message;
        } finally {
            uploading = false;
        }
    }
</script>

<form onsubmit={handleSubmit} class="upload-form">
    <h2>Upload Release</h2>

    {#if error}
        <div class="error">{error}</div>
    {/if}

    <div class="form-group">
        <label for="files">Audio Files</label>
        <input
            type="file"
            id="files"
            multiple
            accept="audio/*"
            onchange={(e) => (files = (e.target as HTMLInputElement).files)}
            required
        />
    </div>

    <div class="form-group">
        <label for="cover">Release Cover (Optional)</label>
        <input
            type="file"
            id="cover"
            accept="image/*"
            onchange={(e) => (coverFile = (e.target as HTMLInputElement).files?.[0] ?? null)}
        />
    </div>

    <div class="form-group">
        <label for="title">Release Title</label>
        <input type="text" id="title" bind:value={releaseTitle} placeholder="Album Title" />
    </div>

    <div class="form-group">
        <label for="artist">Primary Artist</label>
        <input type="text" id="artist" bind:value={primaryArtist} placeholder="Artist Name" />
    </div>

    <div class="row">
        <div class="form-group">
            <label for="year">Year</label>
            <input type="number" id="year" bind:value={year} />
        </div>

        <div class="form-group">
            <label for="type">Type</label>
            <select id="type" bind:value={releaseType}>
                <option value="album">Album</option>
                <option value="ep">EP</option>
                <option value="single">Single</option>
                <option value="compilation">Compilation</option>
            </select>
        </div>
    </div>

    <div class="form-group checkbox-group">
        <input type="checkbox" id="extractAllCovers" bind:checked={extractAllCovers} />
        <label for="extractAllCovers">Extract individual track covers</label>
    </div>

    <button type="submit" disabled={uploading}>
        {uploading ? 'Uploading...' : 'Upload'}
    </button>
</form>

<style>
    .upload-form {
        display: flex;
        flex-direction: column;
        gap: 1rem;
        max-width: 500px;
        padding: 1.5rem;
        background: var(--surface-1);
        border-radius: 8px;
    }

    .form-group {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
    }

    .checkbox-group {
        flex-direction: row;
        align-items: center;
        gap: 0.5rem;
    }

    .row {
        display: flex;
        gap: 1rem;
    }

    .row .form-group {
        flex: 1;
    }

    input,
    select {
        padding: 0.5rem;
        border-radius: 4px;
        border: 1px solid var(--border);
        background: var(--surface-2);
        color: var(--text);
    }

    button {
        padding: 0.75rem;
        background: var(--primary);
        color: white;
        border: none;
        border-radius: 4px;
        cursor: pointer;
        font-weight: bold;
    }

    button:disabled {
        opacity: 0.7;
        cursor: not-allowed;
    }

    .error {
        color: var(--error);
        background: #ff000020;
        padding: 0.5rem;
        border-radius: 4px;
    }
</style>
