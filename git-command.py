#!/usr/bin/env python3
import subprocess
import sys
import time
from pathlib import Path
from datetime import datetime
from collections import defaultdict
from typing import Dict, List, Tuple, Optional


class GitAutomation:
    def __init__(self, repo_path: str = "."):
        self.repo_path = Path(repo_path).absolute()
        if not self._is_git_repo():
            print(f"⚠️ Warning: {self.repo_path} is not a git repository.")

    def _is_git_repo(self) -> bool:
        curr = self.repo_path
        while curr != curr.parent:
            if (curr / ".git").exists():
                return True
            curr = curr.parent
        return False

    def run_command(self, cmd: List[str], timeout: int = 60) -> Tuple[bool, str, str]:
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
                timeout=timeout,
                cwd=self.repo_path,
            )
            return result.returncode == 0, result.stdout or "", result.stderr or ""
        except Exception as e:
            return False, "", str(e)

    def parse_status_line(self, line: str) -> Tuple[str, str]:
        """Improved parsing for porcelain status codes and renames."""
        status = line[:2]
        filepath = line[3:].strip()

        # If renamed, git shows "old_path -> new_path"
        if " -> " in filepath:
            filepath = filepath.split(" -> ")[-1]

        # Strip git's internal quotes if filename has spaces
        filepath = filepath.strip('"')
        return status, filepath

    def get_current_branch(self) -> str:
        success, stdout, _ = self.run_command(["git", "branch", "--show-current"])
        return stdout.strip() if success and stdout.strip() else "main"

    def get_status(self) -> Dict[str, List[str]]:
        success, stdout, stderr = self.run_command(["git", "status", "--porcelain"])
        if not success:
            return {}

        changes = {
            "added": [],
            "modified": [],
            "deleted": [],
            "renamed": [],
            "untracked": [],
        }

        for line in stdout.splitlines():
            if not line:
                continue
            status, filepath = self.parse_status_line(line)

            if "??" in status:
                changes["untracked"].append(filepath)
            elif "A" in status:
                changes["added"].append(filepath)
            elif "M" in status or " M" in status:
                changes["modified"].append(filepath)
            elif "D" in status or " D" in status:
                changes["deleted"].append(filepath)
            elif "R" in status:
                changes["renamed"].append(filepath)
        return changes

    def generate_commit_message(self, changes: Dict[str, List[str]]) -> str:
        all_files = [f for sublist in changes.values() for f in sublist]
        if not all_files:
            return "chore: minor updates"

        # Determine Prefix
        is_fix = any("fix" in f.lower() or "bug" in f.lower() for f in all_files)
        total_added = len(changes["added"]) + len(changes["untracked"])

        if is_fix:
            prefix, action = "fix", "Fix"
        elif any(f.endswith(".md") for f in all_files):
            prefix, action = "docs", "Update"
        elif total_added > len(changes["modified"]):
            prefix, action = "feat", "Add"
        else:
            prefix, action = "refactor", "Update"

        # Build short summary
        scope = self.repo_path.name
        primary_file = Path(all_files[0]).name
        header = f"{prefix}({scope}): {action} {primary_file}"
        if len(all_files) > 1:
            header += f" and {len(all_files) - 1} others"

        # Build Body
        body = ["\nChanges summary:"]
        for category, files in changes.items():
            if files:
                body.append(f"- {category.capitalize()}: {len(files)} files")
                for f in files[:3]:  # Show first 3 files
                    body.append(f"  • {f}")
                if len(files) > 3:
                    body.append(f"  • ... and {len(files) - 3} more")

        return header + "\n" + "\n".join(body)

    def stage_and_commit(self, message: str) -> bool:
        # 1. Stage
        self.run_command(["git", "add", "."])

        # 2. Check if there's actually anything to commit
        success, _, _ = self.run_command(["git", "diff", "--cached", "--quiet"])
        if success:  # Exit code 0 means NO changes
            print("✨ No changes to commit.")
            return False

        # 3. Commit
        print(f"📝 Executing commit with message:")
        print(f"{'=' * 40}\n{message}\n{'=' * 40}")
        success, _, stderr = self.run_command(["git", "commit", "-m", message])
        if not success:
            print(f"❌ Commit failed: {stderr}")
            return False
        return True

    def push_changes(self) -> bool:
        print("⏳ Waiting 10 seconds before pushing...")
        time.sleep(60)
        print("🚀 Pushing to remote...")
        success, stdout, stderr = self.run_command(["git", "push"])
        if success:
            print("✅ Push successful")
            return True

        # Handle missing upstream
        if "no upstream branch" in stderr:
            branch = self.get_current_branch()
            print(f"⚠️ Setting upstream for {branch}...")
            success, _, _ = self.run_command(
                ["git", "push", "--set-upstream", "origin", branch]
            )
            return success

        print(f"❌ Push failed: {stderr}")
        return False

    def run(self, custom_message: Optional[str] = None, dry_run: bool = False) -> str:
        changes = self.get_status()
        if not any(changes.values()):
            return "No changes"

        commit_message = (
            custom_message if custom_message else self.generate_commit_message(changes)
        )

        if dry_run:
            print(f"🔍 [DRY RUN] Generated Commit Message:")
            print(f"{'=' * 40}\n{commit_message}\n{'=' * 40}")
            return "Dry run completed"

        if self.stage_and_commit(commit_message):
            if self.push_changes():
                return "Success"
        return "Nothing to push"

    def watch(self):
        print("👀 Watching for changes... (Ctrl+C to stop)")
        try:
            while True:
                changes = self.get_status()
                if any(changes.values()):
                    print(
                        f"\n⚡ Changes detected in [{self.repo_path.name}] at {datetime.now().strftime('%H:%M:%S')}"
                    )
                    time.sleep(2)  # Debounce
                    self.run()
                time.sleep(10)
        except KeyboardInterrupt:
            print("\n👋 Stopped.")


def main():
    dry_run = "--dry-run" in sys.argv
    watch_mode = "--watch" in sys.argv
    msg = next((arg for arg in sys.argv[1:] if not arg.startswith("-")), None)

    git_auto = GitAutomation()
    if watch_mode:
        git_auto.watch()
    else:
        git_auto.run(custom_message=msg, dry_run=dry_run)


if __name__ == "__main__":
    main()
