from __future__ import annotations

import redis


class CacheLayer:
    def __init__(
        self,
        host: str,
        port: int,
        password: str,
    ) -> None:
        self.client = redis.Redis(
            host=host,
            port=port,
            password=password,
            decode_responses=True,
            socket_connect_timeout=3,
            socket_timeout=3,
        )

    def get(self, key: str) -> str | None:
        return self.client.get(key)

    def set(
        self,
        key: str,
        value: str,
        ttl_seconds: int,
    ) -> None:
        self.client.setex(
            key,
            ttl_seconds,
            value,
        )

    def invalidate(self, key: str) -> None:
        self.client.delete(key)

    def ping(self) -> bool:
        return bool(self.client.ping())
