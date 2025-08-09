from fastapi import HTTPException, Depends, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from supabase import create_client, Client
import os
from dotenv import load_dotenv
from typing import Optional, Dict, Any
import logging

# Load environment variables
load_dotenv()

# Supabase configuration
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
JWT_SECRET = os.getenv("JWT_SECRET")

if not all([SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, JWT_SECRET]):
    raise ValueError("Missing required environment variables for Supabase authentication")

# Initialize Supabase client
supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

# Security scheme
security = HTTPBearer()

class AuthError(Exception):
    def __init__(self, error: str, status_code: int):
        self.error = error
        self.status_code = status_code

def verify_jwt_token(token: str) -> Dict[str, Any]:
    """Verify JWT token and return payload"""
    try:
        # Decode the JWT token
        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated"
        )
        return payload
    except JWTError as e:
        logging.error(f"JWT verification error: {e}")
        raise AuthError("Invalid token", 401)

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> Dict[str, Any]:
    """
    Dependency to get current authenticated user
    """
    try:
        token = credentials.credentials
        payload = verify_jwt_token(token)
        
        # Extract user ID from payload
        user_id = payload.get("sub")
        if not user_id:
            raise AuthError("Invalid token payload", 401)
        
        # Verify user exists in Supabase
        try:
            response = supabase.table("profiles").select("*").eq("id", user_id).execute()
            
            if not response.data:
                raise AuthError("User not found", 404)
            
            user_data = response.data[0]
            return {
                "id": user_id,
                "email": user_data.get("email"),
                "full_name": user_data.get("full_name")
            }
            
        except Exception as db_error:
            logging.error(f"Database error: {db_error}")
            raise AuthError("Database error", 500)
        
    except AuthError:
        raise
    except Exception as e:
        logging.error(f"Authentication error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_current_user_optional(
    request: Request
) -> Optional[Dict[str, Any]]:
    """
    Optional dependency to get current user (doesn't raise exception if not authenticated)
    """
    try:
        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            return None
            
        token = auth_header.split(" ")[1]
        payload = verify_jwt_token(token)
        
        user_id = payload.get("sub")
        if not user_id:
            return None
        
        response = supabase.table("profiles").select("*").eq("id", user_id).execute()
        
        if not response.data:
            return None
        
        user_data = response.data[0]
        return {
            "id": user_id,
            "email": user_data.get("email"),
            "full_name": user_data.get("full_name")
        }
        
    except Exception as e:
        logging.error(f"Optional auth error: {e}")
        return None

# Middleware exception handler
def auth_exception_handler(request: Request, exc: AuthError):
    return HTTPException(
        status_code=exc.status_code,
        detail=exc.error
    )