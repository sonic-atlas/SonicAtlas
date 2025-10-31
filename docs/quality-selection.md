# Quality Selection & Upsampling Prevention

## Backend Implementation

The backend now prevents upsampling by automatically downgrading requested quality to match the source file's capabilities.

### Quality Hierarchy

```
efficiency (128k AAC) < high (320k AAC) < cd (16-bit FLAC) < hires (24-bit FLAC)
```

### Source Quality Detection

The backend determines source quality based on:

**FLAC files:**
- `hires`: 24-bit depth OR sample rate > 48kHz
- `cd`: 16-bit, 44.1kHz (standard CD quality)

**Lossy formats (MP3/AAC):**
- `high`: 256kbps or higher
- `efficiency`: below 256kbps

### API Endpoints

#### Get Available Qualities
```http
GET /api/stream/:trackId/quality
Authorization: Bearer <token>
```

Response:
```json
{
  "sourceQuality": "cd",
  "availableQualities": ["efficiency", "high", "cd"],
  "track": {
    "format": "flac",
    "sampleRate": 44100,
    "bitDepth": 16
  }
}
```

#### Stream with Quality
```http
GET /api/stream/:trackId?quality=high&token=<token>
```

- If requested quality exceeds source quality, it's automatically downgraded
- Backend logs the downgrade for monitoring
- No error is returned - it silently serves the best available quality

### Frontend Integration

**Fetch available qualities when loading track metadata:**

```typescript
const response = await apiGet(`/api/stream/${trackId}/quality`);
const { sourceQuality, availableQualities } = await response.json();
```

**Disable quality options that exceed source:**

```typescript
const qualities = [
  { value: 'efficiency', label: 'Efficiency', disabled: false },
  { value: 'high', label: 'High', disabled: false },
  { value: 'cd', label: 'CD Quality', disabled: !availableQualities.includes('cd') },
  { value: 'hires', label: 'Hi-Res', disabled: !availableQualities.includes('hires') }
];
```

**Show source quality badge:**

```typescript
{#if sourceQuality}
  <div class="source-badge">
    Source: {sourceQuality.toUpperCase()}
  </div>
{/if}
```

### Benefits

1. **No Wasted Bandwidth**: Users can't accidentally stream upsampled files
2. **Better UX**: Disabled options show what the source supports
3. **Transparent**: Users know the file's actual quality
4. **Automatic**: Backend handles downgrading if frontend somehow requests too high
5. **Future-Proof**: Supports hi-res files when uploaded

### Example Scenarios

**16-bit FLAC upload:**
- Source: `cd`
- Available: `efficiency`, `high`, `cd`
- Disabled: `hires`
- Requesting `hires` → automatically serves `cd`

**MP3 320kbps upload:**
- Source: `high`
- Available: `efficiency`, `high`
- Disabled: `cd`, `hires`
- Requesting `cd` → automatically serves `high`

**24-bit/96kHz FLAC upload:**
- Source: `hires`
- Available: `efficiency`, `high`, `cd`, `hires`
- Disabled: none
- All qualities available ✓
