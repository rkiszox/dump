import sys
from pathlib import Path
from dumper import clean_input_path, dump_path

def interactive_loop():
    while True:
        try:
            print("\nEnter Lua File/Folder Path (or drag & drop here, 'q' to quit):")
            user_input = input("> ").strip()
            if not user_input:
                continue
            if user_input.lower() in ("q", "quit", "exit"):
                print("Exiting.")
                break
            target_path = clean_input_path(user_input)
            dump_path(target_path)
        except (KeyboardInterrupt, EOFError):
            print("\nExiting.")
            break

def main():
    if len(sys.argv) > 1:
        target_str = " ".join(sys.argv[1:])
        target_path = clean_input_path(target_str)
        dump_path(target_path)
    else:
        interactive_loop()

if __name__ == "__main__":
    main()
