#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import platform
import re
import subprocess
import sys
import webbrowser
from urllib.parse import urlencode


AZURE_HTTPS_RE = re.compile(
    r"^https://(?P<host>[^/]+)/(?P<path>.+?)/_git/(?P<repo>[^/]+)/?$"
)
AZURE_SSH_RE = re.compile(
    r"^(?P<user>[^@]+)@(?P<host>ssh\.dev\.azure\.com|vs-ssh\.visualstudio\.com):v3/"
    r"(?P<org>[^/]+)/(?P<project>[^/]+)/(?P<repo>[^/]+)/?$"
)


def is_windows() -> bool:
    return os.name == "nt"


def is_wsl() -> bool:
    if is_windows():
        return False
    release = platform.release().lower()
    version = platform.version().lower()
    return "microsoft" in release or "microsoft" in version


def git(*args: str, check: bool = True) -> str:
    completed = subprocess.run(
        ["git", *args],
        check=check,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def get_current_branch() -> str:
    branch = git("branch", "--show-current")
    if not branch:
        raise RuntimeError("Could not determine the current branch.")
    return branch


def remote_exists(name: str) -> bool:
    completed = subprocess.run(
        ["git", "remote", "get-url", name],
        check=False,
        capture_output=True,
        text=True,
    )
    return completed.returncode == 0


def get_remote_url(name: str) -> str:
    remote = git("remote", "get-url", name)
    if not remote:
        raise RuntimeError(f"Git remote '{name}' has no URL.")
    return remote


def local_branch_exists(name: str) -> bool:
    completed = subprocess.run(
        ["git", "branch", "--list", name],
        check=False,
        capture_output=True,
        text=True,
    )
    return bool(completed.stdout.strip())


def remote_head_branch(remote: str) -> str | None:
    completed = subprocess.run(
        ["git", "symbolic-ref", "--short", f"refs/remotes/{remote}/HEAD"],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        return None
    ref = completed.stdout.strip()
    prefix = f"{remote}/"
    return ref[len(prefix) :] if ref.startswith(prefix) else ref


def guess_target_branch(remote: str) -> str:
    for candidate in ("master", "main"):
        if local_branch_exists(candidate):
            return candidate
    head = remote_head_branch(remote)
    if head:
        return head
    return "master"


def parse_remote(remote_url: str) -> tuple[str, str, str]:
    https_match = AZURE_HTTPS_RE.match(remote_url)
    if https_match:
        host = https_match.group("host")
        path = https_match.group("path")
        repo = https_match.group("repo")
        return host, path, repo

    ssh_match = AZURE_SSH_RE.match(remote_url)
    if ssh_match:
        org = ssh_match.group("org")
        project = ssh_match.group("project")
        repo = ssh_match.group("repo")
        return "dev.azure.com", f"{org}/{project}", repo

    raise RuntimeError(
        "Unsupported remote format. Expected an Azure DevOps HTTPS or "
        "ssh.dev.azure.com/vs-ssh.visualstudio.com SSH remote."
    )


def build_pr_url(remote_url: str, source: str, target: str) -> str:
    host, path, repo = parse_remote(remote_url)
    query = urlencode({"sourceRef": source, "targetRef": target})
    return f"https://{host}/{path}/_git/{repo}/pullrequestcreate?{query}"


def open_url(url: str) -> None:
    if is_wsl():
        subprocess.run(
            ["cmd.exe", "/c", "start", "", url],
            check=False,
            stderr=subprocess.DEVNULL,
        )
        return
    opened = webbrowser.open(url)
    if not opened:
        raise RuntimeError("Failed to open a browser for the PR URL.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Open the Azure DevOps PR creation page for the current git branch."
    )
    parser.add_argument(
        "--remote",
        default="origin",
        help="Git remote to inspect. Defaults to 'origin'.",
    )
    parser.add_argument(
        "--target",
        help="Target branch for the PR. Defaults to master/main/or remote HEAD.",
    )
    parser.add_argument(
        "--source",
        help="Source branch for the PR. Defaults to the current branch.",
    )
    parser.add_argument(
        "--print-only",
        action="store_true",
        help="Print the PR URL without opening a browser.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        if not remote_exists(args.remote):
            raise RuntimeError(f"Git remote '{args.remote}' does not exist.")

        source = args.source or get_current_branch()
        target = args.target or guess_target_branch(args.remote)
        remote_url = get_remote_url(args.remote)
        pr_url = build_pr_url(remote_url, source=source, target=target)

        print(pr_url)
        if not args.print_only:
            open_url(pr_url)
    except FileNotFoundError as exc:
        print(f"Error: required command not found: {exc.filename}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.strip() if exc.stderr else "command failed"
        print(f"Error: git command failed: {stderr}", file=sys.stderr)
        return 1
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
