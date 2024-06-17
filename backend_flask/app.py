import cv2
import numpy as np
import face_recognition
import os
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
from functools import wraps


from werkzeug.utils import secure_filename

import shutil

app = Flask(__name__)
CORS(app)

SECRET_CODE = "xmqoqxTzdyBsZw3YI0ZZGuqVI6dDWaVLfBA+69Kbcp0="

def secret_code_auth_middleware(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        # Check if Authorization header is present
        if "Authorization" not in request.headers:
            return jsonify({"error": "Missing Authorization header"}), 401
        
        # Check if secret code is provided in the Authorization header
        client_code = request.headers.get("Authorization")
        if client_code != f"Bearer {SECRET_CODE}":
            return jsonify({"error": "Invalid secret code"}), 401
        return func(*args, **kwargs)
    return wrapper

path = os.getcwd() + '/Images_Attendance'
old_images = []
old_classNames = []
old_encodeListKnown = []

def old_encode_images():
    global old_encodeListKnown, old_classNames, old_images
    old_encodeListKnown = []
    old_images = []
    old_classNames = []
    myList = os.listdir(path)
    for cl in myList:
        curImg = cv2.imread(f'{path}/{cl}')
        old_images.append(curImg)
        old_classNames.append(os.path.splitext(cl)[0])

    for img in old_images:
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        encode = face_recognition.face_encodings(img)[0]
        old_encodeListKnown.append(encode)
    print("old encoding complete")

old_encode_images()
print(len(old_encodeListKnown))

# Directory where known images are stored
new_known_images_dir = "./images"

# Lists to store known encodings and corresponding names
new_known_encodings = []
new_known_names = []

def new_load_image(image_path):
    # Function to load an image and handle errors
    image = cv2.imread(image_path)
    if image is None:
        print(f"Couldn't read image {image_path}")
    else:
        return image

def new_encode_faces():
    # Counter to keep track of encoded images
    encoded_images_counter = 0

    # Loop over each directory in new_known_images_dir
    for individual_dir in os.listdir(new_known_images_dir):
        if not os.path.isdir(os.path.join(new_known_images_dir, individual_dir)):
            continue  # Skip if not a directory

        # Loop over each image in the directory
        for filename in os.listdir(os.path.join(new_known_images_dir, individual_dir)):
            print(f"Processing file: {filename}")  # Print the file being processed

            # Load the image
            image = new_load_image(f"{new_known_images_dir}/{individual_dir}/{filename}")
            if image is None:
                continue  # Skip if the image could not be read

            # Convert the image from BGR (OpenCV default) to RGB
            rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

            # Find all face encodings in the current image
            encodings = face_recognition.face_encodings(rgb_image)

            # Add each encoding to the new_known_encodings list
            for encoding in encodings:
                new_known_encodings.append(encoding)
                new_known_names.append(individual_dir)
                encoded_images_counter += 1

    print(f"Total encoded images: {encoded_images_counter}")
@app.route("/", methods=["GET"])
def check():
    print("live")
    return jsonify({"message": "live"})


@app.route("/advpredict", methods=["POST"])
def advpredict():
    if 'file' not in request.files:
        return jsonify({'error': 'No video file received'})

    video_file = request.files['file']
    video_path = 'input_video.mp4'
    video_file.save(video_path)

    # List to store face IDs
    face_ids = []

    # Video object
    video = cv2.VideoCapture(video_path)

    # Counter to keep track of the total number of detected faces
    total_detected_faces = 0

    # Distance threshold for face comparison
    distance_threshold = 0.5

    # Get total number of frames in the video
    total_frames = int(video.get(cv2.CAP_PROP_FRAME_COUNT))

    # Loop over each frame in the video
    frame_counter = 0
    print("video to frame")
    while video.isOpened():
        if frame_counter >= total_frames:  # Check if it's the last frame
            break

        ret, frame = video.read()
        if not ret or frame_counter % 5 != 0:
            frame_counter += 1
            continue

        # Convert the image from BGR to RGB
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        # Find all face encodings in the current frame
        face_locations = face_recognition.face_locations(rgb_frame)
        face_encodings = face_recognition.face_encodings(rgb_frame, face_locations)

        total_detected_faces += len(face_encodings)

        for i, (face_location, face_encoding) in enumerate(zip(face_locations, face_encodings)):
            # Compare face encodings with known encodings
            face_distances = face_recognition.face_distance(new_known_encodings, face_encoding)

            # Find the closest match
            best_match_index = np.argmin(face_distances)
            if face_distances[best_match_index] <= distance_threshold:
                name = new_known_names[best_match_index]
            else:
                name = "Unknown"
            face_ids.append(name)

        frame_counter += 1

    # Close the video file
    video.release()

    # Remove duplicates from the face_ids list
    unique_face_ids = list(set(face_ids))

    # Remove the video file
    try:
        os.remove(video_path)
    except Exception as e:
        print(f"Error deleting video file: {e}")

    return jsonify({'unique_faces': unique_face_ids, 'total_faces': total_detected_faces})

@app.route("/encode", methods=["GET","POST"])
@secret_code_auth_middleware
def new_encode():
    new_encode_faces()
    return jsonify({'total_encoded_images': len(new_known_encodings)})

@app.route("/predict", methods=["POST", "GET"])
@secret_code_auth_middleware
def predict():
    print(" rout for predict")
    if request.method == "GET":
        print("get request under 'get' request")
        return jsonify({"method": "GET"})

    try:
        print("under predict-try block")
        print(len(old_encodeListKnown))
        image = request.files['image']
        if(image is not None):
         print("upper image found")
        else:
         print("upper image not found")
        image_file = image.read()
        if image_file is not None:
         print("image is recieved")
        else: 
         print("image not recieved")

        np_image = np.frombuffer(image_file, np.uint8)
        img = cv2.imdecode(np_image, cv2.IMREAD_COLOR)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

        facesCurFrame = face_recognition.face_locations(img)
        encodesCurFrame = face_recognition.face_encodings(img, facesCurFrame)

        for encodeFace, faceLoc in zip(encodesCurFrame, facesCurFrame):
            matches = face_recognition.compare_faces(old_encodeListKnown, encodeFace)
            faceDis = face_recognition.face_distance(old_encodeListKnown, encodeFace)

            matchIndex = np.argmin(faceDis)

            if matches[matchIndex]:
                name = old_classNames[matchIndex].upper()
                response = jsonify({'ok': True, 'data': name, 'message': 'Employee recognized successfully'})
                print(name)
                response.headers.add("Access-Control-Allow-Origin", "*")
                response.headers.add("Access-Control-Allow-Headers", "*")
                response.headers.add("Access-Control-Allow-Methods", "*")
                return response
        response = jsonify({'ok': False, 'message': "Employee could not be recognized", 'data': None})
        response.headers.add("Access-Control-Allow-Origin", "*")
        return response

    except Exception as e:
        return jsonify({'ok': False,'data': None, 'message': str(e)})

@app.route("/add", methods=["POST"])
@secret_code_auth_middleware
def add():
    try:
        id = request.form.get('id')
        if id in old_classNames:
            return jsonify({'ok': False,'data': None, 'message': 'Employee with same ID number already exists'})

        image = request.files['image']
        image1 = image.read()
        np_image = np.frombuffer(image1, np.uint8)
        img = cv2.imdecode(np_image, cv2.IMREAD_COLOR)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

        tid = str(id)
        cv2.imwrite(os.path.join(path, tid + ".jpg"), cv2.cvtColor(img, cv2.COLOR_RGB2BGR))

        old_classNames.append(tid)
        old_encode_images()
        print("encoding complete for new image")
        print(len(old_encodeListKnown))
        response = jsonify({'ok': True, 'data': None, 'message': 'Added employee successfully'})
        response.headers.add("Access-Control-Allow-Origin", "*")
        response.headers.add("Access-Control-Allow-Headers", "*")
        response.headers.add("Access-Control-Allow-Methods", "*")
        return response

    except Exception as e:
        return jsonify({'ok': False,'data': None, 'message': str(e)})

@app.route("/edit", methods=["POST"])
@secret_code_auth_middleware
def edit():
    global old_encodeListKnown
    try:
        image = request.files['image']
        id = request.form.get('id')
        tid = str(id)

        if tid not in old_classNames:
            return jsonify({'ok': False,'data': None, 'message': f"Employee with id {id} does not exist"})

        # delete the old image file
        os.remove(os.path.join(path, tid + ".jpg"))
        old_classNames.remove(tid)
        old_encodeListKnown = []

        # save the new image file
        image1 = image.read()
        np_image = np.frombuffer(image1, np.uint8)
        img = cv2.imdecode(np_image, cv2.IMREAD_COLOR)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

        cv2.imwrite(os.path.join(path, tid + ".jpg"), cv2.cvtColor(img, cv2.COLOR_RGB2BGR))

        # re-encode all the images
        old_encode_images()
        print("encoding complete for new image")
        return jsonify({'ok': True, 'data': None,'message': 'Updated employee successfully'})

    except Exception as e:
        return jsonify({'ok': False,'data': None, 'message': str(e)})


@app.route("/add_video_face", methods=["POST"])
@secret_code_auth_middleware
def add_video_face():
    try:
        # Extract the ID from the form data
        id = request.form.get('id')

        # Extract the list of images from the form data
        image_files = request.files.getlist('images')
        
        # Create a new directory for this ID, if it doesn't already exist
        os.makedirs(f'images/{id}', exist_ok=True)

        # Iterate over each image file
        for image in image_files:
            # Read the image file
            image1 = image.read()

            # Convert the image data into a NumPy array
            np_image = np.frombuffer(image1, np.uint8)

            # Decode the image data
            img = cv2.imdecode(np_image, cv2.IMREAD_COLOR)

            # Save the image file
            cv2.imwrite(f'images/{id}/{secure_filename(image.filename)}', img)

        # Return a success response
        return jsonify({'ok': True, 'data': None, 'message': f'Added {len(image_files)} images for ID {id} successfully'})

    except Exception as e:
        # If anything goes wrong, return an error response
        return jsonify({'ok': False, 'data': None, 'message': str(e)})

@app.route("/delete_video_face", methods=["POST"])
@secret_code_auth_middleware
def delete_video_face():
    try:
        # Extract the ID from the form data
        id = request.form.get('id')

        # Check if the directory exists
        if os.path.exists(f'images/{id}'):
            # Delete the directory
            shutil.rmtree(f'images/{id}')
            return jsonify({'ok': True, 'message': f'Deleted images for ID {id} successfully'})
        else:
            return jsonify({'ok': False, 'message': f'No images found for ID {id}'})

    except Exception as e:
        # If anything goes wrong, return an error response
        return jsonify({'ok': False, 'data': None, 'message': str(e)})

@app.route("/scr_add_video_face", methods=["POST"])
@secret_code_auth_middleware
def scr_add_video_face():
    try:
        # Extract the ID from the form data
        id = request.form.get('id')

        # Check if the directory already exists
        if os.path.exists(f'images/{id}'):
            return jsonify({'ok': False, 'message': f'ID {id} already exists'})
        
        # Extract the list of images from the form data
        image_files = request.files.getlist('images')
        
        # Create a new directory for this ID
        os.makedirs(f'images/{id}')

        # Iterate over each image file
        for image in image_files:
            # Read the image file
            image1 = image.read()

            # Convert the image data into a NumPy array
            np_image = np.frombuffer(image1, np.uint8)

            # Decode the image data
            img = cv2.imdecode(np_image, cv2.IMREAD_COLOR)

            # Save the image file
            cv2.imwrite(f'images/{id}/{secure_filename(image.filename)}', img)

        # Return a success response
        return jsonify({'ok': True, 'data': None, 'message': f'Added {len(image_files)} images for ID {id} successfully'})

    except Exception as e:
        # If anything goes wrong, return an error response
        return jsonify({'ok': False, 'data': None, 'message': str(e)})

if __name__ == '__main__':
    old_encode_images()
    new_encode_faces()
    app.run(debug=True, host='0.0.0.0', port=4444)

