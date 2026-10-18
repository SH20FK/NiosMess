"""OS resource ownership at HTTP cancellation boundaries, using real handles."""
import asyncio
import os
import threading

import pytest

from nios_protocol.blobs import _acquire_io, _file_lease, _io, _release_lease


async def reached(event):
    assert await asyncio.to_thread(event.wait, 3), "worker barrier was not reached"


@pytest.mark.asyncio
@pytest.mark.parametrize("kind", ["lease", "descriptor", "file"])
async def test_cancelled_acquisition_disposes_real_resource_and_allows_retry(tmp_path, kind):
    acquired, return_resource = threading.Event(), threading.Event()
    cleanup_started, finish_cleanup = threading.Event(), threading.Event()
    holder, cleanups = [], []
    file_path = tmp_path / "ciphertext.nsc"
    file_path.write_bytes(b"ciphertext")

    def acquire():
        if kind == "lease":
            resource = _file_lease(tmp_path, "a" * 64)
        elif kind == "descriptor":
            resource = os.open(file_path, os.O_RDONLY)
        else:
            resource = file_path.open("rb", 0)
        holder.append(resource)
        acquired.set()
        assert return_resource.wait(3), "acquisition return barrier timed out"
        return resource

    def cleanup(resource):
        cleanup_started.set()
        assert finish_cleanup.wait(3), "cleanup barrier timed out"
        cleanups.append(resource)
        if kind == "lease":
            _release_lease(resource)
        elif kind == "descriptor":
            os.close(resource)
        else:
            resource.close()

    task = asyncio.create_task(_acquire_io(acquire, cleanup))
    try:
        await reached(acquired)
        task.cancel()
        await asyncio.sleep(0)
        # A second cancellation must not cancel the to_thread Future while its
        # acquisition still owns an OS resource and has not returned it.
        task.cancel()
        return_resource.set()
        await reached(cleanup_started)
        task.cancel()
        await asyncio.sleep(0)
        assert not task.done(), "cancellation skipped the cleanup worker"
        finish_cleanup.set()
        with pytest.raises(asyncio.CancelledError):
            await asyncio.wait_for(task, 3)
        assert len(cleanups) == 1 and cleanups[0] is holder[0]
        if kind == "descriptor":
            with pytest.raises(OSError):
                os.fstat(holder[0])
        else:
            assert holder[0].closed
        if kind == "lease":
            # This was 503 with the old generic _io acquisition wrapper.
            next_lease = _file_lease(tmp_path, "a" * 64)
            _release_lease(next_lease)
        else:
            with file_path.open("rb") as retry:
                assert retry.read() == b"ciphertext"
    finally:
        return_resource.set()
        finish_cleanup.set()
        if not task.done():
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass


@pytest.mark.asyncio
async def test_normal_acquisition_transfers_ownership_without_premature_cleanup(tmp_path):
    path = tmp_path / "ciphertext.nsc"
    path.write_bytes(b"ciphertext")
    cleanups = []

    def close(handle):
        cleanups.append(handle)
        handle.close()

    handle = await _acquire_io(path.open, close, "rb", 0)
    try:
        assert not handle.closed
        assert handle.read() == b"ciphertext"
        assert cleanups == []
    finally:
        handle.close()


@pytest.mark.asyncio
async def test_repeated_cancel_waits_for_ordinary_io_before_owner_can_close_file(tmp_path):
    path = tmp_path / "ciphertext.nsc"
    entered, release, finished = threading.Event(), threading.Event(), threading.Event()
    with path.open("wb", buffering=0) as handle:
        def write():
            entered.set()
            assert release.wait(3)
            handle.write(b"complete worker write")
            finished.set()
        task = asyncio.create_task(_io(write))
        try:
            await reached(entered)
            task.cancel()
            await asyncio.sleep(0)
            task.cancel()
            await asyncio.sleep(0)
            assert not task.done(), "owner could close while thread still writes"
            release.set()
            with pytest.raises(asyncio.CancelledError):
                await task
            assert finished.is_set()
        finally:
            release.set()
            if not task.done():
                try:
                    await task
                except asyncio.CancelledError:
                    pass
    assert path.read_bytes() == b"complete worker write"
