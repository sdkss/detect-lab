"""Decoy application module for the detection lab. Harmless filler to add repo volume."""
import os


def load_config():
    return {
        "env": os.getenv("APP_ENV", "dev"),
        "debug": os.getenv("DEBUG", "false") == "true",
    }


def main():
    cfg = load_config()
    print(f"lab app starting in {cfg['env']} mode")


if __name__ == "__main__":
    main()
