LatexOutputInfo = provider(fields = ['dvi', 'pdf'])

def _latex_pdf_impl(ctx):
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
    
    ctx.actions.run(
        mnemonic = "LuaLatex",
        use_default_shell_env = True,
        executable = ctx.executable.tool,
        arguments = [
            toolchain.kpsewhich.files.to_list()[0].path,
            toolchain.luatex.files.to_list()[0].path,
            toolchain.bibtex.files.to_list()[0].path,
            toolchain.biber.files.to_list()[0].path,
            ctx.files._latexrun[0].path,
            ctx.label.name,
            ctx.files.main[0].path,
            outs[0].path,
            custom_dependencies,
        ] + ctx.attr.cmd_flags,
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
    if "pdf" in ext:
        latex_info = LatexOutputInfo(pdf = outs[0])
    else:
        latex_info = LatexOutputInfo(dvi = outs[0])
    return [DefaultInfo(files=depset(outs)), latex_info]

_latex_pdf = rule(
    attrs = {
        "main": attr.label(allow_files = True),
        "srcs": attr.label_list(allow_files = True),
        "cmd_flags": attr.string_list(
            allow_empty = True,
            default = [],
        ),
        "tool": attr.label(
            default = Label("//:run_lualatex"),
            executable = True,
            cfg = "host",
        ),
        "_latexrun": attr.label(
            allow_files = True,
            default = "@bazel_latex_latexrun//:latexrun",
        ),
    },
    toolchains = ["@bazel_latex//:latex_toolchain_type"],
    implementation = _latex_pdf_impl,
)

def _dvi_to_svg_impl(ctx):
    toolchain = ctx.toolchains["@bazel_latex//:latex_toolchain_type"].latexinfo
    out_file = ctx.actions.declare_file(ctx.label.name + ".svg")
    dvis = []
    src = ctx.attr.src
    if LatexOutputInfo in src:
        dvis.append(src[LatexOutputInfo].pdf)
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
    
    ctx.actions.run(
        mnemonic = "DviSvgM",
        use_default_shell_env = True,
        executable = ctx.executable._tool_wrapper_py,
        arguments = [
            toolchain.kpsewhich.files.to_list()[0].path,
            toolchain.dvisvgm.files.to_list()[0].path,
            toolchain.dvips.files.to_list()[0].path,
            ctx.files._libgs[0].path,
            ctx.label.name,
            dvis[0].path,
            outs[0].path,
            custom_dependencies,
        ] + ["-P", "-b", "min"],
        inputs = depset(
            direct = ctx.files.src + 
                     ctx.files.deps +
                     [toolchain.dvisvgm.files.to_list()[0]] +
                     ctx.files._libgs,
            transitive = [
                toolchain.kpsewhich.files,
                toolchain.dvisvgm.files,
                toolchain.dvips.files
            ],
        ),
        outputs = outs,
        tools = [ctx.executable._tool_wrapper_py],
    )
    return [DefaultInfo(files=depset([out_file]))]

_dvi_to_svg = rule(
    attrs = {
        "src": attr.label(),
        "deps": attr.label_list(allow_files = True),
        "_tool_wrapper": attr.label(
            default="@bazel_latex//:tool_wrapper",
            executable = True,
            cfg = "host",
        ),
        "_libgs": attr.label(default="@bazel_latex//:lib_ghost_script_configure"),
        "_tool_wrapper_py": attr.label(
            default = Label("@bazel_latex//:tool_wrapper_py"),
            executable = True,
            cfg = "host",
        ),
    },
    toolchains = ["@bazel_latex//:latex_toolchain_type"],
    implementation = _dvi_to_svg_impl,
)

def latex_document(name, main, srcs = [], tags = [], cmd_flags = []):
    # PDF generation.
    _latex_pdf(
        name = name,
        srcs = srcs + ["@bazel_latex//:core_dependencies"],
        main = main,
        tags = tags,
        cmd_flags = cmd_flags,
    )

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
    
def tex_to_svg(name, main, srcs = [], tags = [], cmd_flags = [], deps = []):
    # PDF and dvi generation.
    _latex_pdf(
        name = name + "_dvi",
        srcs = srcs + [
            "@bazel_latex//:core_dependencies",
            "@bazel_latex//:ghostscript_dependencies",
        ],
        main = main,
        tags = tags,
        cmd_flags = cmd_flags, #["--latex-args=--output-format=dvi"],
    )

    _dvi_to_svg(
        name = name,
        src = ":" + name + "_dvi",
        deps = deps + [
            "@bazel_latex//:core_dependencies",
            "@bazel_latex//:ghostscript_dependencies",
        ],
        tags = tags,
    )
