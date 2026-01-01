<script lang="ts">
    import '@material/web/select/outlined-select.js';
    import '@material/web/select/select-option.js';
    import type { Quality, TrackMetadata } from '$lib/types';
    import { apiGet } from '$lib/api';
    import { onMount } from 'svelte';

    interface Props {
        quality: Quality;
        metadata: TrackMetadata | null;
        trackId: string;
    }
    let { quality = $bindable(), trackId }: Props = $props();

    const qualities: { value: Quality; label: string; description: string }[] = [
        { value: 'auto', label: 'Auto', description: 'Adaptive Bitrate' },
        { value: 'efficiency', label: 'Efficiency', description: 'AAC 128k' },
        { value: 'high', label: 'High', description: 'AAC 320k' },
        { value: 'cd', label: 'CD Quality', description: 'FLAC 44.1kHz' },
        { value: 'hires', label: 'Hi-Res', description: 'FLAC Original' }
    ];

    let sourceQuality = $state<Quality>(quality);
    let availableQualities = $state<Quality[]>([]);
    let isFirefox = $state<boolean>(false);

    onMount(() => {
        isFirefox = navigator.userAgent.toLowerCase().includes('firefox');
    });

    async function loadAvailableQualities() {
        try {
            const res = await apiGet(`/api/stream/${trackId}/quality`);
            if (res.ok) {
                const data = await res.json();
                sourceQuality = data.sourceQuality || 'auto';
                availableQualities = data.availableQualities || [];
            }
        } catch (err) {
            console.error('Failed to load quality info:', err);
            availableQualities = ['efficiency', 'high', 'cd', 'hires'];
        }
    }

    $effect(() => {
        if (trackId) {
            loadAvailableQualities().then(() => {
                if (quality !== 'auto' && !availableQualities.includes(quality)) {
                    quality = 'auto';
                }
                if (isFirefox && quality === 'hires') {
                    quality = 'cd';
                }
            });
        }
    });

    function isQualityAvailable(q: Quality): boolean {
        if (isFirefox && q === 'hires') {
            return false;
        }
        if (q === 'auto') {
            return availableQualities.length > 0;
        }
        return availableQualities.includes(q);
    }
</script>

<div class="qualitySelector">
    {#if isFirefox}
        <div class="firefoxNotice">
            Hi-Res streaming is not fully supported on Firefox and is disabled.
        </div>
    {/if}

    <md-outlined-select
        label="Playback Quality"
        class="qualityDropdown"
        value={quality}
        onchange={(e: Event) => {
            const target = e.target as HTMLSelectElement;
            quality = target.value as Quality;
        }}
    >
        {#each qualities as q (q.value)}
            {@const available = isQualityAvailable(q.value)}
            <md-select-option value={q.value} disabled={!available}>
                <div slot="headline">
                    {q.label}
                    {#if q.value === sourceQuality}
                        <span class="sourceBadge">Source</span>
                    {/if}
                </div>
            </md-select-option>
        {/each}
    </md-outlined-select>
</div>

<style>
    .qualitySelector {
        margin-bottom: 20px;
    }

    .qualityDropdown {
        width: 100%;
        --md-menu-item-selected-container-color: var(--primary-color);
        --md-menu-item-selected-label-text-color: var(--on-primary-color);
        --md-sys-color-secondary-container: var(--primary-color);
        --md-sys-color-on-secondary-container: var(--on-primary-color);
    }

    .firefoxNotice {
        font-size: 12px;
        background-color: var(--surface-base);
        border: 1px solid var(--error-color);
        color: var(--error-color);
        padding: 10px;
        border-radius: 4px;
        margin-bottom: 10px;
        text-align: center;
    }

    .sourceBadge {
        font-size: 10px;
        background-color: var(--secondary-color);
        color: var(--on-secondary-color);
        padding: 2px 6px;
        border-radius: 4px;
        margin-left: 8px;
        vertical-align: middle;
    }
</style>
