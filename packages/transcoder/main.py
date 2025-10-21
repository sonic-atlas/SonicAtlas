from typing import Dict

from fastapi import FastAPI, HTTPException

from .config import config
from .utils import (
    TranscodeRequest,
    TranscodeJob,
    transcode_to_cache
)

app = FastAPI(
    title="SonicAtlas Transcoder Service",
    description="Python + FastAPI service for GPU-accelerated FFmpeg transcoding.",
    version="1.0.0"
)

@app.post("/transcode/{track_id}")
async def start_transcode(track_id: str, request: TranscodeRequest) -> Dict[str, str]:
    """Queue transcode to cache and return cache path.
    
    Validates quality tier exists, spawns async transcode job.
    Returns cache file path (caller is responsible for reading/streaming from disk).
    """

    if request.quality not in config.quality_tiers:
        raise HTTPException(
            status_code=400,
            detail={"error": "BAD_REQUEST", "message": f"Invalid quality tier: {request.quality}"}
        )

    job = TranscodeJob(
        track_id=track_id,
        quality=request.quality
    )

    try:
        result = await transcode_to_cache(job)
        return {
            "message": "Transcoding completed successfully and cached.",
            "cache_path": result["cached_file_path"],
            "quality": job.quality
        }
    except RuntimeError as e:
        raise HTTPException(
            status_code=500,
            detail={"error": "TRANSCODE_001", "message": f"Transcoding failed. {e}"}
        )
    
@app.get("/health")
def health_check() -> Dict[str, str]:
    """
    Check health of the transcoder. If it's on it returns that it's ok. 
    If not it doesn't because it's off dumbass
    """
    return {"status": "ok"}

if __name__ == "__main__":
    """Run the FastAPI app with Uvicorn to localhost and the configured port."""
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=config.transcoder_port)