from pathlib import Path

import pytest

from release_guard import assert_regular_sources, fingerprint


def test_release_guard_detects_unpatched_code_added_files_and_candidate_api(tmp_path):
    (tmp_path / "app").mkdir()
    (tmp_path / "app/unpatched.py").write_text("original")
    (tmp_path / "nios_protocol").mkdir()
    module = tmp_path / "nios_protocol/blobs.py"
    module.write_text("tested")
    original = fingerprint(tmp_path)
    module.write_text("changed after tests")
    assert fingerprint(tmp_path) != original
    module.write_text("tested")
    (tmp_path / "app/unpatched.py").write_text("concurrent fix")
    assert fingerprint(tmp_path) != original
    (tmp_path / "app/unpatched.py").write_text("original")
    (tmp_path / "additional.py").write_text("new import")
    assert fingerprint(tmp_path) != original
    (tmp_path / "additional.py").unlink()
    (tmp_path / "runtime.log").write_text("new log line")
    (tmp_path / "__pycache__").mkdir()
    (tmp_path / "__pycache__/module.pyc").write_bytes(b"compiled")
    assert fingerprint(tmp_path) == original


def test_patch_targets_cannot_follow_shared_production_symlinks(tmp_path):
    outside = tmp_path / "shared.py"
    outside.write_text("live source")
    candidate = tmp_path / "candidate"
    candidate.mkdir()
    link = candidate / "main.py"
    try:
        link.symlink_to(outside)
    except OSError:
        pytest.skip("Windows user lacks symlink creation privilege")
    with pytest.raises(RuntimeError, match="must_be_regular"):
        assert_regular_sources(candidate, ["main.py"])
    first = fingerprint(candidate)
    assert first["main.py"].startswith("link:")
    assert outside.read_text() == "live source"
