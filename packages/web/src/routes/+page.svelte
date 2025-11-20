<script lang="ts">
    import TrackList from '$lib/components/tracks/TrackList.svelte';
    import Player from '$lib/components/player/Player.svelte';
    import LoginForm from '$lib/components/auth/LoginForm.svelte';
    import { goto } from '$app/navigation';
    import type { Track } from '$lib/types';
    import { apiGet } from '$lib/api';
    import { auth } from '$lib/stores/auth.svelte';
    import { onMount } from 'svelte';

    let tracks = $state<Track[]>([]);
    let currentTrack = $state<Track | null>(null);
    let selectedQuality = $state<'efficiency' | 'high' | 'cd' | 'hires'>('hires');

    async function loadTracks() {
        if (!auth.isAuthenticated) return;

        try {
            const res = await apiGet('/api/tracks');
            if (res.ok) {
                tracks = await res.json();
            } else if (res.status === 401 || res.status === 403) {
                auth.clearToken();
            }
        } catch (err) {
            console.error('Failed to load tracks:', err);
        }
    }

    function handleTrackSelected(track: Track) {
        currentTrack = track;
    }

    function handleClosePlayer() {
        console.log('Player error, closing player.');
        currentTrack = null;
    }

    function handleLogout() {
        auth.clearToken();
        tracks = [];
        currentTrack = null;
    }

    function navigateToUpload() {
        goto('/upload');
    }

    function navigateToManage() {
        goto('/manage');
    }

    onMount(() => {
        auth.loadFromStorage();
    });

    $effect(() => {
        if (auth.isAuthenticated) {
            loadTracks();
        }
    });
</script>

{#if !auth.isAuthenticated}
    <LoginForm />
{:else}
    <main>
        <div class="header">
            <h1>Sonic Atlas</h1>
            <div class="headerActions">
                <button class="primaryButton" onclick={navigateToUpload}>Upload Release</button>
                <button class="primaryButton" onclick={navigateToManage}>Manage</button>
                <button class="logoutButton" onclick={handleLogout}>Logout</button>
            </div>
        </div>

        <div class="content">
            <TrackList
                {tracks}
                onTrackSelect={handleTrackSelected}
                currentTrackId={currentTrack?.id}
            />

            {#if currentTrack}
                <Player
                    bind:track={currentTrack}
                    bind:quality={selectedQuality}
                    oncloseplayer={handleClosePlayer}
                />
            {/if}
        </div>
    </main>
{/if}

<style>
    main {
        max-width: 1200px;
        margin: 0 auto;
        padding: 20px;
        background-color: var(--background);
        min-height: 100vh;
    }

    .header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 20px;
    }

    .headerActions {
        display: flex;
        gap: 12px;
    }

    h1 {
        margin: 0;
        color: var(--text-primary-color);
    }

    .logoutButton {
        padding: 8px 16px;
        background: #f44336;
        color: var(--text-primary-color);
        border: none;
        border-radius: 6px;
        cursor: pointer;
        font-size: 14px;
        transition: opacity 0.2s;
    }

    .primaryButton {
        padding: 8px 16px;
        background: var(--primary-color);
        color: var(--text-primary-color);
        border: none;
        border-radius: 6px;
        cursor: pointer;
        font-size: 14px;
        transition: opacity 0.2s;
    }

    .logoutButton:hover {
        opacity: 0.9;
    }

    .primaryButton:hover {
        opacity: 0.9;
    }

    .content {
        display: grid;
        grid-template-columns: 1fr 400px;
        gap: 20px;
        margin-top: 20px;
    }

    @media (max-width: 768px) {
        .content {
            grid-template-columns: 1fr;
        }
    }
</style>
