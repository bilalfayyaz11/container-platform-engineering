from __future__ import annotations

from typing import Any

import psycopg
from psycopg.rows import dict_row


class ItemStore:
    def __init__(self, connection_string: str) -> None:
        self.connection_string = connection_string

    def list_items(self) -> list[dict[str, Any]]:
        with psycopg.connect(
            self.connection_string,
            row_factory=dict_row,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT id, name, created_at
                    FROM items
                    ORDER BY id
                    """
                )

                return [
                    {
                        "id": row["id"],
                        "name": row["name"],
                        "created_at": row["created_at"].isoformat(),
                    }
                    for row in cursor.fetchall()
                ]

    def create_item(self, name: str) -> dict[str, Any]:
        with psycopg.connect(
            self.connection_string,
            row_factory=dict_row,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO items (name)
                    VALUES (%s)
                    RETURNING id, name, created_at
                    """,
                    (name,),
                )

                row = cursor.fetchone()

            connection.commit()

        return {
            "id": row["id"],
            "name": row["name"],
            "created_at": row["created_at"].isoformat(),
        }
