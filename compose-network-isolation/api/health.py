from __future__ import annotations

import psycopg

from cache import CacheLayer


class HealthChecker:
    def __init__(
        self,
        connection_string: str,
        cache: CacheLayer,
    ) -> None:
        self.connection_string = connection_string
        self.cache = cache

    def check_database(self) -> bool:
        try:
            with psycopg.connect(
                self.connection_string,
                connect_timeout=3,
            ) as connection:
                with connection.cursor() as cursor:
                    cursor.execute("SELECT 1")
                    cursor.fetchone()

            return True
        except psycopg.Error:
            return False

    def check_cache(self) -> bool:
        try:
            return self.cache.ping()
        except Exception:
            return False

    def report(self) -> dict[str, str]:
        database_ok = self.check_database()
        cache_ok = self.check_cache()

        return {
            "status": "ok" if database_ok and cache_ok else "degraded",
            "db": "ok" if database_ok else "unavailable",
            "cache": "ok" if cache_ok else "unavailable",
        }
