"""
Offline-only question adapter.

The upstream implementation falls back to live requests if local StackOverflow
helpers are unavailable. This local deployment deliberately blocks that path.
"""

# pylint: disable=relative-import

from .adapter import Adapter

OFFLINE_MESSAGE = """Offline-only deployment

Free-form programming language questions are disabled in this local service.
Only mirrored repositories are available offline.

Try one of these instead:

    /python/:list
    /python/:learn
    /tar
    /:list
"""


class Question(Adapter):
    """
    Return a deterministic local-only message instead of attempting upstream
    StackOverflow queries.
    """

    _adapter_name = "question"
    _output_format = "text"
    _cache_needed = False

    def _get_page(self, topic, request_options=None):
        return {"cache": False, "answer": OFFLINE_MESSAGE}

    def _get_list(self, prefix=None):
        return []

    def is_found(self, topic):
        return True
