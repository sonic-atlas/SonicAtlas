<script lang="ts">
    import type { Quality, TrackMetadata } from '$lib/types';
    import { apiGet } from '$lib/api';

    interface Props {
        quality: Quality;
        metadata: TrackMetadata | null;
        trackId: string;
    }

    let { quality = $bindable(), metadata, trackId }: Props = $props();

    const qualities: { value: Quality; label: string; description: string }[] = [
        { value: 'efficiency', label: 'Efficiency', description: 'AAC 128k' },
        { value: 'high', label: 'High', description: 'AAC 320k' },
        { value: 'cd', label: 'CD Quality', description: 'FLAC 44.1kHz' },
        { value: 'hires', label: 'Hi-Res', description: 'FLAC Original' }
    ];

    let sourceQuality = $state<Quality>(quality);
    let availableQualities = $state<Quality[]>([]);
    let preferredQuality = $state<Quality>(quality);
    let isTemporarilyDowngraded = $state<boolean>(false);

    async function loadAvailableQualities() {
        try {
            const res = await apiGet(`/api/stream/${trackId}/quality`);
            if (res.ok) {
                const data = await res.json();
                sourceQuality = data.sourceQuality;
                availableQualities = data.availableQualities;
            }
        } catch (err) {
            console.error('Failed to load quality info:', err);
            availableQualities = ['efficiency', 'high', 'cd', 'hires'];
        }
    }

    function findBestAvailableQuality(preferred: Quality): Quality {
        const qualityOrder: Quality[] = ['hires', 'cd', 'high', 'efficiency'];
        const preferredIndex = qualityOrder.indexOf(preferred);
        
        for (let i = preferredIndex; i < qualityOrder.length; i++) {
            if (availableQualities.includes(qualityOrder[i])) {
                return qualityOrder[i];
            }
        }
        
        return availableQualities[0] || 'efficiency';
    }


    $effect(() => {
        if (trackId) {
            loadAvailableQualities();
        }
    });

    $effect(() => {
        if (availableQualities.length > 0) {
            if (!availableQualities.includes(preferredQuality)) {
                const bestAvailable = findBestAvailableQuality(preferredQuality);
                quality = bestAvailable;
                isTemporarilyDowngraded = true;
            } else {
                if (isTemporarilyDowngraded && availableQualities.includes(preferredQuality)) {
                    quality = preferredQuality;
                    isTemporarilyDowngraded = false;
                }
            }
        }
    });

    function isQualityAvailable(q: Quality): boolean {
        if (availableQualities.length === 0) return true;
        return availableQualities.includes(q);
    }

    function getQualityNote(q: Quality): string | null {
        if (q === sourceQuality) {
            return 'Source Quality';
        }
        if (!isQualityAvailable(q)) {
            return 'Not available for this file';
        }
        return null;
    }
</script>

<div class="qualitySelector">
    <div class="labelText">Playback Quality</div>
    
    <div class="options" role="group" aria-label="Playback Quality">
        {#each qualities as q (q.value)}
            {@const available = isQualityAvailable(q.value)}
            {@const note = getQualityNote(q.value)}
            <button
                class="qualityOption"
                class:active={quality === q.value}
                class:disabled={!available}
                disabled={!available}
                onclick={() => available && (quality = q.value)}
            >
                <div class="label">
                    {q.label}
                    {#if q.value === sourceQuality}
                        <span class="badge">Source</span>
                    {/if}
                </div>
                <div class="description">{q.description}</div>
                {#if note && !available}
                    <div class="note">{note}</div>
                {/if}
            </button>
        {/each}
    </div>
</div>

<style>
    .qualitySelector {
        margin-bottom: 20px;
    }

    .labelText{
        display: block;
        font-weight: bold;
        margin-bottom: 10px;
        color: var(--text-primary-color);
    }

    .options {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 8px;
        margin-bottom: 10px;
    }

    .qualityOption {
        padding: 10px;
        border: 1px solid var(--text-secondary-color);
        border-radius: 4px;
        background: var(--background);
        cursor: pointer;
        text-align: left;
        transition: all 0.2s;
    }

    .qualityOption:hover:not(:disabled) {
        background: var(--primary-surface-color);
    }

    .qualityOption.active {
        border-color: var(--primary-color);
        background: var(--primary-surface-color);
    }

    .qualityOption.disabled,
    .qualityOption:disabled {
        opacity: 0.4;
        cursor: not-allowed;
        background: var(--surface-color);
    }

    .label {
        font-weight: bold;
        font-size: 12px;
        margin-bottom: 2px;
        display: flex;
        align-items: center;
        gap: 6px;
        color: var(--text-primary-color);
    }

    .badge {
        font-size: 9px;
        font-weight: normal;
        background: var(--secondary-color);
        color: var(--text-primary-color);
        padding: 2px 6px;
        border-radius: 3px;
    }

    .description {
        font-size: 10px;
        color: var(--text-secondary-color);
    }

    .note {
        font-size: 9px;
        color: var(--text-secondary-color);
        margin-top: 4px;
        font-style: italic;
    }
</style>
