#!/usr/bin/env python3
import requests
import os

def test_video_upload():
    # Video file path
    video_path = "/Users/cj/Desktop/video.mp4"
    
    # Check if video exists
    if not os.path.exists(video_path):
        print(f"Video file not found at: {video_path}")
        return
    
    # Backend URL
    backend_url = "http://localhost:8000"
    
    print(f"Testing video upload: {video_path}")
    print(f"File size: {os.path.getsize(video_path) / (1024*1024):.2f} MB")
    
    try:
        # Prepare the multipart form data
        with open(video_path, 'rb') as video_file:
            files = {'video': ('video.mp4', video_file, 'video/mp4')}
            data = {'plate_diameter': '0.45'}  # Standard Olympic plate
            
            print("Uploading video for analysis...")
            response = requests.post(f"{backend_url}/analyze-lift/", files=files, data=data)
            
            if response.status_code == 200:
                # Save the processed video
                output_path = "/Users/cj/Desktop/processed_video.mp4"
                with open(output_path, 'wb') as f:
                    f.write(response.content)
                print(f"✅ Success! Processed video saved to: {output_path}")
                print("You can now open the processed video to see the speed analysis!")
                
            else:
                print(f"❌ Error: {response.status_code}")
                print(f"Response: {response.text}")
                
    except requests.exceptions.ConnectionError:
        print("❌ Could not connect to backend server.")
        print("Make sure the server is running with: uvicorn main:app --host 0.0.0.0 --port 8000 --reload")
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    test_video_upload()