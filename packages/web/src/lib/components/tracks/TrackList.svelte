<script lang="ts">
    import '@material/web/list/list.js';
    import '@material/web/icon/icon.js';
    import '@material/web/iconbutton/icon-button.js';
    import '@material/web/button/text-button.js';
    import '@material/web/menu/menu.js';
    import '@material/web/menu/menu-item.js';
    import '@material/web/divider/divider.js';
    import '@material/web/checkbox/checkbox.js';
    import type { Track } from '$lib/types';
    import TrackItem from './TrackItem.svelte';

    interface Props {
        tracks: Track[];
        onTrackSelect: (track: Track) => void;
        currentTrackId?: string;
    }

    let { tracks, onTrackSelect, currentTrackId }: Props = $props();

    let sortBy = $state<'year' | 'name' | 'artist'>('year');
    let sortMenuOpen = $state(false);

    type GroupedTrack =
        | { type: 'header'; title: string; subtitle: string; id: string }
        | { type: 'disc-header'; title: string; id: string }
        | { type: 'track'; track: Track };

    function getSortedTracks(
        inputTracks: Track[],
        group: boolean,
        sort: typeof sortBy
    ): GroupedTrack[] {
        const groups = new Map<string, Track[]>();
        inputTracks.forEach((t) => {
            const key = t.releaseId || 'unknown';
            if (!groups.has(key)) groups.set(key, []);
            groups.get(key)!.push(t);
        });

        const sortedKeys = Array.from(groups.keys()).sort((a, b) => {
            if (a === 'unknown') return 1;
            if (b === 'unknown') return -1;

            const tracksA = groups.get(a)!;
            const tracksB = groups.get(b)!;
            const repA = tracksA[0];
            const repB = tracksB[0];

            if (sort === 'year') {
                return (repB.releaseYear || 0) - (repA.releaseYear || 0);
            } else if (sort === 'name') {
                return (repA.releaseTitle || '').localeCompare(repB.releaseTitle || '');
            } else {
                return (repA.releaseArtist || '').localeCompare(repB.releaseArtist || '');
            }
        });

        const result: GroupedTrack[] = [];

        sortedKeys.forEach((key) => {
            const groupTracks = groups.get(key)!;

            groupTracks.sort((a, b) => {
                const discA = a.discNumber || 1;
                const discB = b.discNumber || 1;
                if (discA !== discB) return discA - discB;
                return (a.trackNumber || 0) - (b.trackNumber || 0);
            });

            const distinctDiscs = new Set(groupTracks.map((t) => t.discNumber || 1));
            const hasMultipleDiscs = distinctDiscs.size > 1;

            if (key !== 'unknown') {
                const rep = groupTracks[0];
                result.push({
                    type: 'header',
                    title: rep.releaseTitle,
                    subtitle: `${rep.releaseArtist} • ${rep.releaseYear}`,
                    id: key
                });
            }

            let currentDisc = -1;

            groupTracks.forEach((t) => {
                const disc = t.discNumber || 1;
                if (hasMultipleDiscs && disc !== currentDisc) {
                    currentDisc = disc;
                    result.push({
                        type: 'disc-header',
                        title: `Disc ${disc}`,
                        id: `${key}-disc-${disc}`
                    });
                }
                result.push({ type: 'track', track: t });
            });
        });

        return result;
    }

    let displayItems = $derived(getSortedTracks(tracks, true, sortBy));
</script>

