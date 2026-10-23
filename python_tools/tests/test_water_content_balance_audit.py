"""Synthetic-only regression tests; no private REF/HEMP source or dimensions."""
import numpy as np
import pytest

from python_tools import water_content_balance_audit as audit


def synthetic_case(tmp_path):
    xml = tmp_path / "case.xml"
    xml.write_text("""<WUFI1D><Cases><Case><Component><Layers>
    <Layer Index="1"><Scalars><Scalar name="Thickness" unit="m" value="0.02"/></Scalars>
    <Material><Name>SYNTH_A</Name></Material></Layer>
    <Layer Index="2"><Scalars><Scalar name="Thickness" unit="m" value="0.08"/></Scalars>
    <Material><Name>SYNTH_B</Name></Material></Layer>
    </Layers></Component></Case></Cases></WUFI1D>""", encoding="utf-8")
    wxf_dir = tmp_path / "wxf"
    wxf_dir.mkdir()
    values = np.array([[40., 70., 6.4], [42., 73., 6.68], [44., 76., 6.96]])
    asc = tmp_path / "case.asc"
    asc.write_text("\n".join(
        f"2026-01-01T0{i}:00:00 " + " ".join(f"{v:.9g}" for v in row)
        for i, row in enumerate(values)) + "\n", encoding="utf-8")
    layers = [dict(LayerIndex=i + 1, MaterialName=n, ThicknessMetres=d,
                   WaterContentColumn=i + 2)
              for i, (n, d) in enumerate([("SYNTH_A", .02), ("SYNTH_B", .08)])]
    manifest = {"Projects": [{"ProjectBaseName": "Synthetic", "Cases": [
        dict(Layers=layers, ExpectedASCColumnCount=4, TotalWaterContentColumn=4)]}]}

    def reader(path):
        return (values[:, :2].T.copy() if path.name.startswith("layer")
                else values[:, 2][None, :].copy())

    return dict(project="Synthetic", manifest=manifest, xml_file=xml,
                asc_file=asc, wxf_dir=wxf_dir, reader=reader), values


def test_thickness_weighted_balance_and_source_parity(tmp_path):
    kwargs, _ = synthetic_case(tmp_path)
    result = audit.audit_case(**kwargs)
    assert result["hours_checked"] == 3
    assert result["wall_thickness_m"] == pytest.approx(.10)
    assert result["max_absolute_residual_kg_m2"] < 1e-12
    assert result["source_asc_to_wxf_value_parity"] == "exact"


def test_wrong_wxf_total_is_rejected(tmp_path):
    kwargs, values = synthetic_case(tmp_path)
    def wrong_total(path):
        return (values[:, :2].T.copy() if path.name.startswith("layer")
                else (values[:, 2] + .1)[None, :].copy())
    kwargs["reader"] = wrong_total
    with pytest.raises(ValueError, match="WXF differs from original ASC"):
        audit.audit_case(**kwargs)


def test_inconsistent_asc_balance_is_rejected(tmp_path):
    kwargs, values = synthetic_case(tmp_path)
    values[:, 2] += .1
    kwargs["asc_file"].write_text("\n".join(
        f"2026-01-01T0{i}:00:00 " + " ".join(str(v) for v in row)
        for i, row in enumerate(values)) + "\n", encoding="utf-8")
    def updated_reader(path):
        return (values[:, :2].T.copy() if path.name.startswith("layer")
                else values[:, 2][None, :].copy())
    kwargs["reader"] = updated_reader
    with pytest.raises(ValueError, match="residual exceeds serialization tolerance"):
        audit.audit_case(**kwargs)


def test_xml_manifest_thickness_mismatch_is_rejected(tmp_path):
    kwargs, _ = synthetic_case(tmp_path)
    kwargs["manifest"]["Projects"][0]["Cases"][0]["Layers"][0]["ThicknessMetres"] = .03
    with pytest.raises(ValueError, match="XML/manifest"):
        audit.audit_case(**kwargs)


def test_nonhourly_asc_time_is_rejected(tmp_path):
    kwargs, _ = synthetic_case(tmp_path)
    source = kwargs["asc_file"].read_text(encoding="utf-8")
    kwargs["asc_file"].write_text(
        source.replace("2026-01-01T01:00:00", "2026-01-01T04:00:00"),
        encoding="utf-8")
    with pytest.raises(ValueError, match="ASC timeline"):
        audit.audit_case(**kwargs)
