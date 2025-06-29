import json
import sys
import argparse

def load_session_state():
    parser = argparse.ArgumentParser(description='Load and display Gemini session state from a JSON file.')
    parser.add_argument('--input_path', type=str, required=True, help='Path to the session state JSON file.')

    args = parser.parse_args()

    try:
        with open(args.input_path, 'r', encoding='utf-8') as f:
            session_state = json.load(f)

        # JSONデータを整形して表示
        print(json.dumps(session_state, indent=2, ensure_ascii=False))

    except FileNotFoundError:
        print(f"Error: Session state file not found at {args.input_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error decoding session state JSON file: {e}", file=sys.stderr)
        sys.exit(1)
    except IOError as e:
        print(f"Error reading session state file: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    load_session_state()
