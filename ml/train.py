"""
ReLoop Plastic Waste Classification Model Training Pipeline
============================================================
Trains a MobileNetV2-based classifier on real plastic waste images
and exports a TFLite model for on-device mobile inference.

Classes: PET, HDPE, PVC, LDPE, PP, PS, OTHER, NOT_PLASTIC
"""

import os
import shutil
import pathlib
import numpy as np

os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.callbacks import (
    EarlyStopping,
    ReduceLROnPlateau,
    ModelCheckpoint,
)

# ── CONFIG ────────────────────────────────────────────────
IMG_SIZE = 224
BATCH_SIZE = 16
EPOCHS = 30
SEED = 42
BASE_DIR = pathlib.Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
MERGED_DIR = DATA_DIR / "merged"
OUTPUT_DIR = BASE_DIR / "output"

# Target class names (aligned with ReLoop PolymerType codes)
CLASS_NAMES = [
    "PET",       # 1 – Polyethylene terephthalate
    "HDPE",      # 2 – High-density polyethylene
    "PVC",       # 3 – Polyvinyl chloride
    "LDPE",      # 4 – Low-density polyethylene
    "PP",        # 5 – Polypropylene
    "PS",        # 6 – Polystyrene
    "OTHER",     # 7 – Other resins
    "NOT_PLASTIC"  # 8 – Not plastic (negative class)
]


def merge_datasets():
    """Merge both Kaggle datasets into a unified folder structure."""
    print("=" * 60)
    print("Step 1/5: Merging datasets into unified class folders...")
    print("=" * 60)

    MERGED_DIR.mkdir(parents=True, exist_ok=True)
    for cls in CLASS_NAMES:
        (MERGED_DIR / cls).mkdir(exist_ok=True)

    # Mapping from source dataset 1 (seven_plastics)
    src1 = DATA_DIR / "seven_plastics"
    src1_mapping = {
        "1_polyethylene_PET": "PET",
        "2_high_density_polyethylene_PE-HD": "HDPE",
        "3_polyvinylchloride_PVC": "PVC",
        "4_low_density_polyethylene_PE-LD": "LDPE",
        "5_polypropylene_PP": "PP",
        "6_polystyrene_PS": "PS",
        "7_other_resins": "OTHER",
        "8_no_plastic": "NOT_PLASTIC",
    }

    count = 0
    for src_folder, target_class in src1_mapping.items():
        src_path = src1 / src_folder
        if src_path.exists():
            for img in src_path.iterdir():
                if img.suffix.lower() in (".jpg", ".jpeg", ".png", ".bmp", ".webp"):
                    dest = MERGED_DIR / target_class / f"ds1_{img.name}"
                    if not dest.exists():
                        shutil.copy2(img, dest)
                        count += 1
    print(f"  Dataset 1 (Recycling Codes): {count} images copied")

    # Mapping from source dataset 2 (extra)
    src2 = DATA_DIR / "extra"
    src2_mapping = {
        "PET": "PET",
        "HDPE": "HDPE",
        "LDPA": "LDPE",  # Typo in dataset name
        "PP": "PP",
    }

    count2 = 0
    for src_folder, target_class in src2_mapping.items():
        src_path = src2 / src_folder
        if src_path.exists():
            for img in src_path.iterdir():
                if img.suffix.lower() in (".jpg", ".jpeg", ".png", ".bmp", ".webp"):
                    dest = MERGED_DIR / target_class / f"ds2_{img.name}"
                    if not dest.exists():
                        shutil.copy2(img, dest)
                        count2 += 1
    print(f"  Dataset 2 (Plastic Types):   {count2} images copied")

    # Print class distribution
    print("\n  Class Distribution:")
    total = 0
    for cls in CLASS_NAMES:
        n = len(list((MERGED_DIR / cls).iterdir()))
        total += n
        bar = "█" * (n // 5) + "░" * max(0, 50 - n // 5)
        print(f"    {cls:<12} {bar} {n:>4}")
    print(f"    {'TOTAL':<12} {'':>50} {total:>4}")
    return total


def build_datasets():
    """Create train/validation datasets with augmentation."""
    print("\n" + "=" * 60)
    print("Step 2/5: Building train/validation datasets...")
    print("=" * 60)

    train_ds = keras.utils.image_dataset_from_directory(
        MERGED_DIR,
        labels="inferred",
        label_mode="categorical",
        class_names=CLASS_NAMES,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        validation_split=0.2,
        subset="training",
        seed=SEED,
    )

    val_ds = keras.utils.image_dataset_from_directory(
        MERGED_DIR,
        labels="inferred",
        label_mode="categorical",
        class_names=CLASS_NAMES,
        image_size=(IMG_SIZE, IMG_SIZE),
        batch_size=BATCH_SIZE,
        validation_split=0.2,
        subset="validation",
        seed=SEED,
    )

    # Compute class weights for imbalanced dataset
    class_counts = []
    for cls in CLASS_NAMES:
        class_counts.append(len(list((MERGED_DIR / cls).iterdir())))
    class_counts = np.array(class_counts, dtype=np.float32)
    total = class_counts.sum()
    n_classes = len(CLASS_NAMES)
    class_weights = {}
    for i, c in enumerate(class_counts):
        class_weights[i] = total / (n_classes * max(c, 1))
    print(f"  Class weights: {class_weights}")

    # Data augmentation pipeline
    data_augmentation = keras.Sequential([
        layers.RandomFlip("horizontal_and_vertical"),
        layers.RandomRotation(0.3),
        layers.RandomZoom(0.2),
        layers.RandomBrightness(0.2),
        layers.RandomContrast(0.2),
    ], name="data_augmentation")

    # Optimise I/O
    AUTOTUNE = tf.data.AUTOTUNE
    train_ds = train_ds.map(
        lambda x, y: (data_augmentation(x, training=True), y),
        num_parallel_calls=AUTOTUNE,
    ).prefetch(AUTOTUNE)
    val_ds = val_ds.prefetch(AUTOTUNE)

    print(f"  Train batches: {tf.data.experimental.cardinality(train_ds).numpy()}")
    print(f"  Val batches:   {tf.data.experimental.cardinality(val_ds).numpy()}")

    return train_ds, val_ds, class_weights


def build_model():
    """Build MobileNetV2 transfer learning model."""
    print("\n" + "=" * 60)
    print("Step 3/5: Building MobileNetV2 model...")
    print("=" * 60)

    # MobileNetV2 preprocessing: pixel values scaled to [-1, 1]
    preprocess_input = keras.applications.mobilenet_v2.preprocess_input

    base_model = MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )

    # Freeze base model for transfer learning
    base_model.trainable = False

    inputs = keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3))
    x = preprocess_input(inputs)
    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(128, activation="relu")(x)
    x = layers.Dropout(0.2)(x)
    outputs = layers.Dense(len(CLASS_NAMES), activation="softmax")(x)

    model = keras.Model(inputs, outputs)

    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=1e-3),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )

    model.summary()
    return model, base_model


