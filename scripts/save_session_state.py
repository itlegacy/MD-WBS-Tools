import json
import sys
import argparse
from datetime import datetime

def save_session_state():
    parser = argparse.ArgumentParser(description='Save Gemini session state to a JSON file.')
    parser.add_argument('--task_description', type=str, default='', help='Description of the current task.')
    parser.add_argument('--current_plan', type=str, default='', help='Current plan of the agent.')
    parser.add_argument('--completed_steps', type=str, default='[]', help='JSON array string of completed steps.')
    parser.add_argument('--pending_steps', type=str, default='[]', help='JSON array string of pending steps.')
    parser.add_argument('--last_tool_call', type=str, default='{}', help='JSON object string of the last tool call.')
    parser.add_argument('--context_files', type=str, default='[]', help='JSON array string of relevant file paths.')
    parser.add_argument('--output_path', type=str, required=True, help='Path to save the session state JSON file.')

    args = parser.parse_args()

    try:
        completed_steps = json.loads(args.completed_steps) if args.completed_steps else []
        pending_steps = json.loads(args.pending_steps) if args.pending_steps else []
        last_tool_call = json.loads(args.last_tool_call) if args.last_tool_call else {}
        context_files = json.loads(args.context_files) if args.context_files else []
    except json.JSONDecodeError as e:
        print(f"Error decoding JSON arguments: {e}", file=sys.stderr)
        sys.exit(1)

    session_state = {
        "task_description": args.task_description,
        "current_plan": args.current_plan,
        "completed_steps": completed_steps,
        "pending_steps": pending_steps,
        "last_tool_call": last_tool_call,
        "context_files": context_files,
        "timestamp": datetime.utcnow().isoformat() + 'Z'
    }

    try:
        with open(args.output_path, 'w', encoding='utf-8') as f:
            json.dump(session_state, f, indent=2, ensure_ascii=False)
        print(f"Session state saved to: {args.output_path}")
    except IOError as e:
        print(f"Error writing session state file: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    save_session_state()
