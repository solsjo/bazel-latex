LatexOutputInfo = provider(fields = ['format', 'file'])

def _latex_impl(ctx):
    toolchain = ctx.toolchains["@bazel_latex//:latex_toolchain_type"].latexinfo
    custom_dependencies = []
    for srcs in ctx.attr.srcs:
        for file in srcs.files.to_list():
            if file.dirname not in custom_dependencies:
                custom_dependencies.append(file.dirname)
    custom_dependencies = ','.join(custom_dependencies)

    ext = ".pdf"
    for value in ctx.attr.cmd_flags:
        if "output-format" in value and "dvi" in value:
            ext = ".dvi"
    out_file = ctx.actions.declare_file(ctx.label.name + ext)
    outs = [out_file]
    flags = []
    for flag in ctx.attr.cmd_flags:
        flags.append("--flag=" + flag)
    ctx.actions.run(
        mnemonic = "LuaLatex",
        use_default_shell_env = True,
        executable = ctx.executable.tool,
        arguments = [
            "--dep-tool=" + toolchain.kpsewhich.files.to_list()[0].path,
            "--dep-tool=" + toolchain.luatex.files.to_list()[0].path,
            "--dep-tool=" +  toolchain.bibtex.files.to_list()[0].path,
            "--dep-tool=" +  toolchain.biber.files.to_list()[0].path,
            "--tool=" +  ctx.files._latexrun[0].path,
            "--flag=--latex-args=-shell-escape -jobname=" + ctx.label.name,
            "--flag=--latex-cmd=lualatex",
            "--flag=-Wall",
            "--input=" + ctx.files.main[0].path,
            "--tool-output=" + ctx.label.name + ext,
            "--output=" + outs[0].path,
            "--inputs=" + custom_dependencies,
        ] + flags,
        inputs = depset(
            direct = ctx.files.main + ctx.files.srcs + ctx.files._latexrun,
            transitive = [
                toolchain.kpsewhich.files,
                toolchain.luatex.files,
                toolchain.bibtex.files,
                toolchain.biber.files,
            ],
        ),
        outputs = outs,
        tools = [ctx.executable.tool],
    )
    latex_info = LatexOutputInfo(file = outs[0], format=ext)
    return [DefaultInfo(files=depset(outs)), latex_info]

_latex = rule(
    attrs = {
        "main": attr.label(allow_files = True),
        "srcs": attr.label_list(allow_files = True),
        "cmd_flags": attr.string_list(
            allow_empty = True,
            default = [],
        ),
        "tool": attr.label(
            default = Label("@bazel_latex//:tool_wrapper_py"),
            executable = True,
            cfg = "host",
        ),
        "_latexrun": attr.label(
            allow_files = True,
            default = "@bazel_latex_latexrun//:latexrun",
        ),
    },
    toolchains = ["@bazel_latex//:latex_toolchain_type"],
    implementation = _latex_impl,
)

def _latex_to_svg_impl(ctx):
    toolchain = ctx.toolchains["@bazel_latex//:latex_toolchain_type"].latexinfo
    out_file = ctx.actions.declare_file(ctx.label.name + ".svg")
    inputs = []
    cmd_flags = ["-bmin"]
    src = ctx.attr.src
    if LatexOutputInfo in src:
        inputs.append(src[LatexOutputInfo].file)
        input_format = src[LatexOutputInfo].format
        if "pdf" in input_format:
            cmd_flags.append("--pdf")
    else:
        fail("LatexOutputInfo provider not available in src")
   
    custom_dependencies = []
    for deps in ctx.attr.deps:
        for file in deps.files.to_list():
            if file.dirname not in custom_dependencies:
                custom_dependencies.append(file.dirname)
    custom_dependencies = ','.join(custom_dependencies)

    ext = ".svg"
    out_file = ctx.actions.declare_file(ctx.label.name + ext)
    outs = [out_file]
   
    flags = []
    for cmd in cmd_flags:
       flags.append("--flag="+cmd) 
 
    ctx.actions.run(
        mnemonic = "DviSvgM",
        use_default_shell_env = True,
        executable = ctx.executable._tool_wrapper_py,
        arguments = [
            "--dep-tool=" + toolchain.kpsewhich.files.to_list()[0].path,
            "--tool=" + toolchain.dvisvgm.files.to_list()[0].path,
            "--env=LIBGS" + ":" + ctx.files._libgs[0].dirname + "/lib/libgs.so",
            "--input=" + inputs[0].path,
            "--output=" + outs[0].path,
            "--tool-output=" + inputs[0].basename.rsplit(".", 1)[0] + ext,
            "--inputs=" + custom_dependencies,
        ] + flags,
        inputs = depset(
            direct = ctx.files.src + 
                     ctx.files.deps +
                     [toolchain.dvisvgm.files.to_list()[0]] +
                     ctx.files._libgs,
            transitive = [
                toolchain.kpsewhich.files,
                toolchain.dvisvgm.files,
            ],
        ),
        outputs = outs,
        tools = [ctx.executable._tool_wrapper_py],
    )
    return [DefaultInfo(files=depset([out_file]))]

_latex_to_svg = rule(
    attrs = {
        "src": attr.label(),
        "deps": attr.label_list(allow_files = True),
        "_libgs": attr.label(default="@bazel_latex//:lib_ghost_script_configure"),
        "_tool_wrapper_py": attr.label(
            default = Label("@bazel_latex//:tool_wrapper_py"),
            executable = True,
            cfg = "host",
        ),
    },
    toolchains = ["@bazel_latex//:latex_toolchain_type"],
    implementation = _latex_to_svg_impl,
)

def latex_document(name, main, srcs = [], tags = [], cmd_flags = [], format="pdf"):
    if "pdf" not in format:
        cmd_flags + ["--latex-args=--output-format=dvi"]

    _latex(
        name = name,
        srcs = srcs + ["@bazel_latex//:core_dependencies"],
        main = main,
        tags = tags,
        cmd_flags = cmd_flags,
    )

    if "pdf" not in format:
         # Convenience rule for viewing PDFs.
         native.sh_binary(
             name = name + "_view_output",
             srcs = ["@bazel_latex//:view_pdf.sh"],
             data = [":" + name],
             tags = tags,
         )

         # Convenience rule for viewing PDFs.
         native.sh_binary(
             name = name + "_view",
             srcs = ["@bazel_latex//:view_pdf.sh"],
             data = [":" + name],
             args = ["None"],
             tags = tags,
         )
    
def latex_to_svg(name, src, deps = [], **kwargs):

    _latex_to_svg(
        name = name,
        src = src,
        deps = deps + [
            "@bazel_latex//:core_dependencies",
            "@bazel_latex//:ghostscript_dependencies",
        ],
        **kwargs
    )
