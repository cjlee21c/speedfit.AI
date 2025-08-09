from fastapi import FastAPI, UploadFile, File, HTTPException, Form, Depends
from fastapi.responses import FileResponse, JSONResponse
from ultralytics import YOLO
import cv2
import numpy as np
import tempfile
import os
from pathlib import Path
import math
from auth import get_current_user, get_current_user_optional, supabase
from typing import Optional, Dict, Any

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

#finding the barbell plate
def calculate_calibration_from_yolo(results, plate_diameter_meters):
    """
    Calculate pixels per meter using YOLO detected plates (class 0)
    """
    best_plate = None
    max_conf = 0
    
    if len(results) > 0 and len(results[0].boxes) > 0:
        for box in results[0].boxes:
            # Look for plates (class 0) with high confidence
            if int(box.cls) == 0 and box.conf[0] > max_conf and box.conf[0] > 0.7:
                max_conf = box.conf[0]
                best_plate = box
    
    if best_plate is not None:
        # Get plate bounding box coordinates
        x1, y1, x2, y2 = best_plate.xyxy[0].cpu().numpy()
        
        # Calculate plate diameter in pixels (average of width and height)
        width = x2 - x1
        height = y2 - y1
        diameter_pixels = (width + height) / 2
        
        # Calculate pixels per meter
        pixels_per_meter = diameter_pixels / plate_diameter_meters
        
        # Return calibration data and plate info for visualization
        plate_center = ((int((x1+x2)/2), int((y1+y2)/2)), int(diameter_pixels/2))
        return pixels_per_meter, plate_center, max_conf
    
    # Fallback: estimate based on frame size if no plates detected
    return 800.0, None, 0.0

