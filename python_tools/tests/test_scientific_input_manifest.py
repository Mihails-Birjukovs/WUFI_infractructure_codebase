import pytest
from python_tools.scientific_input_manifest import (
    build_manifest, check_manifest, file_digest,
)


def test_sha256_manifest_local_and_reverify(tmp_path):
    p=tmp_path/"source_a.txt"
    p.write_bytes(b"repeatable research")
    orig=build_manifest({"sensor_27":p},git_commit="testcommit")
    assert orig["schema"]=="wufi-scientific-inputs-v1"
    assert orig["inputs"]["sensor_27"]["sha256"]==file_digest(p)["sha256"]
    assert "absolute_path" not in orig["inputs"]["sensor_27"]
    assert check_manifest(orig,{"sensor_27":p})["passed"]
    p.write_bytes(b"changed")
    changed=check_manifest(orig,{"sensor_27":p})
    assert not changed["passed"]
    assert "sha256" in changed["mismatches"]["sensor_27"]


def test_manifest_missing_or_unsafe_labels(tmp_path):
    p=tmp_path/"x"
    p.write_bytes(b"data")
    with pytest.raises(ValueError):
        build_manifest({"sensor/private":p})
    with pytest.raises(ValueError,match="Logical source"):
        check_manifest(build_manifest({"x":p}),{"y":p})
