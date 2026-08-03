#!/usr/bin/env python3

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, log_loss


DATA_DIR = Path("/pipeline/data")
RESULTS_DIR = Path("/pipeline/results")
DATA_FILE = DATA_DIR / "prepared-dataset.joblib"
METADATA_FILE = DATA_DIR / "dataset-metadata.json"
RESULTS_FILE = RESULTS_DIR / "results.json"
MODEL_FILE = RESULTS_DIR / "distributed-classifier.joblib"


def main() -> int:
    random_seed = int(os.getenv("RANDOM_SEED", "42"))
    max_iterations = int(os.getenv("MAX_ITERATIONS", "500"))

    if not DATA_FILE.is_file():
        raise FileNotFoundError(
            f"Required preprocessed dataset is missing: {DATA_FILE}"
        )

    if not METADATA_FILE.is_file():
        raise FileNotFoundError(
            f"Required dataset metadata is missing: {METADATA_FILE}"
        )

    payload = joblib.load(DATA_FILE)
    metadata = json.loads(
        METADATA_FILE.read_text(encoding="utf-8")
    )

    model = LogisticRegression(
        max_iter=max_iterations,
        random_state=random_seed,
        solver="liblinear",
    )

    model.fit(payload["x_train"], payload["y_train"])

    predictions = model.predict(payload["x_test"])
    probabilities = model.predict_proba(payload["x_test"])

    accuracy = accuracy_score(payload["y_test"], predictions)
    loss = log_loss(payload["y_test"], probabilities)

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, MODEL_FILE)

    results = {
        "model_accuracy": round(float(accuracy), 6),
        "loss": round(float(loss), 6),
        "data_source": metadata["data_source"],
        "training_samples": metadata["training_samples"],
        "test_samples": metadata["test_samples"],
        "random_seed": random_seed,
        "completed_at": datetime.now(timezone.utc).isoformat(),
        "model_file": MODEL_FILE.name,
    }

    RESULTS_FILE.write_text(
        json.dumps(results, indent=2) + "\n",
        encoding="utf-8",
    )

    print(json.dumps(results, indent=2))
    print(f"Results written to: {RESULTS_FILE}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"Training worker failed: {error}", file=sys.stderr)
        sys.exit(1)
