LatexOutputInfo = provider(fields = ['format', 'file'])

def _latex_impl(ctx):
    toolchain = ctx.toolchains["@bazel_latex//:latex_toolchain_type"].latexinfo
    custom_dependencies = []
    for srcs in ctx.attr.srcs:
        for file in srcs.files.to_list():
            if file.dirname not in custom_dependencies:
                custom_dependencies.append(file.dirname)
    custom_dependencies = ','.join(custom_dependencies)

    flags = ["--flag=--latex-args=--output-format={}".format(ctx.attr.format)]
    for value in ctx.attr.cmd_flags:
        if "output-format" in value and ctx.attr.format not in value:
            fail("Value of attr format ({}) conflicts with value of flag {}".format(ctx.attr.format, value))
        flags.append("--flag=" + value)

    ctx.actions.run(
        mnemonic = "LuaLatex",
        use_default_shell_env = True,
        executable = ctx.executable._tool,
        arguments = [
            "--dep-tool=" + toolchain.kpsewhich.files.to_list()[0].path,
            "--dep-tool=" + toolchain.luatex.files.to_list()[0].path,
            "--dep-tool=" +  toolchain.bibtex.files.to_list()[0].path,
            "--dep-tool=" +  toolchain.biber.files.to_list()[0].path,
            "--tool=" +  ctx.files._latexrun[0].path,
            "--flag=--latex-cmd=lualatex",
            "--flag=--latex-args=-shell-escape -jobname=" + ctx.label.name,
            "--flag=-Wall",
            "--input=" + ctx.file.main.path,
            "--tool-output=" + ctx.file.main.basename.rsplit(".", 1)[0] + ".{}".format(ctx.attr.format),
            "--output=" + ctx.outputs.out.path,
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
        outputs = [ctx.outputs.out],
        tools = [ctx.executable._tool],
    )
    latex_info = LatexOutputInfo(file = ctx.outputs.out, format=ctx.attr.format)
    return [latex_info]

_latex = rule(
    attrs = {
        "main": attr.label(
            allow_single_file = [".tex"],
            mandatory = True,
         ),
        "srcs": attr.label_list(allow_files = True),
        "cmd_flags": attr.string_list(
            allow_empty = True,
            default = [],
        ),
        "format": attr.string(
            doc = "Output file format",
            default = "pdf",
            values = ["dvi", "pdf"],
        ),
        "_tool": attr.label(
            default = Label("@bazel_latex//:tool_wrapper_py"),
            executable = True,
            cfg = "host",
        ),
        "_latexrun": attr.label(
            allow_files = True,
            default = "@bazel_latex_latexrun//:latexrun",
        ),
    },
    outputs = {"out": "%{name}.%{format}"},
    toolchains = ["@bazel_latex//:latex_toolchain_type"],
    implementation = _latex_impl,
)

def _latex_to_svg_impl(ctx):
    toolchain = ctx.toolchains["@bazel_latex//:latex_toolchain_type"].latexinfo
   
    custom_dependencies = []
    for deps in ctx.attr.deps:
        for file in deps.files.to_list():
            if file.dirname not in custom_dependencies:
                custom_dependencies.append(file.dirname)
    custom_dependencies = ','.join(custom_dependencies)

    src = ctx.attr.src
    if LatexOutputInfo in src:
        input_file = src[LatexOutputInfo].file
        input_format = src[LatexOutputInfo].format
    else:
        fail("LatexOutputInfo provider not available in src")

    flags = []
    if "pdf" in input_format:
        flags.append("--flag=--pdf")
    for cmd in ctx.attr.cmd_flags:
       flags.append("--flag="+cmd) 
 
    ctx.actions.run(
        mnemonic = "DviSvgM",
        use_default_shell_env = True,
        executable = ctx.executable._tool,
        arguments = [
            "--dep-tool=" + toolchain.kpsewhich.files.to_list()[0].path,
            "--tool=" + toolchain.dvisvgm.files.to_list()[0].path,
            "--env=LIBGS" + ":" + ctx.files._libgs[0].dirname + "/lib/libgs.so",
            "--input=" + input_file.path,
            "--output=" + ctx.outputs.out.path,
            "--tool-output=" + input_file.basename.rsplit(".", 1)[0] + ".svg",
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
        outputs = [ctx.outputs.out],
        tools = [ctx.executable._tool],
    )

_latex_to_svg = rule(
    attrs = {
        "src": attr.label(),
        "deps": attr.label_list(allow_files = True),
        "cmd_flags": attr.string_list(
            allow_empty = True,
            default = [],
        ),
        "_libgs": attr.label(default="@bazel_latex//third_party:lib_ghost_script_configure"),
        "_tool": attr.label(
            default = Label("@bazel_latex//:tool_wrapper_py"),
            executable = True,
            cfg = "host",
        ),
    },
    outputs = {"out": "%{name}.svg"},
    toolchains = ["@bazel_latex//:latex_toolchain_type"],
    implementation = _latex_to_svg_impl,
)

def latex_document(name, main, srcs = [], tags = [], cmd_flags = [], format="pdf"):
    _latex(
        name = name,
        srcs = srcs + ["@bazel_latex//:core_dependencies"],
        main = main,
        tags = tags,
        cmd_flags = cmd_flags,
        format = format,
    )

    if "pdf" in format:
         # Convenience rule for viewing PDFs.
         native.sh_binary(
             name = "{}_view_output".format(name),
             srcs = ["@bazel_latex//:view_pdf.sh"],
             data = [":{}".format(name)],
             tags = tags,
         )

         # Convenience rule for viewing PDFs.
         native.sh_binary(
             name = "{}_view".format(name),
             srcs = ["@bazel_latex//:view_pdf.sh"],
             data = [":{}".format(name)],
             args = ["None"],
             tags = tags,
         )
    
def latex_to_svg(name, src, deps = [], **kwargs):

    _latex_to_svg(
        name = name,
        src = src,
        deps = deps + [
            "@bazel_latex//:core_dependencies",
            "@bazel_latex//third_party:ghostscript_dependencies",
        ],
        **kwargs
    )