def train_model(model, base_model, train_ds, val_ds, class_weights):
    """Two-phase training: frozen base → fine-tune top layers."""
    print("\n" + "=" * 60)
    print("Step 4/5: Training model...")
    print("=" * 60)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    callbacks = [
        EarlyStopping(patience=5, restore_best_weights=True, verbose=1),
        ReduceLROnPlateau(factor=0.5, patience=3, verbose=1),
        ModelCheckpoint(
            str(OUTPUT_DIR / "best_model.keras"),
            save_best_only=True,
            verbose=1,
        ),
    ]

    # Phase 1: Train top layers only
    print("\n  ── Phase 1: Training classification head (base frozen) ──")
    history1 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=15,
        class_weight=class_weights,
        callbacks=callbacks,
        verbose=1,
    )

    # Phase 2: Fine-tune top layers of MobileNetV2
    print("\n  ── Phase 2: Fine-tuning top 30 layers of MobileNetV2 ──")
    base_model.trainable = True
    for layer in base_model.layers[:-30]:
        layer.trainable = False

    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=1e-4),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )

    history2 = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=EPOCHS,
        initial_epoch=len(history1.history["loss"]),
        class_weight=class_weights,
        callbacks=callbacks,
        verbose=1,
    )

    # Evaluate
    val_loss, val_acc = model.evaluate(val_ds, verbose=0)
    print(f"\n  ✓ Final Validation Accuracy: {val_acc:.4f}")
    print(f"  ✓ Final Validation Loss:     {val_loss:.4f}")

    return model


def export_tflite(model):
    """Convert trained model to optimized TFLite format."""
    print("\n" + "=" * 60)
    print("Step 5/5: Exporting to TFLite for on-device inference...")
    print("=" * 60)

    # Standard Float16 quantization (best accuracy/size tradeoff for mobile)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]

    tflite_model = converter.convert()

    tflite_path = OUTPUT_DIR / "plastic_classifier.tflite"
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)

    size_mb = tflite_path.stat().st_size / (1024 * 1024)
    print(f"  ✓ TFLite model saved: {tflite_path}")
    print(f"  ✓ Model size: {size_mb:.2f} MB")

    # Save labels file for the Flutter app
    labels_path = OUTPUT_DIR / "labels.txt"
    with open(labels_path, "w") as f:
        for name in CLASS_NAMES:
            f.write(name + "\n")
    print(f"  ✓ Labels file saved: {labels_path}")

    # Also save the full Keras model
    model.save(OUTPUT_DIR / "plastic_classifier.keras")
    print(f"  ✓ Keras model saved: {OUTPUT_DIR / 'plastic_classifier.keras'}")

    return tflite_path


def main():
    print("╔" + "═" * 58 + "╗")
    print("║   ReLoop Plastic Waste Classification – Training Pipeline  ║")
    print("╚" + "═" * 58 + "╝")
    print()

    total = merge_datasets()
    if total == 0:
        print("ERROR: No images found. Check the dataset paths.")
        return

    train_ds, val_ds, class_weights = build_datasets()
    model, base_model = build_model()
    model = train_model(model, base_model, train_ds, val_ds, class_weights)
    tflite_path = export_tflite(model)

    print("\n" + "═" * 60)
    print("  TRAINING COMPLETE!")
    print(f"  TFLite model: {tflite_path}")
    print(f"  Copy to: mobile/assets/models/plastic_classifier.tflite")
    print("═" * 60)


if __name__ == "__main__":
    main()
