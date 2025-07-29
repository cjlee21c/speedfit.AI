from fastapi import FastAPI, UploadFile, File, HTTPException, Form
from fastapi.responses import FileResponse, JSONResponse
from ultralytics import YOLO
import cv2
import numpy as np
import tempfile
import os
from pathlib import Path
import math

app = FastAPI(title="Speedfit.AI Backend")  #creating main application instance

# Global variable for the YOLO model
model = None

@app.on_event("startup") #run this function one time, right after server starts up before accepting any requests --> making api much faster
async def load_model():
    global model
    model_path = Path("models/best.pt")  # Update this path to where you'll store your model
    if not model_path.exists():
        raise RuntimeError("YOLO model not found")
    model = YOLO(model_path)

def calculate_calibration(frame, plate_diameter_meters):
    """
    Calculate pixels per meter using plate detection
    """
    # Convert to HSV for better color detection
    hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
    
    # Create a mask for dark circular objects (plates)
    # Adjust these values based on your plate colors
    lower_dark = np.array([0, 0, 0])
    upper_dark = np.array([180, 255, 100])
    mask = cv2.inRange(hsv, lower_dark, upper_dark)
    
    # Find contours
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # Find the largest circular contour (likely a plate)
    best_circle = None
    max_area = 0
    
    for contour in contours:
        area = cv2.contourArea(contour)
        if area > max_area and area > 1000:  # Minimum area threshold
            # Check if contour is roughly circular
            perimeter = cv2.arcLength(contour, True)
            if perimeter > 0:
                circularity = 4 * math.pi * area / (perimeter * perimeter)
                if circularity > 0.5:  # Reasonably circular
                    # Get bounding circle
                    (x, y), radius = cv2.minEnclosingCircle(contour)
                    if radius > 20:  # Minimum radius threshold
                        best_circle = ((int(x), int(y)), int(radius))
                        max_area = area
    
    if best_circle:
        # Calculate pixels per meter
        radius_pixels = best_circle[1]
        diameter_pixels = radius_pixels * 2
        pixels_per_meter = diameter_pixels / plate_diameter_meters
        return pixels_per_meter, best_circle
    
    # Fallback: estimate based on frame size (rough approximation)
    return 800.0, None  # Default approximation

