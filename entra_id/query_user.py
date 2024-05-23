#!/usr/bin/env python

import sys
import subprocess
import re
import json

def is_uuid(value):
    """Check if value is a valid UUID."""
    pattern = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', re.IGNORECASE)
    return bool(pattern.match(value))

def query_user_by_object_id(uuid):
    """Query Azure for a user with the specified object ID."""
    try:
        result = subprocess.run(['az', 'ad', 'user', 'show', '--id', uuid], capture_output=True, text=True)
        if result.returncode == 0:
            user_info = json.loads(result.stdout)
            print(json.dumps(user_info, indent=2))
        else:
            print("Error retrieving user:", result.stderr)
    except Exception as e:
        print("Failed to query user:", str(e))

def query_user_by_name(name):
    """Query Azure for users with the specified name."""
    try:
        result = subprocess.run(['az', 'ad', 'user', 'list', '--filter', f"startswith(displayName,'{name}')"], capture_output=True, text=True)
        if result.returncode == 0:
            users_info = json.loads(result.stdout)
            if users_info:
                print(json.dumps(users_info, indent=2))
            else:
                print("No users found with the specified name.")
        else:
            print("Error retrieving users:", result.stderr)
    except Exception as e:
        print("Failed to query users:", str(e))

def main():
    if len(sys.argv) != 2:
        print("Usage: python script.py <UUID or Name>")
        sys.exit(1)

    input_arg = sys.argv[1]

    if is_uuid(input_arg):
        query_user_by_object_id(input_arg)
    else:
        query_user_by_name(input_arg)

if __name__ == "__main__":
    main()