@app.post("/analyze-lift/")  #important part,,Swift app sends a post request through /analyze-lift/ URL, telling FastAPI that this function is activated
async def analyze_lift(
    video: UploadFile = File(...), 
    plate_diameter: float = Form(0.45),
    lift_type: str = Form("Squat"),
    weight: Optional[float] = Form(None),
    current_user: Optional[Dict[str, Any]] = Depends(get_current_user_optional)
):
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
        print(f"Processing video: {video.filename}, size: {video.size} bytes")
        # Open video file
        cap = cv2.VideoCapture(temp_video_path)
        print(f"Video opened: {cap.isOpened()}")
        fps = cap.get(cv2.CAP_PROP_FPS)
        width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
        
        # Create output video writer
        output_path = tempfile.NamedTemporaryFile(delete=False, suffix='.mp4').name
        fourcc = cv2.VideoWriter_fourcc(*'mp4v')
        out = cv2.VideoWriter(output_path, fourcc, fps, (width, height)) #creating a new, blank video file where final video with bar path drawn on it.
        
        bar_positions = []
        timestamps = []
        pixels_per_meter = None
        calibration_confidence = 0.0
        frame_number = 0
        
        # Rep tracking variables (with safe defaults)
        rep_state = "READY"
        rep_start_time = 0.0
        rep_start_y = 0.0
        velocity_window = []
        completed_reps = []
        current_rep_velocity = 0.0
        
        # Frame skipping for performance optimization
        frame_skip = 2  # Process every 2nd frame for YOLO detection
        last_results = None  # Store last YOLO results for skipped frames
        yolo_calls = 0  # Track how many times YOLO actually runs
        
        while cap.isOpened():   #while loop reads video using .read() one frame at a time until the video is over
            ret, frame = cap.read()
            if not ret:
                break
                
            # Frame skipping optimization: only run YOLO on selected frames
            if frame_number % frame_skip == 0:
                # Run YOLO detection on this frame
                #results contain bouding box (coordinates of the box, access with .xyxy), class IO (.cls), and confidency score
                results = model(frame)   #results holds everything the model found in that one frame
                last_results = results  # Store for next skipped frame
                yolo_processed = True
                yolo_calls += 1
            else:
                # Use previous frame's YOLO results
                results = last_results if last_results is not None else model(frame)
                yolo_processed = False
            
            # Perform calibration using YOLO detected plates if not yet calibrated
            if pixels_per_meter is None:
                temp_pixels_per_meter, detected_plate, confidence = calculate_calibration_from_yolo(results, plate_diameter)
                if detected_plate and confidence > calibration_confidence:
                    pixels_per_meter = temp_pixels_per_meter
                    calibration_confidence = confidence
                    # Draw calibration circle around detected plate
                    cv2.circle(frame, detected_plate[0], detected_plate[1], (255, 0, 0), 3)
                    cv2.putText(frame, f"Calibrated: {pixels_per_meter:.1f} px/m (conf: {confidence:.2f})", 
                              (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 0, 0), 2)
            
            # Use fallback calibration if no plates detected after several frames
            if pixels_per_meter is None and frame_number > 30:
                pixels_per_meter = 800.0  # Default fallback
                cv2.putText(frame, "Using default calibration (no plates detected)", 
                          (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
            
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
                
                # Safe rep tracking
                try:
                #bar_positions --> list of all the (x,y) coordinates of the bar, one for each frame
                    if len(bar_positions) >= 2 and len(timestamps) >= 2:
                        current_y = bar_center[1]
                        current_time = timestamps[-1]
                        prev_y = bar_positions[-2][1] 
                        prev_time = timestamps[-2]
                        
                        # Calculate Y velocity safely
                        time_diff = current_time - prev_time
                        if time_diff > 0 and pixels_per_meter and pixels_per_meter > 0:
                            y_velocity_pixels = (current_y - prev_y) / time_diff
                            y_velocity_ms = -y_velocity_pixels / pixels_per_meter  # Negative = up
                            
                            # Add to velocity window
                            velocity_window.append(y_velocity_ms)
                            if len(velocity_window) > 10:
                                velocity_window.pop(0)
                            
                            # Simple rep detection
                            if len(velocity_window) >= 5:
                                avg_velocity = sum(velocity_window) / len(velocity_window)
                                
                                if avg_velocity > 0.05 and rep_state == "READY":
                                    rep_state = "LIFTING"
                                    rep_start_time = current_time
                                    rep_start_y = current_y
                                elif avg_velocity <= 0.0 and rep_state == "LIFTING":
                                    # Rep completed
                                    rep_duration = current_time - rep_start_time
                                    if rep_duration > 0.5:
                                        rep_distance = abs(rep_start_y - current_y) / pixels_per_meter
                                        rep_velocity = rep_distance / rep_duration
                                        completed_reps.append(rep_velocity)
                                        current_rep_velocity = rep_velocity
                                    rep_state = "READY"
                except Exception as e:
                    print(f"Rep tracking error (skipping): {e}")
                    pass  # Continue processing even if rep tracking fails
                
                
                # Draw the bar path on the frame
                if len(bar_positions) > 1:
                    points = np.array(bar_positions, dtype=np.int32)
                    cv2.polylines(frame, [points], isClosed=False, color=(0, 255, 0), thickness=2)
                
                
                # Safe rep overlay - bottom left, bigger size
                try:
                    # Calculate position for bottom-left (bigger box)
                    box_width = 200
                    box_height = 120
                    box_x = 20
                    box_y = height - box_height - 20
                    
                    # Draw rep info box
                    cv2.rectangle(frame, (box_x, box_y), (box_x + box_width, box_y + box_height), (0, 0, 0), -1)
                    cv2.rectangle(frame, (box_x, box_y), (box_x + box_width, box_y + box_height), (255, 255, 255), 3)
                    
                    cv2.putText(frame, f"Reps: {len(completed_reps)}", (box_x + 15, box_y + 35), 
                              cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
                    cv2.putText(frame, f"State: {rep_state}", (box_x + 15, box_y + 70), 
                              cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
                    if current_rep_velocity > 0:
                        cv2.putText(frame, f"Last: {current_rep_velocity:.2f}m/s", (box_x + 15, box_y + 105), 
                                  cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
                except Exception as e:
                    print(f"Overlay error (skipping): {e}")
                    pass
            
            # Add performance indicator
            perf_color = (0, 255, 0) if yolo_processed else (255, 255, 0)  # Green if YOLO ran, yellow if skipped
            perf_text = "YOLO" if yolo_processed else "SKIP"
            cv2.putText(frame, perf_text, (width - 60, 25), 
                      cv2.FONT_HERSHEY_SIMPLEX, 0.5, perf_color, 1)
            
            # Write the frame
            out.write(frame)
            frame_number += 1
        
        # Calculate session statistics (per-rep data only)
        session_stats = {}
        if completed_reps:
            session_average = sum(completed_reps) / len(completed_reps)
            session_stats = {
                "session_average": session_average,
                "total_reps": len(completed_reps),
                "rep_speeds": completed_reps,
                "calibration_used": pixels_per_meter is not None,
                "pixels_per_meter": pixels_per_meter or 0
            }
        
        # Print session stats to console for debugging
        print(f"Session Analysis Complete: {session_stats}")
        
        # Print performance optimization stats
        total_frames = frame_number
        frames_saved = total_frames - yolo_calls
        speed_improvement = (frames_saved / total_frames) * 100 if total_frames > 0 else 0
        print(f"Performance Optimization: {yolo_calls}/{total_frames} YOLO calls ({speed_improvement:.1f}% faster)")
        
        # Clean up
        cap.release()
        out.release()
        cv2.destroyAllWindows()
        os.unlink(temp_video_path)
        
        # Store session metrics in a temporary file alongside video
        metrics_path = output_path.replace('.mp4', '_metrics.json')
        print(f"DEBUG: Creating metrics file at: {metrics_path}")
        print(f"DEBUG: Output path was: {output_path}")
        import json
        with open(metrics_path, 'w') as f:
            json.dump(session_stats, f)
        print(f"DEBUG: Metrics file created successfully")
        
        # Save to database if user is authenticated
        session_id = None
        user_authenticated = current_user is not None
        has_reps = session_stats.get("total_reps", 0) > 0
        print(f"DEBUG: User authenticated: {user_authenticated}, Has reps: {has_reps}")
        
        if current_user and session_stats.get("total_reps", 0) > 0:
            try:
                # Determine plate size string from diameter
                plate_size_map = {
                    0.45: "45cm (Olympic)",
                    0.35: "35cm (Standard)", 
                    0.25: "25cm (Small)"
                }
                plate_size = plate_size_map.get(plate_diameter, "45cm (Olympic)")
                
                # Insert workout session
                session_data = {
                    "user_id": current_user["id"],
                    "lift_type": lift_type,
                    "weight": weight,
                    "plate_size": plate_size,
                    "session_average": session_stats.get("session_average"),
                    "total_reps": session_stats.get("total_reps", 0),
                    "calibration_used": session_stats.get("calibration_used", False),
                    "pixels_per_meter": session_stats.get("pixels_per_meter", 0)
                }
                
                session_response = supabase.table("workout_sessions").insert(session_data).execute()
                
                if session_response.data:
                    session_id = session_response.data[0]["id"]
                    
                    # Insert individual rep analysis
                    for i, velocity in enumerate(session_stats.get("rep_speeds", [])):
                        rep_data = {
                            "session_id": session_id,
                            "rep_number": i + 1,
                            "velocity": velocity
                        }
                        supabase.table("rep_analysis").insert(rep_data).execute()
                    
                    print(f"Saved workout session {session_id} for user {current_user['id']}")
                
            except Exception as e:
                print(f"Error saving session to database: {e}")
                # Continue without failing the request
        
        # Return the processed video
        headers = {"X-Metrics-Path": metrics_path}
        if session_id:
            headers["X-Session-Id"] = str(session_id)
            
        return FileResponse(
            output_path,
            media_type="video/mp4",
            headers=headers
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
        print(f"DEBUG: Metrics request received")
        
        # Security: Validate video_id format to prevent path traversal
        if not re.match(r'^[a-zA-Z0-9_-]+$', video_id):
            print(f"DEBUG: Invalid video_id format")
            raise HTTPException(status_code=400, detail="Invalid video ID format")
        
        # Construct metrics file path - use proper temp directory
        import tempfile
        temp_dir = tempfile.gettempdir()
        metrics_path = os.path.join(temp_dir, f"{video_id}_metrics.json")
        print(f"DEBUG: Looking for metrics file at: {metrics_path}")
        print(f"DEBUG: File exists: {os.path.exists(metrics_path)}")
        
        # List all files in temp directory to see what's actually there
        print(f"DEBUG: Files in {temp_dir}: {[f for f in os.listdir(temp_dir) if 'metrics.json' in f]}")
        
        if not os.path.exists(metrics_path):
            raise HTTPException(status_code=404, detail="Metrics not found")
        
        with open(metrics_path, 'r') as f:
            metrics = json.load(f)
        
        print(f"DEBUG: Successfully loaded metrics: {metrics}")
        return JSONResponse(content=metrics)
    except Exception as e:
        print(f"DEBUG: Error in get_metrics: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/workout-sessions/")
async def get_workout_sessions(
    current_user: Dict[str, Any] = Depends(get_current_user),
    limit: int = 50,
    offset: int = 0
):
    """Get user's workout sessions"""
    try:
        response = supabase.table("workout_sessions") \
            .select("*") \
            .eq("user_id", current_user["id"]) \
            .order("session_date", desc=True) \
            .range(offset, offset + limit - 1) \
            .execute()
        
        return {"sessions": response.data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/workout-sessions/{session_id}/reps")
async def get_session_reps(
    session_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Get rep analysis for a specific session"""
    try:
        # Verify session belongs to user
        session_response = supabase.table("workout_sessions") \
            .select("id") \
            .eq("id", session_id) \
            .eq("user_id", current_user["id"]) \
            .execute()
        
        if not session_response.data:
            raise HTTPException(status_code=404, detail="Session not found")
        
        # Get rep analysis
        reps_response = supabase.table("rep_analysis") \
            .select("*") \
            .eq("session_id", session_id) \
            .order("rep_number", desc=False) \
            .execute()
        
        return {"reps": reps_response.data}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/workout-sessions/{session_id}")
async def delete_workout_session(
    session_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    """Delete a workout session"""
    try:
        # Verify session belongs to user and delete
        response = supabase.table("workout_sessions") \
            .delete() \
            .eq("id", session_id) \
            .eq("user_id", current_user["id"]) \
            .execute()
        
        if not response.data:
            raise HTTPException(status_code=404, detail="Session not found")
        
        return {"message": "Session deleted successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {"status": "healthy", "model_loaded": model is not None} 
