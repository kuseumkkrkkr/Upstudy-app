"""Auth routes package.

Exports:
- require_role: FastAPI dependency factory for JWT + RBAC.
"""
from .middleware import require_role

__all__ = ["require_role"]
