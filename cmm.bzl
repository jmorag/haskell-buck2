# Compiling Cmm (the `cmm-sources` of a Cabal component) into a library that
# Haskell libraries can depend on.
#
# GHC compiles .cmm files itself, so this runs it on each of them, once for
# each kind of object that a link needs: ordinary ones for static linking and
# position-independent ones for shared libraries (dynamic ones, in GHC's
# terms). The library is the objects themselves, to be linked (all of them)
# into the library of the component's Haskell code, as in Cabal: see
# `internal_deps` of haskell_library().

load("@prelude//cxx:cxx_context.bzl", "get_cxx_toolchain_info")
load(
    "@prelude//linking:link_info.bzl",
    "LibOutputStyle",
    "LinkInfo",
    "LinkInfos",
    "LinkStyle",
    "ObjectsLinkable",
    "create_merged_link_info",
)
load("@prelude//linking:types.bzl", "Linkage")
load("@prelude//linking:linkable_graph.bzl", "create_linkable_graph", "create_linkable_graph_node", "create_linkable_node")
load("@prelude//linking:shared_libraries.bzl", "EMPTY_SHARED_LIBRARY_INFO")
load("@prelude//decls/toolchains_common.bzl", "toolchains_common")
load("@prelude//haskell:toolchain.bzl", "HaskellToolchainInfo")
load("@third-party-haskell//:tools.bzl", "CC_FINGERPRINT", "GHC_FINGERPRINT")

def _cmm_library_impl(ctx: AnalysisContext) -> list[Provider]:
    ghc = ctx.attrs._haskell_toolchain[HaskellToolchainInfo]
    linker_type = get_cxx_toolchain_info(ctx).linker_info.type
    link_infos = {}
    for output_style, link_style, flags in (
        (LibOutputStyle("archive"), LinkStyle("static"), []),
        (LibOutputStyle("pic_archive"), LinkStyle("shared"), ["-dynamic", "-fPIC"]),
    ):
        variant = link_style.value
        objects = []
        for src in ctx.attrs.srcs:
            obj = ctx.actions.declare_output(variant, src.short_path + ".o")
            cmd = cmd_args(
                ghc.compiler,
                ghc.compiler_flags,
                ["-prof"] if ctx.attrs.profiling else [],
                flags,
                ctx.attrs.flags,
                "-c",
                src,
                "-o",
                obj.as_output(),
            )

            # The fingerprints are not read: they make the GHC installation and
            # the C toolchain part of the action's cache key (see toolchains/BUCK).
            ctx.actions.run(
                cmd,
                category = "ghc_cmm",
                identifier = variant + "/" + src.short_path,
                env = {"CABAL_BUCK2_GHC": GHC_FINGERPRINT, "CABAL_BUCK2_CC": CC_FINGERPRINT},
            )
            objects.append(obj)

        # The Cmm code is only reached from Haskell code, by symbol, so every
        # object has to be kept.
        link_infos[output_style] = LinkInfos(default = LinkInfo(
            name = ctx.label.name,
            linkables = [ObjectsLinkable(objects = objects, linker_type = linker_type, link_whole = True)],
        ))

    return [
        DefaultInfo(),
        create_merged_link_info(ctx, get_cxx_toolchain_info(ctx).pic_behavior, link_infos, preferred_linkage = Linkage("static")),
        EMPTY_SHARED_LIBRARY_INFO,
        create_linkable_graph(
            ctx,
            node = create_linkable_graph_node(
                ctx,
                linkable_node = create_linkable_node(
                    ctx = ctx,
                    default_soname = None,
                    preferred_linkage = Linkage("static"),
                    link_infos = link_infos,
                ),
            ),
        ),
    ]

_cmm_library = rule(
    impl = _cmm_library_impl,
    attrs = {
        "flags": attrs.list(attrs.arg(), default = []),
        "labels": attrs.list(attrs.string(), default = []),
        "profiling": attrs.bool(default = False),
        "srcs": attrs.list(attrs.source()),
        "_cxx_toolchain": toolchains_common.cxx(),
        "_haskell_toolchain": toolchains_common.haskell(),
    },
)

_PROFILING = select({
    "root//buck2/constraints:prof": True,
    "DEFAULT": False,
})

def cmm_library(name, srcs, flags = [], **kwargs):
    """A library of Cmm code, to depend on from haskell_library() (as one
    of its `internal_deps`).

    Args:
      name: the target name.
      srcs: the .cmm files.
      flags: options for GHC when it compiles them.
    """
    _cmm_library(name = name, srcs = srcs, flags = flags, profiling = _PROFILING, **kwargs)
