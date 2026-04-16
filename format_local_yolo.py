import os
import json
import glob
import random
import shutil

# --- Configuration ---
SOURCE_DIR = "./all_labeled_crops"  # Make sure all your JPGs and JSONs are in here
OUTPUT_DIR = "./dataset_stage2"
SPLIT_RATIO = 0.8  # 80% Training, 20% Validation

# The Option B Mapping: Just wheels and macro-joints
CLASS_MAP = {
    "wheel": 0,
    "joint": 1
}


def setup_dirs():
    print("Building YOLO directory structure...")
    folders = [
        f"{OUTPUT_DIR}/images/train", f"{OUTPUT_DIR}/images/val",
        f"{OUTPUT_DIR}/labels/train", f"{OUTPUT_DIR}/labels/val"
    ]
    for f in folders:
        os.makedirs(f, exist_ok=True)


def convert_anylabeling_to_yolo():
    setup_dirs()

    json_files = glob.glob(os.path.join(SOURCE_DIR, "*.json"))
    valid_data = []

    print(f"Found {len(json_files)} annotated JSON files. Converting formats...")

    for json_path in json_files:
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)

            img_w = data['imageWidth']
            img_h = data['imageHeight']
            img_name = data['imagePath']
            img_path = os.path.join(SOURCE_DIR, img_name)

            # Skip if the image wasn't moved over correctly
            if not os.path.exists(img_path):
                continue

            yolo_lines = []
            for shape in data['shapes']:
                label = shape['label'].lower()
                if label not in CLASS_MAP:
                    continue

                class_id = CLASS_MAP[label]
                points = shape['points']

                # AnyLabeling uses [[x1, y1], [x2, y2]]
                x1, y1 = points[0]
                x2, y2 = points[1]

                xmin, xmax = min(x1, x2), max(x1, x2)
                ymin, ymax = min(y1, y2), max(y1, y2)

                # Convert to YOLO format: center_x, center_y, width, height (normalized 0-1)
                w = xmax - xmin
                h = ymax - ymin
                cx = xmin + (w / 2)
                cy = ymin + (h / 2)

                yolo_lines.append(f"{class_id} {cx / img_w:.6f} {cy / img_h:.6f} {w / img_w:.6f} {h / img_h:.6f}")

            if yolo_lines:
                valid_data.append((img_path, yolo_lines))

        except Exception as e:
            print(f"Error processing {json_path}: {e}")
            continue

    if not valid_data:
        print("ERROR: No valid labels found. Did you name them 'wheel' and 'joint'?")
        return

    # Shuffle for a healthy distribution
    random.shuffle(valid_data)
    split_idx = int(len(valid_data) * SPLIT_RATIO)

    def process_split(split_data, split_name):
        for img_p, lines in split_data:
            base_name = os.path.splitext(os.path.basename(img_p))[0]
            shutil.copy2(img_p, f"{OUTPUT_DIR}/images/{split_name}/{base_name}.jpg")
            with open(f"{OUTPUT_DIR}/labels/{split_name}/{base_name}.txt", 'w') as f:
                f.write('\n'.join(lines))

    print(f"Routing {split_idx} images to Training...")
    process_split(valid_data[:split_idx], "train")

    print(f"Routing {len(valid_data) - split_idx} images to Validation...")
    process_split(valid_data[split_idx:], "val")

    # Bundle it up for the cloud
    print(f"\nZipping everything into ready_for_runpod.zip...")
    shutil.make_archive("ready_for_runpod", 'zip', OUTPUT_DIR)
    print("SUCCESS! Your dataset is ready for the GPU.")


if __name__ == '__main__':
    convert_anylabeling_to_yolo()