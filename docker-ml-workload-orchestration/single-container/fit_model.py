#!/usr/bin/env python3

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
from sklearn.datasets import load_breast_cancer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, log_loss
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


def get_int_env(name: str, default: int) -> int:
    value = os.getenv(name, str(default))

    try:
        return int(value)
    except ValueError as exc:
        raise ValueError(f"{name} must be an integer, received: {value}") from exc


def get_float_env(name: str, default: float) -> float:
    value = os.getenv(name, str(default))

    try:
        return float(value)
    except ValueError as exc:
        raise ValueError(f"{name} must be numeric, received: {value}") from exc


def main() -> int:
    output_dir = Path(os.getenv("OUTPUT_DIR", "/app/output"))
    random_seed = get_int_env("RANDOM_SEED", 42)
    max_iterations = get_int_env("MAX_ITERATIONS", 500)
    regularization = get_float_env("REGULARIZATION_C", 1.0)
    test_size = get_float_env("TEST_SIZE", 0.2)

    if not 0 < test_size < 1:
        raise ValueError("TEST_SIZE must be between 0 and 1.")

    if max_iterations < 1:
        raise ValueError("MAX_ITERATIONS must be greater than zero.")

    if regularization <= 0:
        raise ValueError("REGULARIZATION_C must be greater than zero.")

    output_dir.mkdir(parents=True, exist_ok=True)

    dataset = load_breast_cancer()

    x_train, x_test, y_train, y_test = train_test_split(
        dataset.data,
        dataset.target,
        test_size=test_size,
        random_state=random_seed,
        stratify=dataset.target,
    )

    model = Pipeline(
        steps=[
            ("scaler", StandardScaler()),
            (
                "classifier",
                LogisticRegression(
                    C=regularization,
                    max_iter=max_iterations,
                    random_state=random_seed,
                    solver="liblinear",
                ),
            ),
        ]
    )

    model.fit(x_train, y_train)

    predictions = model.predict(x_test)
    probabilities = model.predict_proba(x_test)

    accuracy = accuracy_score(y_test, predictions)
    loss = log_loss(y_test, probabilities)

    model_path = output_dir / "breast-cancer-classifier.joblib"
    metrics_path = output_dir / "metrics.json"

    joblib.dump(model, model_path)

    metrics = {
        "accuracy": round(float(accuracy), 6),
        "loss": round(float(loss), 6),
        "epochs_run": 1,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "random_seed": random_seed,
        "max_iterations": max_iterations,
        "regularization_c": regularization,
        "test_size": test_size,
        "training_samples": int(len(x_train)),
        "test_samples": int(len(x_test)),
        "model_file": model_path.name,
    }

    metrics_path.write_text(
        json.dumps(metrics, indent=2) + "\n",
        encoding="utf-8",
    )

    print(json.dumps(metrics, indent=2))
    print(f"Model written to: {model_path}")
    print(f"Metrics written to: {metrics_path}")

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(f"Training failed: {error}", file=sys.stderr)
        sys.exit(1)