@app.post("/analyze-lift/")  #important part,,Swift app sends a post request through /analyze-lift/ URL, telling FastAPI that this function is activated
async def analyze_lift(video: UploadFile = File(...), plate_diameter: float = Form(0.45)):
    # Security: Validate file type and size
    if not video.filename or not video.filename.lower().endswith(('.mp4', '.mov', '.avi')):
        raise HTTPException(status_code=400, detail="Invalid video format")
    
    # Security: Limit file size to 100MB
    MAX_FILE_SIZE = 100 * 1024 * 1024  # 100MB
    if video.size and video.size > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large. Maximum size is 100MB")
    
    # Security: Validate filename to prevent path traversal
    import re
    if not re.match(r'^[a-zA-Z0-9._-]+$', video.filename):
        raise HTTPException(status_code=400, detail="Invalid filename format")
    
    # Validate plate diameter
    if not (0.1 <= plate_diameter <= 1.0):
        raise HTTPException(status_code=400, detail="Invalid plate diameter. Must be between 0.1 and 1.0 meters")
    
    # Save uploaded video to temp file
    with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(video.filename)[1]) as temp_video:
        content = await video.read()
        temp_video.write(content)
        temp_video_path = temp_video.name

    try:
        # Open video file
        cap = cv2.VideoCapture(temp_video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        
        # Create output video writer
        output_path = tempfile.NamedTemporaryFile(delete=False, suffix='.mp4').name
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(output_path, fourcc, fps, (width, height)) #creating a new, blank video file where final video with bar path drawn on it.
        
        bar_positions = []
        velocities = []
        timestamps = []
        pixels_per_meter = None
        calibration_frame_count = 0
        frame_number = 0
        
        while cap.isOpened():   #while loop reads video using .read() one frame at a time until the video is over
            ret, frame = cap.read()
            if not ret:
                break
            
            # Perform calibration on early frames if not yet calibrated
            if pixels_per_meter is None and calibration_frame_count < 10:
                temp_pixels_per_meter, detected_circle = calculate_calibration(frame, plate_diameter)
                if detected_circle:
                    pixels_per_meter = temp_pixels_per_meter
                    # Draw calibration circle for feedback
                    cv2.circle(frame, detected_circle[0], detected_circle[1], (255, 0, 0), 2)
                    cv2.putText(frame, f"Calibrated: {pixels_per_meter:.1f} px/m", 
                              (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 0), 2)
                calibration_frame_count += 1
            
            # Use fallback calibration if none found
            if pixels_per_meter is None and calibration_frame_count >= 10:
                pixels_per_meter = 800.0  # Default fallback
                
            # Run YOLO detection
            results = model(frame)   #results holds everything the model found in that one frame
            
            # Find the best "bar tip" detection in the frame
            best_bar_tip = None
            max_conf = 0
            
            if len(results) > 0 and len(results[0].boxes) > 0:
                for box in results[0].boxes:
                    # Check if the detected class is "bar tip" (assuming class ID is 1)
                    if int(box.cls) == 1 and box.conf[0] > max_conf:
                        max_conf = box.conf[0]
                        best_bar_tip = box

            # If a confident bar tip was found, use it to draw the path
            if best_bar_tip is not None and best_bar_tip.conf[0] > 0.25: # Confidence threshold
                # Get the coordinates of the bar tip box
                x1, y1, x2, y2 = best_bar_tip.xyxy[0].cpu().numpy()
                
                # Calculate the center point of this box
                bar_center = np.array([(x1 + x2) / 2, (y1 + y2) / 2])
                bar_positions.append(bar_center)
                timestamps.append(frame_number / fps)  # Time in seconds
                
                # Calculate velocity if we have enough positions
                current_velocity = 0.0
                if len(bar_positions) >= 3 and pixels_per_meter:
                    # Use last 3 points for smoother velocity calculation
                    pos_current = bar_positions[-1]
                    pos_prev = bar_positions[-2]
                    time_current = timestamps[-1]
                    time_prev = timestamps[-2]
                    
                    # Calculate distance in pixels and convert to meters
                    distance_pixels = np.linalg.norm(pos_current - pos_prev)
                    distance_meters = distance_pixels / pixels_per_meter
                    
                    # Calculate time difference
                    time_diff = time_current - time_prev
                    
                    if time_diff > 0:
                        current_velocity = distance_meters / time_diff  # m/s
                        
                        # Apply smoothing filter
                        if len(velocities) > 0:
                            # Simple exponential smoothing
                            alpha = 0.3
                            current_velocity = alpha * current_velocity + (1 - alpha) * velocities[-1]
                
                velocities.append(current_velocity)
                
                # Draw the bar path on the frame
                if len(bar_positions) > 1:
                    points = np.array(bar_positions, dtype=np.int32)
                    cv2.polylines(frame, [points], isClosed=False, color=(0, 255, 0), thickness=2)
                
                # Display velocity on frame
                if current_velocity > 0:
                    velocity_text = f"Speed: {current_velocity:.2f} m/s"
                    cv2.putText(frame, velocity_text, (10, height - 30), 
                              cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
            
            # Write the frame
            out.write(frame)
            frame_number += 1
        
        # Calculate velocity statistics
        velocity_stats = {}
        if velocities:
            valid_velocities = [v for v in velocities if v > 0]
            if valid_velocities:
                velocity_stats = {
                    "peak_velocity": max(valid_velocities),
                    "mean_velocity": sum(valid_velocities) / len(valid_velocities),
                    "total_distance": sum(distances for distances in [
                        np.linalg.norm(bar_positions[i+1] - bar_positions[i]) / pixels_per_meter 
                        for i in range(len(bar_positions)-1)
                    ] if pixels_per_meter),
                    "calibration_used": pixels_per_meter is not None,
                    "pixels_per_meter": pixels_per_meter or 0
                }
        
        # Print velocity stats to console for debugging
        print(f"Velocity Analysis Complete: {velocity_stats}")
        
        # Clean up
        cap.release()
        out.release()
        cv2.destroyAllWindows()
        os.unlink(temp_video_path)
        
        # Store metrics in a temporary file alongside video
        metrics_path = output_path.replace('.mp4', '_metrics.json')
        import json
        with open(metrics_path, 'w') as f:
            json.dump(velocity_stats, f)
        
        # Return the processed video
        return FileResponse(
            output_path,
            media_type="video/mp4",
            headers={"X-Metrics-Path": metrics_path}
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Cleanup temp files
        if os.path.exists(temp_video_path):
            os.unlink(temp_video_path)

@app.get("/metrics/{video_id}")
async def get_metrics(video_id: str):
    """Get velocity metrics for a processed video"""
    import json
    import re
    try:
        # Security: Validate video_id format to prevent path traversal
        if not re.match(r'^[a-zA-Z0-9_-]+$', video_id):
            raise HTTPException(status_code=400, detail="Invalid video ID format")
        
        # Construct metrics file path
        metrics_path = f"/tmp/{video_id}_metrics.json"
        
        if not os.path.exists(metrics_path):
            raise HTTPException(status_code=404, detail="Metrics not found")
        
        with open(metrics_path, 'r') as f:
            metrics = json.load(f)
        
        return JSONResponse(content=metrics)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {"status": "healthy", "model_loaded": model is not None} 
