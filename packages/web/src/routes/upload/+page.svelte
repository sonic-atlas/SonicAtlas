<script lang="ts">
    import { page } from '$app/state';
    import { onMount } from 'svelte';
    import { apiFetch } from '$lib/api';
    import UploadReleaseForm from '$lib/components/upload/UploadReleaseForm.svelte';
    import ReleaseEditor from '$lib/components/upload/ReleaseEditor.svelte';

    let release = $state<any>(null);
    let tracks = $state<any[]>([]);
    let loading = $state(true);

    onMount(async () => {
        const id = page.url.searchParams.get('id');
        if (id) {
            try {
                const res = await apiFetch(`/api/releases/${id}`);
                if (res.ok) {
                    const data = await res.json();
                    release = data.release;
                    tracks = data.tracks;
                } else {
                    console.error('Failed to load release');
                }
            } catch (e) {
                console.error(e);
            }
        }
        loading = false;
    });

    function onUploadComplete(data: { release: any; tracks: any[] }) {
        release = data.release;
        tracks = data.tracks;
    }
</script>

<div class="upload-page">
    {#if loading}
        <p>Loading...</p>
    {:else if release}
        <ReleaseEditor {release} {tracks} />
    {:else}
        <UploadReleaseForm {onUploadComplete} />
    {/if}
</div>

<style>
    .upload-page {
        max-width: 800px;
        margin: 0 auto;
        padding: 2rem;
    }
</style>
