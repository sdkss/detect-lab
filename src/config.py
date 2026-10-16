"""Decoy config module. Pulls from env — no real secrets here."""
import os

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///lab.db")
API_BASE = os.getenv("API_BASE", "https://api.example.com")
FEATURE_FLAGS = {"beta_ui": False, "new_pipeline": True}
