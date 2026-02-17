<script lang="ts">
    import { uploadRelease, type ReleaseUploadProgress, type FileUploadProgress } from '$lib/upload/chunkedUploads';
    import { socket } from '$lib/stores/socket.svelte';
    import '@material/web/textfield/outlined-text-field.js';
    import '@material/web/button/filled-button.js';
    import '@material/web/button/outlined-button.js';
    import '@material/web/checkbox/checkbox.js';
    import '@material/web/select/outlined-select.js';
    import '@material/web/select/select-option.js';

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
    let uploadProgress = $state<ReleaseUploadProgress | null>(null);

    async function handleSubmit(e: Event) {
        e.preventDefault();
        if (!files || files.length === 0) {
            error = 'Please select files';
            return;
        }

        uploading = true;
        error = null;
        uploadProgress = null;

        const fileArray = Array.from(files);

        try {
            const data = await uploadRelease(
                {
                    title: releaseTitle,
                    primaryArtist,
                    year,
                    releaseType,
                    extractAllCovers,
                    socketId: socket.id
                },
                fileArray,
                coverFile,
                (progress) => {
                    uploadProgress = progress;
                }
            );
            onUploadComplete(data);
        } catch (err: any) {
            error = err.message;
        } finally {
            uploading = false;
        }
    }

    let dragging = $state(false);

    function handleDragOver(e: DragEvent) {
        e.preventDefault();
        dragging = true;
    }

    function handleDragLeave(e: DragEvent) {
        e.preventDefault();
        dragging = false;
    }

    function handleDrop(e: DragEvent) {
        e.preventDefault();
        dragging = false;
        if (e.dataTransfer && e.dataTransfer.files.length > 0) {
            files = e.dataTransfer.files;
        }
    }

    function getStatusIcon(status: FileUploadProgress['status']): string {
        switch (status) {
            case 'pending':
                return 'hourglass_empty';
            case 'uploading':
                return 'cloud_upload';
            case 'processing':
                return 'settings';
            case 'complete':
                return 'check_circle';
            case 'error':
                return 'error';
        }
    }

    function formatBytes(bytes: number): string {
        if (bytes < 1024) return `${bytes} B`;
        if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
        return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }
</script>

