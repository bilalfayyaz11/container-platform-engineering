#!/usr/bin/env python3

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
from sklearn.datasets import make_classification
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler


DATA_DIR = Path("/pipeline/data")
DATA_FILE = DATA_DIR / "prepared-dataset.joblib"
METADATA_FILE = DATA_DIR / "dataset-metadata.json"
READY_FILE = DATA_DIR / ".ready"


def main() -> int:
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    features, labels = make_classification(
        n_samples=2000,
        n_features=20,
        n_informative=12,
        n_redundant=4,
        n_classes=2,
        class_sep=1.2,
        random_state=42,
    )

    x_train, x_test, y_train, y_test = train_test_split(
        features,
        labels,
        test_size=0.2,
        random_state=42,
        stratify=labels,
    )

    scaler = StandardScaler()
    x_train_scaled = scaler.fit_transform(x_train)
    x_test_scaled = scaler.transform(x_test)

    payload = {
        "x_train": x_train_scaled,
        "x_test": x_test_scaled,
        "y_train": y_train,
        "y_test": y_test,
        "scaler": scaler,
    }

    joblib.dump(payload, DATA_FILE)

    metadata = {
        "data_source": DATA_FILE.name,
        "training_samples": int(len(x_train_scaled)),
        "test_samples": int(len(x_test_scaled)),
        "features": int(x_train_scaled.shape[1]),
        "random_seed": 42,
        "prepared_at": datetime.now(timezone.utc).isoformat(),
    }

    METADATA_FILE.write_text(
        json.dumps(metadata, indent=2) + "\n",
        encoding="utf-8",
    )

    READY_FILE.write_text("ready\n", encoding="utf-8")

    print(json.dumps(metadata, indent=2))
    print(f"Prepared dataset: {DATA_FILE}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"Data preparation failed: {error}", file=sys.stderr)
        sys.exit(1)
