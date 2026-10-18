"""Cold-start an existing release APK on a disposable Android emulator.

Collection deliberately exits successfully after recording application failures.
Run ``assert`` after uploading the evidence to turn them into a CI failure. No
login, credentials, or production account is involved. Every adb operation uses
an explicit emulator serial; this tool refuses to clear a physical device.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import time
import traceback
import xml.etree.ElementTree as ET


PACKAGE = "com.niosmess.pulse"
ACTIVITY = f"{PACKAGE}/.MainActivity"
LOG_LINE = re.compile(
    r"^\d\d-\d\d\s+\S+\s+(\d+)\s+\d+\s+([VDIWEF])\s+([^:]+):\s?(.*)$"
)
# EGL_SUCCESS is a successful driver probe despite its E/flutter log level.
# Preserve it as evidence and still require an actual visible Flutter frame.
# Every other EGL/Impeller error remains fatal to this smoke check.
EGL_SUCCESS_PROBE = re.compile(
    r"\[ERROR:flutter/impeller/toolkit/egl/egl\.cc\(\d+\)\] "
    r"EGL Error: Success \(12288\) in "
    r"(?:\.\./)*flutter/impeller/toolkit/egl/display\.cc:\d+"
)


def screenshot_content(path: Path) -> dict:
    from PIL import Image, ImageStat

    with Image.open(path) as image:
        image = image.convert("RGB")
        width, height = image.size
        # Ignore navigation/status bars: they can make a blank app look alive.
        image = image.crop(
            (int(width * 0.06), int(height * 0.10),
             int(width * 0.94), int(height * 0.90))
        ).resize((128, 128))
        stddev = max(ImageStat.Stat(image).stddev)
        quantized = image.point(lambda value: value // 16 * 16)
        colors = quantized.getcolors(128 * 128) or []
        dominant_fraction = max((count for count, _ in colors), default=0) / 16384
        return {
            "stddev": round(stddev, 3),
            "dominant_fraction": round(dominant_fraction, 5),
            "nonblank": stddev >= 2 and dominant_fraction < 0.997,
        }


def app_semantics(xml: str) -> list[str]:
    try:
        root = ET.fromstring(xml)
    except ET.ParseError:
        return []
    return sorted({
        value.strip()
        for node in root.iter("node")
        if node.get("package") == PACKAGE
        for value in (node.get("text", ""), node.get("content-desc", ""))
        if value.strip()
    })


def startup_errors(log: str, pids: set[str]) -> list[str]:
    errors = []
    for line in log.splitlines():
        match = LOG_LINE.match(line)
        if match:
            pid, level, tag, message = match.groups()
            if (level == "E" and tag.strip() == "flutter"
                    and EGL_SUCCESS_PROBE.fullmatch(message)):
                continue
            if pid in pids and (
                (tag.strip() == "flutter" and level in {"E", "F"})
                or (level == "F")
                or any(marker in message for marker in (
                    "FLUTTER_ERROR_EXCEPTION:", "PLATFORM_ERROR:",
                    "Unhandled Exception:", "Dart Error:", "FATAL EXCEPTION:",
                ))
                or re.search(r"\[ERROR\]\s+(?:zone|flutter|platform|bootstrap|startup):", message)
            ):
                errors.append(line)
        if PACKAGE in line and any(marker in line for marker in (
            "Process:", "Fatal signal", "ANR in ", ">>>", "am_crash", "am_anr",
        )):
            errors.append(line)
    return list(dict.fromkeys(errors))


def renderer_diagnostics(log: str, pids: set[str]) -> list[str]:
    diagnostics = []
    for line in log.splitlines():
        match = LOG_LINE.match(line)
        if match:
            pid, level, tag, message = match.groups()
            if (pid in pids and level == "E" and tag.strip() == "flutter"
                    and EGL_SUCCESS_PROBE.fullmatch(message)):
                diagnostics.append(line)
    return list(dict.fromkeys(diagnostics))


def bootstrap_completed(log: str, pids: set[str]) -> bool:
    for line in log.splitlines():
        match = LOG_LINE.match(line)
        if match:
            pid, level, tag, message = match.groups()
            if (pid in pids and level == "I" and tag.strip() == "flutter"
                    and re.search(r"\[INFO\] bootstrap: Application started$", message)):
                return True
    return False


def first_frame_evidence(log: str, gfx: str, surface_latency: str,
                         semantics: list[str]) -> dict:
    displayed = bool(re.search(r"Displayed\s+" + re.escape(ACTIVITY), log))
    frame_count = re.search(r"Total frames rendered:\s*(\d+)", gfx)
    surface_frames = 0
    for line in surface_latency.splitlines():
        columns = line.split()
        if len(columns) == 3 and all(column.isdigit() for column in columns):
            if 0 < int(columns[1]) < 9223372036854775807:
                surface_frames += 1
    return {
        "android_displayed": displayed,
        "gfx_frames": int(frame_count.group(1)) if frame_count else 0,
        "surface_presented_frames": surface_frames,
        "semantics_labels": semantics,
        "rendered": displayed or bool(semantics) or surface_frames > 0,
    }


class Collector:
    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.output = args.output
        self.output.mkdir(parents=True, exist_ok=True)
        self.pids: set[str] = set()
        self.report = {
            "package": PACKAGE,
            "serial": args.serial,
            "source_run_id": os.environ.get("SOURCE_RUN_ID", ""),
            "tool_commit": os.environ.get("GITHUB_SHA", ""),
            "passed": False,
            "samples": [],
            "collection_errors": [],
        }

    def write(self, name: str, value: str) -> str:
        (self.output / name).write_text(value, encoding="utf-8")
        return value

    def adb(self, *arguments: str, timeout: float = 20,
            required: bool = False) -> str:
        try:
            completed = subprocess.run(
                ["adb", "-s", self.args.serial, *arguments],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                timeout=timeout, check=False,
            )
            output = completed.stdout.decode("utf-8", errors="replace")
            if required and completed.returncode:
                raise RuntimeError(f"adb {' '.join(arguments[:3])}: {output}")
            return output
        except subprocess.TimeoutExpired as error:
            if required:
                raise RuntimeError(f"adb command timed out: {arguments[:3]}") from error
            return f"COMMAND TIMED OUT: {' '.join(arguments)}\n"

    def snapshot(self, label: str) -> dict:
        pid = " ".join(value for value in self.adb("shell", "pidof", PACKAGE).split()
                       if value.isdigit())
        self.pids.update(value for value in pid.split() if value.isdigit())
        window = self.write(f"{label}-window.txt", self.adb("shell", "dumpsys", "window"))
        gfx = self.write(f"{label}-gfx.txt", self.adb("shell", "dumpsys", "gfxinfo", PACKAGE, "framestats"))
        surfaces = self.write(f"{label}-surfaces.txt", self.adb("shell", "dumpsys", "SurfaceFlinger", "--list"))
        latency = ""
        for surface in surfaces.splitlines():
            if PACKAGE in surface and "SurfaceView" in surface:
                latency += self.adb("shell", "dumpsys", "SurfaceFlinger", "--latency", shlex.quote(surface))
        self.write(f"{label}-surface-latency.txt", latency)
        self.write(f"{label}-uiautomator.txt", self.adb(
            "shell", "uiautomator", "dump", "--compressed", "/sdcard/nios-startup.xml", timeout=12))
        xml = self.write(f"{label}-ui.xml", self.adb("shell", "cat", "/sdcard/nios-startup.xml"))
        # exec-out preserves PNG bytes; shell text decoding corrupts screenshots.
        png = subprocess.run(
            ["adb", "-s", self.args.serial, "exec-out", "screencap", "-p"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15, check=True,
        ).stdout
        screenshot = self.output / f"{label}.png"
        screenshot.write_bytes(png)
        log = self.write("logcat.txt", self.adb("logcat", "-d", "-v", "threadtime", "-b", "all"))
        focus = "\n".join(line for line in window.splitlines()
                          if "mCurrentFocus=" in line or "mFocusedApp=" in line)
        return {
            "label": label,
            "pid": pid,
            "focus": focus,
            "foreground": PACKAGE in focus,
            "bootstrap_completed": bootstrap_completed(log, set(pid.split())),
            "first_frame": first_frame_evidence(log, gfx, latency, app_semantics(xml)),
            "screenshot": screenshot_content(screenshot),
            "errors": startup_errors(log, self.pids),
            "renderer_diagnostics": renderer_diagnostics(log, self.pids),
        }

    def run(self) -> None:
        if not re.fullmatch(r"emulator-\d+", self.args.serial):
            raise ValueError("Only an explicit emulator-NNNN serial is allowed")
        if self.adb("shell", "getprop", "ro.kernel.qemu", required=True).strip() != "1":
            raise ValueError("Refusing to clear application data outside an emulator")
        matches = list(self.args.apk_dir.rglob("niosmess-x86_64.apk"))
        if len(matches) != 1:
            raise ValueError(f"Expected one niosmess-x86_64.apk, found {len(matches)}")
        apk = matches[0]
        with apk.open("rb") as stream:
            self.report["apk_sha256"] = hashlib.file_digest(stream, "sha256").hexdigest()
        self.report["apk"] = str(apk)
        self.write("device.txt", self.adb("shell", "getprop"))
        self.write("install.txt", self.adb("install", "-r", "-g", str(apk), timeout=120, required=True))
        self.write("package.txt", self.adb("shell", "dumpsys", "package", PACKAGE))
        self.adb("shell", "am", "force-stop", PACKAGE, required=True)
        self.write("clear.txt", self.adb("shell", "pm", "clear", PACKAGE, required=True))
        self.adb("shell", "input", "keyevent", "KEYCODE_WAKEUP")
        self.adb("shell", "wm", "dismiss-keyguard")
        self.adb("logcat", "-c", "-b", "all", required=True)
        start = time.monotonic()
        self.write("launch.txt", self.adb("shell", "am", "start", "-n", ACTIVITY, required=True))
        deadline = start + self.args.timeout
        next_snapshot = start + 8
        success_since = None
        while time.monotonic() < deadline:
            pid = self.adb("shell", "pidof", PACKAGE, timeout=5).strip()
            self.pids.update(value for value in pid.split() if value.isdigit())
            if time.monotonic() >= next_snapshot:
                sample = self.snapshot(f"{int(time.monotonic() - start):03d}s")
                sample["elapsed_seconds"] = round(time.monotonic() - start, 2)
                self.report["samples"].append(sample)
                visible = (bool(sample["pid"]) and sample["foreground"]
                           and sample["bootstrap_completed"]
                           and sample["first_frame"]["rendered"]
                           and sample["screenshot"]["nonblank"] and not sample["errors"])
                print(json.dumps(sample, ensure_ascii=False), flush=True)
                if visible:
                    success_since = success_since or time.monotonic()
                    if time.monotonic() - success_since >= 10:
                        self.report["passed"] = True
                        break
                else:
                    success_since = None
                if sample["errors"]:
                    break
                next_snapshot = time.monotonic() + 10
            time.sleep(1)
        self.report["elapsed_seconds"] = round(time.monotonic() - start, 2)
        self.report["observed_pids"] = sorted(self.pids)

    def collect(self) -> None:
        try:
            self.run()
        except Exception:
            self.report["collection_errors"].append(traceback.format_exc())
        finally:
            # Still collect a final log/diagnostic when installation or launch failed.
            if re.fullmatch(r"emulator-\d+", self.args.serial):
                for name, command in {
                    "logcat.txt": ("logcat", "-d", "-v", "threadtime", "-b", "all"),
                    "activity.txt": ("shell", "dumpsys", "activity", "activities"),
                    "processes.txt": ("shell", "ps", "-A"),
                    "meminfo.txt": ("shell", "dumpsys", "meminfo", PACKAGE),
                }.items():
                    try:
                        self.write(name, self.adb(*command))
                    except Exception:
                        self.report["collection_errors"].append(traceback.format_exc())
                try:
                    completed = subprocess.run(
                        ["adb", "-s", self.args.serial, "exec-out", "screencap", "-p"],
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                        timeout=15, check=True,
                    )
                    (self.output / "final.png").write_bytes(completed.stdout)
                except Exception:
                    self.report["collection_errors"].append(traceback.format_exc())
            self.report["passed"] = self.report["passed"] and not self.report["collection_errors"]
            self.write("report.json", json.dumps(self.report, indent=2, ensure_ascii=False) + "\n")
            print(f"Evidence saved to {self.output}; launch passed={self.report['passed']}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    collect = subparsers.add_parser("collect")
    collect.add_argument("--apk-dir", type=Path, required=True)
    collect.add_argument("--output", type=Path, required=True)
    collect.add_argument("--serial", default="emulator-5554")
    collect.add_argument("--timeout", type=int, default=90)
    check = subparsers.add_parser("assert")
    check.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "collect":
        Collector(args).collect()
        return 0
    report_path = args.output / "report.json"
    if not report_path.exists():
        print("::error::Cold-start evidence is missing; inspect emulator/artifact setup logs")
        return 1
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if not report.get("passed"):
        print("::error::Android cold start failed: inspect report.json, logcat.txt and screenshots")
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 1
    print("Android release cold start passed: process alive, foreground first frame visible, no fatal errors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
