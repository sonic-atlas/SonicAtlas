<script lang="ts">
    import '@material/web/button/filled-button.js';
    import '@material/web/button/outlined-button.js';
    import '@material/web/icon/icon.js';
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

        document.body.style.overflow = 'hidden';

        return () => {
            document.body.style.overflow = '';
        };
    });
</script>

{#if !auth.isAuthenticated}
    <LoginForm />
{:else}
    <main>
        <div class="mainColumn">
            <div class="header">
                <h1>Sonic Atlas</h1>
                <div class="headerActions">
                    <md-filled-button
                        onclick={navigateToUpload}
                        onkeydown={(e: KeyboardEvent) => {
                            if (e.key === 'Enter' || e.key === ' ') navigateToUpload();
                        }}
                        role="button"
                        tabindex="0">Upload Release</md-filled-button
                    >
                    <md-filled-button
                        onclick={navigateToManage}
                        onkeydown={(e: KeyboardEvent) => {
                            if (e.key === 'Enter' || e.key === ' ') navigateToManage();
                        }}
                        role="button"
                        tabindex="0">Manage</md-filled-button
                    >
                    <md-outlined-button
                        class="logoutButton"
                        onclick={handleLogout}
                        onkeydown={(e: KeyboardEvent) => {
                            if (e.key === 'Enter' || e.key === ' ') handleLogout();
                        }}
                        role="button"
                        tabindex="0">Logout</md-outlined-button
                    >
                </div>
            </div>

            <div class="trackListContainer">
                <TrackList
                    {tracks}
                    onTrackSelect={handleTrackSelected}
                    currentTrackId={currentTrack?.id}
                />
            </div>
        </div>

        <div class="playerColumn">
            {#if currentTrack}
                <Player
                    bind:track={currentTrack}
                    bind:quality={selectedQuality}
                    oncloseplayer={handleClosePlayer}
                />
            {:else}
                <div class="playerPlaceholder">
                    <h2>Now Playing</h2>
                    <div class="placeholderContent">
                        <md-icon class="placeholderIcon">music_off</md-icon>
                        <p>Select a track to start listening</p>
                    </div>
                </div>
            {/if}
        </div>
    </main>
{/if}

<style>
    main {
        max-width: 1600px;
        margin: 0 auto;
        background-color: var(--background-color);
        height: 100vh;
        color: var(--text-primary-color);
        display: grid;
        grid-template-columns: 1fr 400px;
        overflow: hidden;
    }

    .mainColumn {
        display: flex;
        flex-direction: column;
        height: 100%;
        overflow: hidden;
        border-right: 1px solid var(--border-color);
    }

    .header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 20px;
        border-bottom: 1px solid var(--border-color);
        flex-shrink: 0;
    }

    .headerActions {
        display: flex;
        gap: 12px;
    }

    .logoutButton {
        --md-outlined-button-label-text-color: var(--error-color);
    }

    h1 {
        margin: 0;
        color: var(--text-primary-color);
        font-family: var(--md-sys-typescale-display-small-font);
    }

    .trackListContainer {
        flex: 1;
        overflow-y: auto;
        padding: 20px;
    }

    .playerColumn {
        height: 100%;
        overflow-y: auto;
        background-color: var(--surface-color);
        padding: 20px;
    }

    @media (max-width: 900px) {
        main {
            grid-template-columns: 1fr;
            height: auto;
            display: flex;
            flex-direction: column;
        }

        .mainColumn {
            height: auto;
            border-right: none;
            overflow: visible;
        }

        .trackListContainer {
            overflow: visible;
            padding: 0 20px 20px 20px;
        }

        .playerColumn {
            height: auto;
            overflow: visible;
            order: -1;
        }

        :global(body) {
            overflow: auto;
        }
    }

    .playerPlaceholder {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: flex-start;
        height: 100%;
        color: var(--text-secondary-color);
        padding-top: 20px;
    }

    .playerPlaceholder h2 {
        margin: 0 0 40px 0;
        color: var(--text-primary-color);
        font-family: var(--md-sys-typescale-display-small-font);
        font-size: 24px;
    }

    .placeholderContent {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 16px;
        margin-top: 100px;
        opacity: 0.7;
    }

    .placeholderIcon {
        font-size: 64px;
        color: var(--text-secondary-color);
    }
</style>
