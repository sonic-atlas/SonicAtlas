import sys, os
from datetime import datetime

COLORS = {
    "info": "\033[36m",
    "warn": "\033[33m",
    "error": "\033[31m",
    "debug": "\033[35m",
    "reset": "\033[0m"
}

class Logger:
    def __init__(self, *, timestamp=True, color=True):
        self.timestamp = timestamp
        self.color = color
    
    def _format(self, level: str, message: str) -> str:
        time_str = f"[{datetime.now().strftime('%H:%M:%S')}] " if self.timestamp else ""
        color = COLORS[level] if self.color else ""
        reset = COLORS['reset'] if self.color else ""

        indented = message.replace("\n", "\n    ")

        return f"{time_str}{color}[Transcoder] {level.upper()}:{reset} {indented}"
    
    def info(self, msg: str):
        print(self._format("info", msg))
    
    def warn(self, msg: str):
        print(self._format("warn", msg), file=sys.stderr)
    
    def error(self, msg: str):
        print(self._format("error", msg), file=sys.stderr)
    
    def debug(self, msg: str):
        if os.getenv("PYTHON_ENV") == "development" or os.getenv("NODE_ENV") == "development":
            print(self._format("debug", msg))

logger = Logger()