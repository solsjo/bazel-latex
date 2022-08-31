workspace(name = "bazel_latex")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "bazel_toolchains",
    sha256 = "109a99384f9d08f9e75136d218ebaebc68cc810c56897aea2224c57932052d30",
    strip_prefix = "bazel-toolchains-94d31935a2c94fe7e7c7379a0f3393e181928ff7",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/bazel-toolchains/archive/94d31935a2c94fe7e7c7379a0f3393e181928ff7.tar.gz",
        "https://github.com/bazelbuild/bazel-toolchains/archive/94d31935a2c94fe7e7c7379a0f3393e181928ff7.tar.gz",
    ],
)

register_toolchains(
    "//:latex_toolchain_amd64-freebsd",
    "//:latex_toolchain_x86_64-darwin",
    "//:latex_toolchain_x86_64-linux",
)

load("@bazel_latex//:repositories.bzl", "latex_repositories")

latex_repositories()

# Needed for building ghostscript
# Which is needed by dvisvgm,
# dvisvgm is part of the texlive toolchain,
# but cannot produce correct svg files without dynamically
# linking to ghostscript.
load("@rules_foreign_cc//foreign_cc:repositories.bzl", "rules_foreign_cc_dependencies")

rules_foreign_cc_dependencies(register_built_tools=true)
