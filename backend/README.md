# Speedfit.AI Backend

This is the backend server for Speedfit.AI, which processes workout videos using YOLOv8 for bar path tracking.

## Setup

1. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Place your YOLO model:
- Put your `best.pt` file in the `models` directory

4. Run the server:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## API Endpoints

- `GET /health`: Health check endpoint
- `POST /analyze-lift/`: Upload a video for analysis
  - Accepts: multipart/form-data with a video file
  - Returns: Processed video with bar path visualization

## Notes

- The YOLO model expects to detect "bar tip" (class 1)
- Confidence threshold for detection is set to 0.25
- The server needs to be running for the iOS app to work 