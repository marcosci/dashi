"""Trust + parse Authelia forward-auth headers. In dev (mock_user set), bypass."""

from __future__ import annotations

from dataclasses import dataclass

from fastapi import Header, HTTPException, status

from .settings import settings


@dataclass(frozen=True)
class Principal:
    user: str
    groups: tuple[str, ...]

    def in_group(self, name: str) -> bool:
        return name in self.groups


def current_user(
    x_remote_user: str | None = Header(default=None),
    x_remote_groups: str | None = Header(default=None),
    remote_user: str | None = Header(default=None, alias="Remote-User"),
    remote_groups: str | None = Header(default=None, alias="Remote-Groups"),
) -> Principal:
    """FastAPI dependency. Returns the authenticated principal or 401.

    Header order of precedence:
      1. mock (env var, dev only)
      2. Remote-User / Remote-Groups (Authelia forward-auth)
      3. X-Remote-User / X-Remote-Groups (oauth2-proxy style)
    """
    if settings.mock_user:
        groups = tuple(g.strip() for g in settings.mock_groups.split(",") if g.strip())
        return Principal(user=settings.mock_user, groups=groups)

    user = remote_user or x_remote_user
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="no Remote-User header — request must come through the ingress",
        )

    raw = remote_groups or x_remote_groups or ""
    groups = tuple(g.strip() for g in raw.split(",") if g.strip())
    return Principal(user=user, groups=groups)
