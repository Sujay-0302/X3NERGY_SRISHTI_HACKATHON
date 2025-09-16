
import base64
import pymysql
import io
import traceback
import numpy as np
from flask import Flask, request, jsonify
from flask_cors import CORS
from deepface import DeepFace
import cv2
from PIL import Image
import pickle

app = Flask(__name__)
CORS(app)

# Database connection function
def get_db_connection():
    return pymysql.connect( 
        
        host="localhost",
        user="short",
        password="123",
        database="stmdata",
        cursorclass=pymysql.cursors.DictCursor
    )

# Extract facial features
def extract_features(image):
    try:
        embedding = DeepFace.represent(image, model_name="Facenet", enforce_detection=False)
        return np.array(embedding[0]["embedding"])
    except Exception as e:
        print("Error extracting features:", e)
        return None

@app.route('/api/store-image', methods=['POST'])
def store_image():
    try:
        data = request.json
        name = data.get("name")
        relation = data.get("relation")
        description = data.get("description")
        image_base64 = data.get("image")

        if not all([name, relation, description, image_base64]):
            return jsonify({"error": "Missing required fields"}), 400

        # Decode base64 image
        image_data = base64.b64decode(image_base64)
        image = Image.open(io.BytesIO(image_data))
        image = np.array(image)

        # Extract features
        features = extract_features(image)
        if features is None:
            return jsonify({"error": "Feature extraction failed"}), 500

        # Convert NumPy array to bytes for database storage
        features_bytes = pickle.dumps(features)

        db = get_db_connection()
        with db.cursor() as cursor:
            # Store image details in the image table
            sql = "INSERT INTO image (name, relation, description, image_data) VALUES (%s, %s, %s, %s)"
            cursor.execute(sql, (name, relation, description, image_data))
            image_id = cursor.lastrowid  # Get the inserted image ID

            # Store extracted features in the image_data table linked to image table
            sql1 = "INSERT INTO image_data (image_id, image_ex) VALUES (%s, %s)"
            cursor.execute(sql1, (image_id, features_bytes))
            
            db.commit()
        db.close()

        return jsonify({"message": "Image stored successfully", "image_id": image_id}), 201

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route('/api/match-image', methods=['POST'])
def match_image_endpoint():
    try:
        print("[MATCH] Face matching started...")

        new_image_base64 = request.json.get('image')
        if not new_image_base64:
            return jsonify({"error": "No image provided"}), 400

        # Decode base64 and extract features
        new_image_data = base64.b64decode(new_image_base64)
        new_image = Image.open(io.BytesIO(new_image_data))
        new_image = np.array(new_image)
        fx1 = extract_features(new_image)

        if fx1 is None:
            return jsonify({"error": "Feature extraction failed"}), 500

        db = get_db_connection()
        if db is None:
            return jsonify({"error": "Database connection failed"}), 500

        matched_image_id = None
        min_distance = float("inf")  # Initialize with a large value

        try:
            with db.cursor() as cursor:
                # Fetch stored features from image_data table
                sql = "SELECT image_id, image_ex FROM image_data"
                cursor.execute(sql)
                all_images = cursor.fetchall()

            for row in all_images:
                try:
                    # Ensure image_ex is not empty or NULL
                    if not row['image_ex']:
                        print(f"[ERROR] Empty or NULL image_ex for ID={row['image_id']}")
                        continue

                    # Deserialize stored features
                    features_img2 = pickle.loads(bytes(row['image_ex']))

                    # Compute Euclidean distance
                    distance = np.linalg.norm(fx1 - features_img2)

                    print(f"[MATCH] Comparing with image ID={row['image_id']}, Distance={distance}")

                    # Update matched image if distance is smallest
                    if distance < 10 and distance < min_distance:
                        min_distance = distance
                        matched_image_id = row['image_id']

                except Exception as e:
                    print(f"[MATCH] Error processing database image ID={row['image_id']}: {e}")
                    traceback.print_exc()
                    continue

        finally:
            db.close()

        # If a match is found, retrieve full details from the image table
        if matched_image_id is not None:
            db = get_db_connection()
            with db.cursor() as cursor:
                sql = "SELECT * FROM image WHERE id = %s"
                cursor.execute(sql, (matched_image_id,))
                matched_image = cursor.fetchone()
            db.close()

            # Convert image_data from bytes to base64 string
            if matched_image and 'image_data' in matched_image:
                matched_image['image_data'] = base64.b64encode(matched_image['image_data']).decode('utf-8')

            print(f"[MATCH] Match found! Returning details of ID={matched_image_id}")
            return jsonify(matched_image), 200

        print("[MATCH] No match found in database")
        return jsonify({"message": "No match found"}), 404

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0", port=5000)
#image 
