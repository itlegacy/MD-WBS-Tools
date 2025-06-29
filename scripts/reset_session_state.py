import os
import sys
import argparse

def reset_session_state():
    parser = argparse.ArgumentParser(description='Remove the Gemini session state JSON file.')
    parser.add_argument('--target_path', type=str, required=True, help='Path to the session state JSON file to remove.')

    args = parser.parse_args()
    target_path = args.target_path

    if os.path.exists(target_path):
        try:
            os.remove(target_path)
            print(f"Session state file removed: {target_path}")
        except OSError as e:
            print(f"Error removing session state file: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print(f"No session state file found at: {target_path}")

if __name__ == "__main__":
    reset_session_state()
