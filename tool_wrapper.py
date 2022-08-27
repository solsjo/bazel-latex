#!/usr/bin/env python

import glob
import os
import shutil
import subprocess
import sys

from pathlib import Path


ARGS_COUNT = 9


def setup_argparse():
    # grab main tool
    # grab helper tools
    # grab input file
    # grab flags


def setup_dependencies():
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
        else:
            texinputs.append(src)
    return texinputs


def setup_env(texinputs, main_tool, tools):
    env = dict(os.environ)
    env["OPENTYPEFONTS"] = ":".join(texinputs)
    env["PATH"] = "%s:%s" % (os.path.abspath("bin"), env["PATH"])
    env["SOURCE_DATE_EPOCH"] = "0"
    env["TEXINPUTS"] = ":".join(texinputs)
    env["TEXMF"] = os.path.abspath("texmf/texmf-dist")
    env["TEXMFCNF"] = os.path.abspath("texmf/texmf-dist/web2c")
    env["TEXMFROOT"] = os.path.abspath("texmf")
    env["TTFONTS"] = ":".join(texinputs)
    
    os.mkdir("bin")
    for tool in tools:
        shutil.copy(kpsewhich_file, "bin/" + os.path.basename(tool))

    shutil.copy("texmf/texmf-dist/scripts/texlive/fmtutil.pl", "bin/mktexfmt")
    return env


def main():
    texinputs = setup_dependencies()
    #parser = setup_argparse()
    #args = parser.parse_args()
    (
        kpsewhich_file,
        main_tool_file,
        libgs_file,
        job_name,
        main_file,
        output_file,
        dependency_list,
    ) = sys.argv[1:ARGS_COUNT]

    tools = [kpsewhich_file] + [main_tool_file]
    env["LIBGS"] = os.path.abspath(f"{os.path.dirname(libgs_file)}/lib/libgs.so")
    
    # Add custom dependencies to TEXINPUTS
    dependency_list = dependency_list.split(',')
    texinputs.extend([os.path.abspath(path) for path in dependency_list])
    env = setup_env(texinputs, tools)
    
    return_code = subprocess.call(
        args=[
            os.path.basename(main_tool_file),
        ] + sys.argv[ARGS_COUNT:] + [main_file],
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
    
    if return_code != 0:
        sys.exit(return_code)
    
    svg_file = Path(main_file).stem + Path(output_file).suffix
    os.rename(svg_file, output_file)

if __name__ == "__main__":
    main():
