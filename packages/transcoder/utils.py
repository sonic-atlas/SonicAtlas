import asyncio

from typing import Dict, List
from pathlib import Path

from pydantic import BaseModel, Field

from .config import config
from .logger import logger

class TranscodeRequest(BaseModel):
    """Request body for a transcode operation."""
    quality: str = Field(..., description="Target quality tier ('efficiency'|'high'|'cd'|'hires').")
    
class TranscodeJob(BaseModel):
    """Single transcode request parameters.

    track_id: maps to storage_path/originals/{track_id}.flac.
    quality: One of config.quality_tiers keys.
    """
    track_id: str
    quality: str

cache_dir = "cache"


def get_ffmpeg_command(job: TranscodeJob, quality_config: Dict[str, str], output_filepath: Path) -> List[str]:
    """Build FFmpeg command-line arguments.
    
    Conditionally applies codec, bitrate, compression, sample rate, bit depth based on quality config.
    Always disables video for covers (-vn) and interactive input (-nostdin).
    """
    
    input_file = Path(config.storage_path) / "originals" / f"{job.track_id}.flac"
    
    command = [
        config.ffmpeg_path,
        '-y',
        '-nostdin',
        '-i', str(input_file),
        '-vn',
    ]

    command.extend(['-threads', str(config.ffmpeg_threads)])

    codec = quality_config.get("codec")
    bitrate = quality_config.get("bitrate")
    compression = quality_config.get("compression")
    sample_rate = quality_config.get("sample_rate")
    bit_depth_format = quality_config.get("bit_depth_format")

    if codec:
        command.extend(['-c:a', codec])
    if bitrate:
        command.extend(['-b:a', bitrate])
    if compression:
        command.extend(['-compression_level', compression])
    if sample_rate:
        command.extend(['-ar', sample_rate])
    if bit_depth_format:
        command.extend(['-sample_fmt', bit_depth_format])
    
    format_type = quality_config.get("format")
    if format_type:
        command.append('-f')
        command.append(format_type)

    command.append(str(output_filepath))

    return command

async def transcode_to_cache(job: TranscodeJob) -> Dict[str, str]:
    """Transcode input to cache folder based on job parameters.
    
    Returns early if cache hit (exists + size > 0).
    """
    quality_config = config.quality_tiers.get(job.quality)
    if not quality_config:
        raise ValueError(f"Unknown quality tier: {job.quality}")

    cache_path_root = Path(config.storage_path) / "cache"
    cache_path_root.mkdir(parents=True, exist_ok=True)
    
    output_filename = f"{job.track_id}_{job.quality}.{quality_config['extension']}"
    output_filepath = cache_path_root / output_filename

    try:
        if output_filepath.exists() and output_filepath.stat().st_size > 0:
            logger.info(f"Cache hit for {output_filepath}, skipping transcode.")
            return {
                "status": "completed",
                "cached_file_path": str(output_filepath.relative_to(config.storage_path)),
                "full_path": str(output_filepath)
            }
        elif output_filepath.exists() and output_filepath.stat().st_size == 0:
            return {
                "status": "failed",
                "error": "Cached file exists but is empty, a transcode may be in progress."
            }
    except Exception:
        pass

    ffmpeg_command = get_ffmpeg_command(job, quality_config, output_filepath)
    logger.debug(f"Executing FFmpeg command: {' '.join(ffmpeg_command)}")

    process = await asyncio.create_subprocess_exec(
        *ffmpeg_command,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )

    _, stderr = await process.communicate()

    if process.returncode != 0:
        decoded_output = (stderr or b"").decode('utf-8', errors='ignore')
        logger.error(f"FFmpeg failed with exit code {process.returncode}:\n{decoded_output}")
        raise RuntimeError(f"Transcoding failed. FFmpeg output:\n{decoded_output}")

    result = {
        "status": "completed",
        "cached_file_path": str(output_filepath.relative_to(config.storage_path)),
        "full_path": str(output_filepath)
    }
    return result

