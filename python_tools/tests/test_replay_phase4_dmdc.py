import numpy as np
import pytest
from python_tools.replay_phase4_dmdc import normalize_states, normalized_forcing


def test_common_experimental_scaling_and_separate_centering():
    exp = np.array([[1., 3.], [2., 4.], [4., 8.], [8., 9.]])
    model = exp * np.array([.5, 2.]) + np.array([30., -5.])
    a,b=normalize_states(exp,model)
    np.testing.assert_allclose(a.mean(axis=0),[0,0],atol=1e-12)
    np.testing.assert_allclose(b.mean(axis=0),[0,0],atol=1e-12)
    np.testing.assert_allclose(np.std(a,axis=0),[1,1],atol=1e-12)
    np.testing.assert_allclose(np.std(b,axis=0),[.5,2.],atol=1e-12)


def test_forcing_centered_and_standardized():
    u=normalized_forcing(np.array([1., 2., 3., 4.]))
    assert u.shape==(4,1)
    assert abs(float(u.mean()))<1e-12
    assert float(u.std())==pytest.approx(1.)


def test_zero_variance_rejected():
    with pytest.raises(ValueError,match="vary"):
        normalized_forcing(np.ones(30))
    with pytest.raises(ValueError,match="SD"):
        normalize_states(np.ones((20,2)),np.ones((20,2)))
