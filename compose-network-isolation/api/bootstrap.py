from __future__ import annotations

import logging
import time

import psycopg


class DatabaseBootstrap:
    def __init__(self, connection_string: str) -> None:
        self.connection_string = connection_string

    def wait_for_ready(
        self,
        host: str,
        port: int,
        timeout_seconds: int,
    ) -> bool:
        deadline = time.monotonic() + timeout_seconds
        delay = 1.0
        attempt = 1

        while time.monotonic() < deadline:
            try:
                with psycopg.connect(
                    self.connection_string,
                    connect_timeout=3,
                ):
                    logging.info(
                        "database ready host=%s port=%s attempt=%s",
                        host,
                        port,
                        attempt,
                    )
                    return True
            except psycopg.Error as error:
                logging.warning(
                    "database unavailable attempt=%s delay=%.1f error=%s",
                    attempt,
                    delay,
                    error,
                )

                time.sleep(delay)
                delay = min(delay * 2, 8.0)
                attempt += 1

        return False

    def apply_schema(self) -> None:
        with psycopg.connect(self.connection_string) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS items (
                        id BIGSERIAL PRIMARY KEY,
                        name VARCHAR(255) NOT NULL,
                        created_at TIMESTAMPTZ NOT NULL
                            DEFAULT CURRENT_TIMESTAMP
                    )
                    """
                )

            connection.commit()

    def seed_initial_data(self) -> int:
        with psycopg.connect(self.connection_string) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) FROM items")
                existing_count = cursor.fetchone()[0]

                if existing_count == 0:
                    cursor.execute(
                        """
                        INSERT INTO items (name)
                        VALUES (%s), (%s)
                        """,
                        (
                            "network-isolation",
                            "service-discovery",
                        ),
                    )

                    inserted = 2
                else:
                    inserted = 0

            connection.commit()
            return inserted