<div class="trackListContainer">
    <div class="header">
        <h2>Tracks</h2>
        <div class="actions">
            <span style="position: relative;">
                <md-text-button
                    id="sort-menu-anchor"
                    onclick={() => {
                        sortMenuOpen = !sortMenuOpen;
                    }}
                    onkeydown={(e: KeyboardEvent) => {
                        if (e.key === 'Enter' || e.key === ' ') sortMenuOpen = !sortMenuOpen;
                    }}
                    aria-label="Sort options"
                    role="button"
                    tabindex="0"
                >
                    <md-icon slot="icon">sort</md-icon>
                    Sort by: {sortBy.charAt(0).toUpperCase() + sortBy.slice(1)}
                </md-text-button>

                <md-menu
                    anchor="sort-menu-anchor"
                    open={sortMenuOpen}
                    onclosed={() => (sortMenuOpen = false)}
                >
                    <div class="menuContent">
                        <md-menu-item
                            onclick={() => (sortBy = 'year')}
                            onkeydown={(e: KeyboardEvent) => {
                                if (e.key === 'Enter' || e.key === ' ') sortBy = 'year';
                            }}
                            selected={sortBy === 'year'}
                            role="menuitem"
                            tabindex="0"
                        >
                            <div slot="headline">Year</div>
                        </md-menu-item>
                        <md-menu-item
                            onclick={() => (sortBy = 'name')}
                            onkeydown={(e: KeyboardEvent) => {
                                if (e.key === 'Enter' || e.key === ' ') sortBy = 'name';
                            }}
                            selected={sortBy === 'name'}
                            role="menuitem"
                            tabindex="0"
                        >
                            <div slot="headline">Name</div>
                        </md-menu-item>
                        <md-menu-item
                            onclick={() => (sortBy = 'artist')}
                            onkeydown={(e: KeyboardEvent) => {
                                if (e.key === 'Enter' || e.key === ' ') sortBy = 'artist';
                            }}
                            selected={sortBy === 'artist'}
                            role="menuitem"
                            tabindex="0"
                        >
                            <div slot="headline">Artist</div>
                        </md-menu-item>
                    </div>
                </md-menu>
            </span>
        </div>
    </div>

    {#if tracks.length === 0}
        <p>No tracks uploaded yet</p>
    {:else}
        <md-list>
            {#each displayItems as item (item.type === 'header' ? `h-${item.id}` : item.type === 'disc-header' ? `d-${item.id}` : item.track.id)}
                {#if item.type === 'header'}
                    <div class="groupHeader">
                        <div class="groupTitle">{item.title}</div>
                        <div class="groupSubtitle">{item.subtitle}</div>
                    </div>
                {:else if item.type === 'disc-header'}
                    <div class="discHeader">
                        <md-icon class="discIcon">album</md-icon>
                        <span>{item.title}</span>
                    </div>
                {:else if item.type === 'track'}
                    <TrackItem
                        track={item.track}
                        isPlaying={currentTrackId === item.track.id}
                        onClick={() => onTrackSelect(item.track)}
                    />
                {/if}
            {/each}
        </md-list>
    {/if}
</div>

<style>
    .trackListContainer {
        padding: 0;
    }

    .header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding-right: 16px;
    }

    h2 {
        margin: 0 0 16px 16px;
        color: var(--text-primary-color);
        font-family: var(--md-sys-typescale-title-large-font);
        font-weight: 500;
    }

    .groupHeader {
        padding: 40px 16px 16px 16px;
        color: var(--text-primary-color);
        background: transparent;
        border-bottom: 1px solid var(--outline-variant);
        margin-bottom: 8px;
    }

    .groupTitle {
        font-family: var(--md-sys-typescale-headline-small-font);
        font-weight: 500;
        color: var(--primary-color);
        margin-bottom: 4px;
    }

    .groupSubtitle {
        font-family: var(--md-sys-typescale-body-small-font);
        color: var(--text-secondary-color);
    }

    .discHeader {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 16px 16px 8px 16px;
        color: var(--text-secondary-color);
        font-family: var(--md-sys-typescale-title-small-font);
        font-weight: 500;
        margin-top: 8px;
    }

    .discIcon {
        font-size: 18px;
        width: 18px;
        height: 18px;
    }

    .menuContent {
        padding: 8px 0;
    }

    md-list {
        background: transparent;
        --md-list-container-color: transparent;
        padding-bottom: 80px;
    }

    p {
        margin-left: 16px;
        color: var(--text-secondary-color);
        font-family: var(--md-sys-typescale-body-medium-font);
    }
</style>
