import numpy as np
from python_tools.dmd import delay_dmd


def test_delay_dmd_finds_known_daily_oscillation():
    t=np.arange(240)
    theta=2*np.pi*t/24
    states=np.vstack([np.sin(theta),np.cos(theta)])
    modes=delay_dmd(states,delays=24,rank=2,dt_hours=1.)
    omega=modes["omega_per_hour"]
    periods=2*np.pi/np.abs(np.imag(omega))
    assert len(periods)==2
    np.testing.assert_allclose(periods,[24,24],rtol=1e-6,atol=1e-6)
