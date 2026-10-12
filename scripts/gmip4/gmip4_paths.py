"""Folders the GMIP4 scripts read and write, taken from environment variables.

The defaults are the folders of the 2026 campaign; set the variables to run
the scripts on another campaign or for another user (see README.md).
"""
import getpass
import os
from pathlib import Path

try:
    _user = getpass.getuser()
except Exception:   # no passwd entry and no USER/LOGNAME
    _user = "jabeer"

# campaign run folders <region>_<method>_rgi7_<run>/ (the dirres of every run)
RUN_DIR = Path(os.environ.get(
    "GMIP4_RUN_DIR", "/scratch_net/vierzack04_fourth/jabeer/GloGEM/glogemflow_development"))

# combined submission files: <RESULTS_DIR>/{dh,flow}/<NN>_<Region>_GloGEMflow/
RESULTS_DIR = Path(os.environ.get(
    "GMIP4_RESULTS_DIR", "/scratch_net/vierzack04_fourth/jabeer/GloGEM/r7spec_global_results"))

# GloGEM data root, as main_dir in settings.pro
DATA_DIR = Path(os.environ.get("GLOGEM_DATA_DIR", f"/itet-stor/{_user}/glogem"))
CATCHMENT_DIR = DATA_DIR / "data" / "catchments"
GEOMETRY_DIR = DATA_DIR / "geometricdata"

# a colleague's combined Δh files, copied by combine_gmip4_output.py where REUSE_SOURCES says so
REUSE_DIR = Path(os.environ.get(
    "GMIP4_REUSE_DIR", "/scratch_net/vierzack05_fourth/lvantrich/GloGEM/r7spec_global_results/monthly"))
