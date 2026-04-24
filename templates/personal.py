"""
Adapter for the tracked personal cheat sheets stored in this repository.
"""

# pylint: disable=relative-import,abstract-method

from .git_adapter import RepositoryAdapter


class Personal(RepositoryAdapter):
    """
    Local flat-file cheat-sheet adapter for curated personal notes.
    """

    _adapter_name = "personal"
    _output_format = "text+code"
    _cache_needed = False
    _local_repository_location = "/app/personal"
    _cheatsheet_files_prefix = ""
