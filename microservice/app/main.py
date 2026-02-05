from fastapi import FastAPI, Depends, HTTPException, status, Header
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta
from typing import Optional
from . import models, auth, database

models.Base.metadata.create_all(bind=database.engine)

app = FastAPI()

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.on_event("startup")
def startup_event():
    # Create a test user on startup if not exists
    db = database.SessionLocal()
    user = db.query(models.User).filter(models.User.username == "admin").first()
    if not user:
        # Default user: admin / password123
        fake_hashed_password = auth.get_password_hash("password123")
        db_user = models.User(username="admin", hashed_password=fake_hashed_password)
        db.add(db_user)
        db.commit()
    db.close()

@app.get("/health")
def health_check():
    return {"status": "healthy"}

@app.post("/login")
def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.username == form_data.username).first()
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=auth.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth.create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/verify")
def verify_token(token: Optional[str] = Header(None)):
    # Mimics Verification logic. 
    # Use: curl -H "token: <jwt>" http://localhost:8000/verify
    if not token:
        # Try authorization header if 'token' header is missing
        return {"valid": False, "detail": "Token missing"}
    
    # Strip 'Bearer ' if present
    if token.startswith("Bearer "):
        token = token.split(" ")[1]

    try:
        payload = auth.jwt.decode(token, auth.SECRET_KEY, algorithms=[auth.ALGORITHM])
        return {"valid": True, "user": payload.get("sub")}
    except auth.JWTError as e:
        return {"valid": False, "detail": str(e)}

@app.get("/secure")
def secure_endpoint(authorization: Optional[str] = Header(None)):
     # This endpoint is intended to be protected by Kong.
     # It simply returns data. If Kong is working, this is only reachable with a valid JWT.
     return {
         "message": "This is a secure endpoint protected by Kong!",
         "context": "If you see this, and you didn't provide a token, Kong Bypass is active."
     }

@app.get("/users")
def get_users(db: Session = Depends(get_db)):
    # This endpoint is protected by Kong in main configuration
    users = db.query(models.User).all()
    return [{"id": user.id, "username": user.username, "is_active": user.is_active} for user in users]
