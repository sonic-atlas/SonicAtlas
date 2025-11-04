<script lang="ts">
	import type { Track } from '$lib/types';
	import TrackItem from './TrackItem.svelte';

	interface Props {
		tracks: Track[];
		onTrackSelect: (track: Track) => void;
		currentTrackId?: string;
	}

	let { tracks, onTrackSelect, currentTrackId }: Props = $props();
</script>

<div class="trackList">
	<h2>Tracks</h2>

	{#if tracks.length === 0}
		<p>No tracks uploaded yet</p>
	{:else}
		<div class="tracks">
			{#each tracks as track (track.id)}
				<TrackItem
					{track}
					isPlaying={currentTrackId === track.id}
					onClick={() => onTrackSelect(track)}
				/>
			{/each}
		</div>
	{/if}
</div>

<style>
	.trackList {
		border: 1px solid var(--text-secondary-color);
		padding: 20px;
		border-radius: 8px;
	}

	h2 {
		margin-top: 0;
		color: var(--text-primary-color);
	}

	.tracks {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	p {
		color: var(--text-secondary-color);
	}
</style>
