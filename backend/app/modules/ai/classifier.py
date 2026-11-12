"""Plug-in point for the polymer classification model.

ReLoop does not ship a trained model. Your team's model (trained in a notebook) is connected here:

1. Save the trained model from the notebook to a file (for example `polymer_model.keras`, `.h5`, `.pt`,
   `.onnx` or `.pkl`) and put it anywhere on the backend machine.
2. Set the environment variable before starting the backend:
       Windows PowerShell:  $env:RELOOP_POLYMER_MODEL = "C:\\path\\to\\polymer_model.keras"
       macOS / Linux:       export RELOOP_POLYMER_MODEL=/path/to/polymer_model.keras
3. Fill in `load_model()` and `predict()` below with the loading and preprocessing code from the notebook
   (the same image size, normalisation and class order used in training).
4. Map every class label your model outputs to a ReLoop material code in `LABEL_TO_MATERIAL`.
5. Install the model's framework into the backend virtualenv (e.g. `pip install tensorflow pillow`).

Until all of this is done, `/ai/classify` answers 503 AI_MODEL_NOT_CONFIGURED. It never returns a made-up
prediction, so the app shows "AI detection is not connected" and the generator picks the material by hand.
"""

from __future__ import annotations

import os
import threading
from typing import Any, List, Optional, Tuple

#: Default model path if exists
_DEFAULT_PATH = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", "ml", "output", "plastic_classifier.keras")
)

#: Path to the trained model file. Unset means "no model connected".
MODEL_PATH: Optional[str] = os.getenv("RELOOP_POLYMER_MODEL") or (_DEFAULT_PATH if os.path.exists(_DEFAULT_PATH) else None)

#: Name stored with every prediction so results can be traced to a model version.
MODEL_VERSION: str = os.getenv("RELOOP_POLYMER_MODEL_VERSION") or (os.path.basename(MODEL_PATH) if MODEL_PATH else "mobilenetv2_reloop_v1")

#: Below this confidence the app asks the generator to choose manually instead of pre-filling.
LOW_CONFIDENCE: float = float(os.getenv("RELOOP_POLYMER_MIN_CONFIDENCE", "0.6"))

#: Your model's class labels → ReLoop material codes (see GET /materials: PET, HDPE, PVC, LDPE, PP, PS, OTHER, MLP).
#: Labels are matched case-insensitively. Labels missing here are reported as OTHER.
LABEL_TO_MATERIAL = {
    "pet": "PET",
    "hdpe": "HDPE",
    "pvc": "PVC",
    "ldpe": "LDPE",
    "pp": "PP",
    "ps": "PS",
    "other": "OTHER",
    "not_plastic": "OTHER",
    "mlp": "MLP",
}

CLASS_NAMES = ["PET", "HDPE", "PVC", "LDPE", "PP", "PS", "OTHER", "NOT_PLASTIC"]


class ModelNotConfigured(Exception):
    """No model file is configured, or load_model/predict have not been filled in yet."""


def load_model(path: str) -> Any:
    """Load the trained model from `path`."""
    import tensorflow as tf
    return tf.keras.models.load_model(path)


def predict(model: Any, image_bytes: bytes) -> List[Tuple[str, float]]:
    """Run the model on one image and return (label, probability) pairs for every class."""
    import io
    import numpy as np
    from PIL import Image

    img = Image.open(io.BytesIO(image_bytes)).convert("RGB").resize((224, 224))
    x = np.asarray(img, dtype="float32")[None]
    x = (x / 127.5) - 1.0  # MobileNetV2 normalisation
    probs = model.predict(x, verbose=0)[0]
    return list(zip(CLASS_NAMES, map(float, probs)))


_model: Any = None
_lock = threading.Lock()


def _get_model() -> Any:
    global _model
    if not MODEL_PATH:
        raise ModelNotConfigured("RELOOP_POLYMER_MODEL is not set, so no polymer model is connected.")
    if not os.path.exists(MODEL_PATH):
        raise ModelNotConfigured(f"Model file not found: {MODEL_PATH}")
    with _lock:
        if _model is None:
            _model = load_model(MODEL_PATH)
    return _model


def classify(image_bytes: bytes) -> List[Tuple[str, float]]:
    """Returns (material_code, probability) sorted by probability, highest first.

    Probabilities of labels that map to the same material are added together.
    Raises ModelNotConfigured when no model is connected.
    """
    model = _get_model()
    raw = predict(model, image_bytes)
    merged: dict[str, float] = {}
    for label, p in raw:
        code = LABEL_TO_MATERIAL.get(str(label).strip().lower(), "OTHER")
        merged[code] = merged.get(code, 0.0) + float(p)
    return sorted(merged.items(), key=lambda kv: kv[1], reverse=True)
