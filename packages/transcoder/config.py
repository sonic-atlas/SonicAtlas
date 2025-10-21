import os
from typing import Dict
from dotenv import load_dotenv
from pydantic import BaseModel

load_dotenv()

class TranscoderConfig(BaseModel):
    """Audio transcoding service configuration.
    
    Pulls settings from environment variables with sensible defaults.
    FFmpeg threads=0 auto-scales;
    """

    storage_path: str = os.getenv("storage_path", "storage/")
    ffmpeg_path: str = os.getenv("ffmpeg_path", "ffmpeg") # Path to ffmpeg binary; must be in PATH or absolute.

    ffmpeg_threads: int = int(os.getenv("ffmpeg_threads", "0"))  # 0 = auto / use all

    transcoder_port: int = 8000

    quality_tiers: Dict[str, Dict[str, str]] = {
        "efficiency": {"codec": "aac", "bitrate": "128k", "extension": "m4a", "mime": "audio/aac"},
        "high": {"codec": "aac", "bitrate": "320k", "extension": "m4a", "mime": "audio/aac"},
        "cd": {"codec": "flac", "compression": "5", "extension": "flac", "mime": "audio/flac", "sample_rate": "44100", "bit_depth_format": "s16"},
        "hires": {"codec": "flac", "compression": "5", "extension": "flac", "mime": "audio/flac"},
    }

    class Config:
        case_sensitive = True

config = TranscoderConfig()
