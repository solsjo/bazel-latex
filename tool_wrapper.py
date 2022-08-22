#!/usr/bin/env python

import glob
import os
import shutil
import subprocess
import sys

from pathlib import Path


ARGS_COUNT = 9
tex_pro_path = None
else_path = None

# Walk through all externals. If they start with the special prefix
# texlive_{extra,texmf}__ prefix, it means they should be part of the
# texmf directory. LaTeX utilities don't seem to like the use of
# symlinks, so move the externals into the texmf directory.
#
# Externals that do not start with the special prefix should be added to
# TEXINPUTS, so that inclusions of external resources works.
texinputs = [""] + glob.glob("bazel-out/*/bin")
for external in sorted(os.listdir("external")):
    src = os.path.abspath(os.path.join("external", external))
    if external.startswith("texlive_extra__") or external.startswith(
            "texlive_texmf__"):
        dst = os.path.join("texmf", "/".join(external.split("__")[1:]))
        try:
            os.makedirs(os.path.dirname(dst))
        except OSError:
            pass
        os.rename(src, dst)
        if "tex.pro" in dst:
            tex_pro_path = dst
    else:
        if "tex.pro" in src:
            tex_pro_path = src
            else_path = True
        texinputs.append(src)

(
    kpsewhich_file,
    dvisvgm_file,
    dvips_file,
    libgs_file,
    job_name,
    main_file,
    output_file,
    dependency_list,
) = sys.argv[1:ARGS_COUNT]

added_before_custom = False
tex_pro_path2 = None
for inp in texinputs:
    if "tex.pro" in inp:
        added_before_custom = True
        tex_pro_path2 = inp
# Add custom dependencies to TEXINPUTS
dependency_list = dependency_list.split(',')
texinputs.extend([os.path.abspath(path) for path in dependency_list])
added_in_custom = False
for inp in texinputs:
    if "tex.pro" in inp:
        added_in_custom = True
        tex_pro_path2 = inp
    

env = dict(os.environ)
env["OPENTYPEFONTS"] = ":".join(texinputs)
env["PATH"] = "%s:%s" % (os.path.abspath("bin"), env["PATH"])
env["SOURCE_DATE_EPOCH"] = "0"
env["TEXINPUTS"] = ":".join(texinputs)
env["TEXMF"] = os.path.abspath("texmf/texmf-dist")
env["TEXMFCNF"] = os.path.abspath("texmf/texmf-dist/web2c")
env["TEXMFROOT"] = os.path.abspath("texmf")
env["TTFONTS"] = ":".join(texinputs)
env["LIBGS"] = os.path.abspath(f"{os.path.dirname(libgs_file)}/lib/libgs.so")

os.mkdir("bin")
shutil.copy(kpsewhich_file, "bin/kpsewhich")
shutil.copy(dvisvgm_file, "bin/dvisvgm")
shutil.copy(dvips_file, "bin/dvips")
shutil.copy("texmf/texmf-dist/scripts/texlive/fmtutil.pl", "bin/mktexfmt")
#shutil.copy("texmf/texmf-dist/dvips/base/tex.pro", "texmf-dist/dvips/base/tex.pro")

return_code = subprocess.call(
    args=[
        "dvisvgm",
    ] + sys.argv[ARGS_COUNT:] + [main_file],
    env=env,
)
h_out = subprocess.check_output(
    args=[
        "dvisvgm",
        "-h"
    ],
    env=env,
)

l_out = subprocess.check_output(
    args=[
        "dvisvgm",
        "-l"
    ],
    env=env,
)

v_out = subprocess.check_output(
    args=[
        "kpsewhich",
        "-var-value",
        "SELFAUTOLOC",
    ],
    env=env,
)
r_out = ""
try:
    r_out = subprocess.check_output(
        args=[
            "kpsewhich",
            "tex.pro",
        ],
        env=env,
    )
except:
    pass

try:
    f_out = subprocess.check_output(
        args=[
            "find",
            env["TEXMF"],
            "-print",
        ],
        env=env,
    )
except:
    pass
#raise IOError(f"{v_out}\n\n{tex_pro_path}\n\n{os.listdir(env["TEXMF"] + "/" + "dvips" + "/" + "base")}")
#a = os.path.exists(os.path.abspath(env["LIBGS"]))
#a_path = env["LIBGS"]
#b_path = libgs_file
#content = os.listdir(os.path.dirname(env["LIBGS"]))
#content2 = os.listdir(f"{os.path.dirname(libgs_file)}/lib")
#raise IOError(f"h:{tex_pro_path}\n\nn:{tex_pro_path2}\n\nelse:{else_path}\n\nin:{added_in_custom}\n\nbefore:{added_before_custom}\n\nl:{else_path}\n\nv:{v_out}::{r_out}\n\ncontent:{return_code}\n\n:::{f_out}")
if return_code != 0:
    sys.exit(return_code)

svg_file = Path(main_file).stem + Path(output_file).suffix
os.rename(svg_file, output_file)
