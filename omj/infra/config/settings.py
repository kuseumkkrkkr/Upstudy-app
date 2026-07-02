"""Application settings.

Simple settings container backed by environment variables with sensible
defaults for the OMJ backend.
"""
import os


class Settings:
    """Settings singleton."""

    TEXTBOOK_DB_PATH: str = os.getenv("TEXTBOOK_DB_PATH", "textbook.db")
