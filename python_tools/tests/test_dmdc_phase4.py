import numpy as np
import pytest
from python_tools.dmdc_phase4 import design, fit, joint_ridge, impulse, impulse_metrics, spectral_memory


def test_exact_two_state_lag_and_current_control():
    rng = np.random.default_rng(123)
    u = rng.normal(size=(500, 1))
    x = np.zeros((500, 1))
    for k in range(1, 499):
        x[k+1] = .7*x[k] + .2*x[k-1] + .4*u[k]
    z, ctrl, y=design(x,u,2)
    assert z.shape==(498,2) and ctrl.shape==(498,1) and y.shape==(498,1)
    a,b=fit(x,u,p=2,ridge=1e-9)
    np.testing.assert_allclose(a,[[.7,.2]],atol=1e-5)
    np.testing.assert_allclose(b,[[.4]],atol=1e-5)


def test_one_based_impulse_lag_and_spectral_memory():
    a=np.array([[.8,0]])
    b=np.array([[.5]])
    out=impulse(a,b,p=2,horizon=4)
    np.testing.assert_allclose(out[:,0],[.5,.4,.32,.256],atol=1e-12)
    assert impulse_metrics(out)["peak_lag_h"]==1.
    assert spectral_memory(a,2)["dominant_decay_time_h"]==pytest.approx(-1/np.log(.8))


def test_joint_chronological_ridge():
    n=180
    u=np.sin(np.arange(n)*.3)[:,None]
    e=np.zeros((n,1));m=np.zeros((n,1))
    for i in range(1,n-1):
        e[i+1] = .8*e[i]+.2*u[i]
        m[i+1] = .9*m[i]+.05*u[i]
    z=joint_ridge(e,m,u,p=2,grid=(0.,1e-5,1e-2))
    assert z["ridge"] in (0.,1e-5,1e-2)
    assert len(z["validation_mse"])==2
    assert z["training_rows"]>z["validation_rows"]


def test_alignment_rejected():
    with pytest.raises(ValueError):
        design(np.zeros((4,1)),np.zeros((5,1)),p=2)
