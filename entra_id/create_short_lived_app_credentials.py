#!/usr/bin/env python

from typing import Optional

import os
import re
import sys

def is_uuid(s: str):
    """
    Check if the given string is a valid UUID.

    Args:
    s (str): String to check for UUID.

    Returns:
    bool: True if string is a valid UUID, False otherwise.
    """
    # A UUID is in the form of 8-4-4-4-12 hexadecimal digits.
    regex_uuid = re.compile(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
    return bool(regex_uuid.match(s))

def get_app_info():
    app_id_or_name = input('Enter the application ID or name: ')

    if is_uuid(app_id_or_name):
        app_id = app_id_or_name

        args = ['ad', 'app', 'show', f'--id={app_id}']
        rsp_file = os.path.join(tmp_dir, f'ad-app-show-rsp.json')
        az(*args, file=rsp_file)
        with open(rsp_file) as f:
            j = json.load(f)
            app_name = j['displayName']

        yes_or_no = input(f"A short-lived secret will be created for '{app_name}'. Continue? (Y/n): ")
        if len(yes_or_no) > 0 and yes_or_no.lower() != 'y':
            print('Cancelled.')
            raise
    else:
        app_name = app_id_or_name

        args = ['ad', 'app', 'list', f'--display-name={app_name}']
        rsp_file = os.path.join(tmp_dir, f'ad-app-list-rsp.json')
        az(*args, file=rsp_file)
        with open(rsp_file) as f:
            j = json.load(f)
            app_id = j['appId']

    if not app_name.startswith('Dev.'):
        yes_or_no = input(f"'{app_name}' doesn't seem like a development app. Do you really want to create a short-lived secret for it? (y/N): ")
        if yes_or_no.lower() != 'y':
            print('Cancelled.')
            raise

    return app_id, app_name

def main():
    print("This script is not ready yet. Please use 'create_short_lived_app_credentials.sh' for now")
    return

    if len(sys.argv) != 1:
        print_usage(f'ERROR: Too many arguments.')
        sys.exit(1)

    app_id, app_name = get_app_info()
    print(f'app_id = {app_id}')
    print(f'app_name = {app_name}')

class AZError(Exception):
    pass

def az(*args, file='', **popen_kwargs) -> Optional[str]:
    args = list(args)
    args.insert(0, '/usr/bin/az')
    popen_kwargs['stdout'] = subprocess.PIPE
    popen_kwargs['stderr'] = subprocess.PIPE
    proc = subprocess.Popen(args, **popen_kwargs)
    (stdout, stderr) = proc.communicate()
    str_stdout = stdout.decode(errors='replace')
    str_stderr = stderr.decode(errors='replace')
    if proc.returncode != 0:
        raise AZError(' '.join(args), str_stderr)

    if file != '':
        with open(file, 'w') as f:
            f.write(str_stdout.rstrip('\n'))
    else:
        return str_stdout.rstrip('\n')

def print_usage(error_msg: str):
    print(error_msg)
    print()
    print('Usage:')
    print(f'    {sys.argv[0]}')

if __name__ == '__main__':
    main()
