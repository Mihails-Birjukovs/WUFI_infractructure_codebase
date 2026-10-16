import numpy as np
import pytest

from python_tools.hodmd_mode_catalog import (
    catalog_single_fit,normalize_pair,SINGLE_SENSOR_TARGETS
)


def test_full_catalog_positive_frequency_sine_mode():
    hours=np.arange(400)
    x=np.vstack([
        np.sin(2*np.pi*hours/24.)+.005*np.sin(hours*.4),
        np.cos(2*np.pi*hours/24.)+.005*np.cos(hours*.31),
    ])
    a,b=normalize_pair(x,x+.1)
    np.testing.assert_allclose(a.mean(axis=1),0,atol=1e-12)
    np.testing.assert_allclose(b.mean(axis=1),0,atol=1e-12)
    result=catalog_single_fit(a,delay=12,rank=4)
    assert len(result)>0
    assert all(e["period_h"]>0 for e in result)
    assert all(np.isfinite(e["amplitude"]) for e in result)
    assert any(abs(e["period_h"]-24)<.3 for e in result)
    assert all(e["loading_0"]>=0 and e["loading_1"]>=0 for e in result)


def test_strict_embedding_exclusion():
    assert len(SINGLE_SENSOR_TARGETS)==3
    rng=np.random.default_rng(3)
    x=rng.normal(size=(2,300))
    with pytest.raises(ValueError,match="embedding dimension"):
        catalog_single_fit(x,12,24)
