from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from ultralytics import YOLO
import cv2
import numpy as np
import tempfile
import os
from pathlib import Path

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

@app.post("/analyze-lift/")  #important part,,Swift app sends a post request through /analyze-lift/ URL, telling FastAPI that this function is activated
async def analyze_lift(video: UploadFile = File(...)):
    # Security: Validate file type and size
    if not video.filename.endswith(('.mp4', '.mov', '.avi')):
        raise HTTPException(status_code=400, detail="Invalid video format")
    
    # Security: Limit file size to 100MB
    MAX_FILE_SIZE = 100 * 1024 * 1024  # 100MB
    if video.size and video.size > MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large. Maximum size is 100MB")
    
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
        
        while cap.isOpened():   #while loop reads video using .read() one frame at a time until the video is over
            ret, frame = cap.read()
            if not ret:
                break
                
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
                
                # Draw the bar path on the frame
                if len(bar_positions) > 1:
                    points = np.array(bar_positions, dtype=np.int32)
                    cv2.polylines(frame, [points], isClosed=False, color=(0, 255, 0), thickness=2)
            
            # Write the frame
            out.write(frame)
        
        # Clean up
        cap.release()
        out.release()
        cv2.destroyAllWindows()
        os.unlink(temp_video_path)
        
        # Return the processed video
        return FileResponse(
            output_path,
            media_type="video/mp4"
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Cleanup temp files
        if os.path.exists(temp_video_path):
            os.unlink(temp_video_path)

@app.get("/health")
async def health_check():
    return {"status": "healthy", "model_loaded": model is not None} 
