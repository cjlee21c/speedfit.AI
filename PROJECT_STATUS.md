# Speedfit.AI Project Summary

## Current Status
- ✅ Working iOS app with YOLOv8 barbell detection
- ✅ Backend running on FastAPI with video processing
- ✅ Per-rep velocity tracking with state machine (READY/LIFTING)
- ✅ Frame skipping optimization (50% faster processing)
- ✅ Simplified UI focused on session-based per-rep data
- ✅ Bigger bottom-left overlay showing rep count and velocities
- ✅ Successfully pushed to GitHub: https://github.com/cjlee21c/speedfit.AI

## Key Features
### Backend (Python FastAPI)
- **YOLO-based detection**: Plates (class 0) and bar tips (class 1)
- **Smart calibration**: Uses known plate diameters (45cm, 35cm, 25cm)
- **Per-rep velocity tracking**: State machine detects concentric lifting phases
- **Frame skipping**: Only runs YOLO on every 2nd frame for 50% speed improvement
- **Session analytics**: Calculates session average and tracks individual rep speeds
- **Error handling**: Comprehensive try-catch blocks prevent crashes

### iOS App (SwiftUI)
- **Clean session UI**: Shows session average, total reps, individual rep speeds
- **Simplified data**: Removed unused peak/mean velocity features
- **Real-time feedback**: Video overlay shows rep count and lifting state
- **Calibration guidance**: Built-in camera setup instructions

## Performance Optimizations
- **Frame skipping**: 50% reduction in YOLO inference calls
- **Simplified calculations**: Removed frame-by-frame velocity math
- **Smart calibration**: Only attempts calibration on first 30 frames

## Network Setup
- **Hotspot connectivity**: App connects via Personal Hotspot (172.20.10.x)
- **IP helper script**: `./get_ip.sh` shows current server IP and health status
- **Dynamic IP handling**: Configured for hotspot stability

## Project Structure
- iOS app: `/Users/cj/Desktop/Speedfit.AI/Speedfit.AI/`
- Backend: `/Users/cj/Desktop/Speedfit.AI/backend/`
- Models: `/Users/cj/Desktop/Speedfit.AI/backend/models/best.pt`
- IP Helper: `/Users/cj/Desktop/Speedfit.AI/get_ip.sh`

## How to Run
1. **Setup Hotspot**: Turn on Personal Hotspot on phone, connect MacBook
2. **Backend**: `cd backend && uvicorn main:app --host 0.0.0.0 --port 8000 --reload`
3. **Check IP**: `./get_ip.sh` (update iOS app if needed)
4. **iOS**: Open Speedfit.AI.xcodeproj in Xcode and run on device

## Recent Major Updates
- **Simplified codebase**: Removed ~50 lines of unused velocity calculations
- **Per-rep focus**: Only tracks individual rep speeds and session averages
- **Better UI**: Clean session results with individual rep breakdown
- **Performance boost**: Frame skipping optimization for faster processing
- **Network stability**: Hotspot-based connectivity eliminates IP address issues