<form onsubmit={handleSubmit} class="uploadForm">
    <h2>Upload Release</h2>

    {#if error}
        <div class="error">{error}</div>
    {/if}

    <div class="formGroup">
        <label for="files">Audio Files</label>
        <div
            class="dropZone"
            class:dragging
            ondragover={handleDragOver}
            ondragleave={handleDragLeave}
            ondrop={handleDrop}
            role="button"
            tabindex="0"
            aria-label="Drop audio files here"
        >
            <md-icon class="uploadIcon">cloud_upload</md-icon>
            <p>
                {#if files && files.length > 0}
                    {files.length} files selected
                {:else}
                    Drag audio files here or click to select
                {/if}
            </p>
            <input
                type="file"
                id="files"
                multiple
                accept="audio/*"
                onchange={(e) => (files = (e.target as HTMLInputElement).files)}
                required={!files || files.length === 0}
                class="fileInput"
            />
        </div>
    </div>

    <div class="formGroup">
        <label for="cover">Release Cover (Optional)</label>
        <div class="fileInputWrapper">
            <md-outlined-button
                type="button"
                onclick={() => document.getElementById('cover')?.click()}
                onkeydown={(e: KeyboardEvent) => {
                    if (e.key === 'Enter' || e.key === ' ') document.getElementById('cover')?.click();
                }}
                role="button"
                tabindex="0"
            >
                Choose File
            </md-outlined-button>
            <span class="fileName">{coverFile ? coverFile.name : 'No file chosen'}</span>
            <input
                type="file"
                id="cover"
                accept="image/*"
                style="display: none;"
                onchange={(e) => (coverFile = (e.target as HTMLInputElement).files?.[0] ?? null)}
            />
        </div>
    </div>

    <div class="formGroup">
        <md-outlined-text-field
            label="Release Title"
            value={releaseTitle}
            oninput={(e: Event) => (releaseTitle = (e.target as HTMLInputElement).value)}
            required
        ></md-outlined-text-field>
    </div>

    <div class="formGroup">
        <md-outlined-text-field
            label="Primary Artist"
            value={primaryArtist}
            oninput={(e: Event) => (primaryArtist = (e.target as HTMLInputElement).value)}
            required
        ></md-outlined-text-field>
    </div>

    <div class="row">
        <div class="formGroup">
            <md-outlined-text-field
                label="Year"
                type="number"
                value={year}
                oninput={(e: Event) => (year = (e.target as HTMLInputElement).value)}
                required
            ></md-outlined-text-field>
        </div>

        <div class="formGroup">
            <md-outlined-select
                label="Type"
                value={releaseType}
                onchange={(e: Event) => (releaseType = (e.target as HTMLSelectElement).value)}
            >
                <md-select-option value="album">
                    <div slot="headline">Album</div>
                </md-select-option>
                <md-select-option value="ep">
                    <div slot="headline">EP</div>
                </md-select-option>
                <md-select-option value="single">
                    <div slot="headline">Single</div>
                </md-select-option>
                <md-select-option value="compilation">
                    <div slot="headline">Compilation</div>
                </md-select-option>
            </md-outlined-select>
        </div>
    </div>

    <div class="formGroup checkboxGroup">
        <md-checkbox
            id="extractAllCovers"
            checked={extractAllCovers}
            onchange={(e: Event) => (extractAllCovers = (e.target as HTMLInputElement).checked)}
        ></md-checkbox>
        <label for="extractAllCovers">Extract individual track covers</label>
    </div>

    {#if uploadProgress && uploading}
        <div class="progressSection">
            <div class="overallProgress">
                <div class="progressLabel">
                    <span>Overall Progress</span>
                    <span>{uploadProgress.overallProgress}%</span>
                </div>
                <div class="progressBar">
                    <div class="progressFill" style="width: {uploadProgress.overallProgress}%"></div>
                </div>
            </div>

            <div class="fileProgressList">
                {#each uploadProgress.files as fp}
                    <div class="fileProgress" class:error={fp.status === 'error'}>
                        <div class="fileProgressHeader">
                            <md-icon class="statusIcon {fp.status}">{getStatusIcon(fp.status)}</md-icon>
                            <span class="fileProgressName" title={fp.fileName}>{fp.fileName}</span>
                            <span class="fileProgressSize">
                                {formatBytes(fp.bytesUploaded)} / {formatBytes(fp.bytesTotal)}
                            </span>
                        </div>
                        {#if fp.status === 'uploading'}
                            <div class="progressBar small">
                                <div
                                    class="progressFill"
                                    style="width: {fp.bytesTotal > 0
                                        ? Math.round((fp.bytesUploaded / fp.bytesTotal) * 100)
                                        : 0}%"
                                ></div>
                            </div>
                        {/if}
                        {#if fp.error}
                            <span class="fileError">{fp.error}</span>
                        {/if}
                    </div>
                {/each}
            </div>
        </div>
    {/if}

    <md-filled-button type="submit" disabled={uploading}>
        {#if uploading && uploadProgress}
            Uploading... {uploadProgress.overallProgress}%
        {:else if uploading}
            Preparing...
        {:else}
            Upload
        {/if}
    </md-filled-button>
</form>

<style>
    .uploadForm {
        display: flex;
        flex-direction: column;
        gap: 1rem;
        max-width: 500px;
        padding: 1.5rem;
        background: var(--surface-color);
        border-radius: 8px;
    }

    .dropZone {
        border: 2px dashed var(--border-color);
        border-radius: 8px;
        padding: 2rem;
        text-align: center;
        cursor: pointer;
        transition:
            background 0.2s,
            border-color 0.2s;
        position: relative;
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 1rem;
        background: var(--surface-color);
        color: var(--text-secondary-color);
    }

    .dropZone:hover,
    .dropZone.dragging {
        background: var(--surface-high);
        border-color: var(--primary-color);
        color: var(--primary-color);
    }

    .fileInput {
        position: absolute;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        opacity: 0;
        cursor: pointer;
    }

    .formGroup {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
    }

    .checkboxGroup {
        flex-direction: row;
        align-items: center;
        gap: 0.5rem;
    }

    .row {
        display: flex;
        gap: 1rem;
    }

    .row .formGroup {
        flex: 1;
    }
    .error {
        color: var(--error-color);
        background: #ff000020;
        padding: 0.5rem;
        border-radius: 4px;
    }

    .fileInputWrapper {
        display: flex;
        align-items: center;
        gap: 1rem;
    }

    .fileName {
        color: var(--text-secondary-color);
        font-size: 0.9rem;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .uploadIcon {
        font-size: 48px;
    }

    .progressSection {
        display: flex;
        flex-direction: column;
        gap: 1rem;
    }

    .overallProgress {
        display: flex;
        flex-direction: column;
        gap: 0.25rem;
    }

    .progressLabel {
        display: flex;
        justify-content: space-between;
        font-size: 0.85rem;
        color: var(--text-secondary-color);
    }

    .progressBar {
        height: 8px;
        background: var(--surface-high, #333);
        border-radius: 4px;
        overflow: hidden;
    }

    .progressBar.small {
        height: 4px;
        margin-top: 0.25rem;
    }

    .progressFill {
        height: 100%;
        background: var(--primary-color);
        border-radius: 4px;
        transition: width 0.2s ease;
    }

    .fileProgressList {
        display: flex;
        flex-direction: column;
        gap: 0.5rem;
        max-height: 240px;
        overflow-y: auto;
    }

    .fileProgress {
        padding: 0.5rem;
        background: var(--surface-high, #222);
        border-radius: 6px;
    }

    .fileProgress.error {
        background: #ff000015;
    }

    .fileProgressHeader {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        font-size: 0.85rem;
    }

    .statusIcon {
        font-size: 18px;
    }

    .statusIcon.complete {
        color: #4caf50;
    }

    .statusIcon.error {
        color: var(--error-color);
    }

    .statusIcon.uploading {
        color: var(--primary-color);
    }

    .statusIcon.processing {
        color: #ff9800;
    }

    .fileProgressName {
        flex: 1;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .fileProgressSize {
        color: var(--text-secondary-color);
        font-size: 0.8rem;
        white-space: nowrap;
    }

    .fileError {
        color: var(--error-color);
        font-size: 0.8rem;
        margin-top: 0.25rem;
        display: block;
    }
</style>
