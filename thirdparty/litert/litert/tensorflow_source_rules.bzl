# This file is used to define a custom repository rule for TensorFlow submodule used by LiteRT.
#
# The function below allows us to select between a local TensorFlow source from local_repository
# or a remote http_archive based on the 'USE_LOCAL_TF' environment variable.
#
# To use this rule, you must set the 'USE_LOCAL_TF' environment variable to
# 'true' and the 'TF_LOCAL_SOURCE_PATH' environment variable to the absolute path of
# the tensorflow source directory. We need to pass the absolute path because we cannot use
# ctx.path() on a relative path for lower bazel versions.

"""
Implementation function for custom TensorFlow source repository rule.
This rule is used to select between a local TensorFlow source from local_repository
or a remote http_archive based on the 'USE_LOCAL_TF' environment variable.
"""

def _create_tblgen_patch(ctx, patch_file_path):
    """Helper function to create the tblgen dictionary support patch file.
    
    For proof of concept: Copy patch from vendored copy using shell command (like docker build).
    This avoids Starlark string parsing issues with patch content containing @ symbols.
    """
    # Copy patch file from vendored copy (when USE_LOCAL_TF=true) or create symlink
    # This follows the docker build pattern of using shell commands to link/copy files
    result = ctx.execute([
        "bash",
        "-c",
        "if [ -f 'tensorflow/third_party/llvm/tblgen_dict_support.patch' ]; then cp 'tensorflow/third_party/llvm/tblgen_dict_support.patch' '{}'; else echo 'ERROR: Patch file not found in vendored copy' >&2; exit 1; fi".format(str(patch_file_path)),
    ])
    if result.return_code != 0:
        fail("Failed to copy tblgen patch file from vendored copy: " + result.stderr)

def _tensorflow_source_repo_impl(ctx):
    use_local_tf = ctx.os.environ.get("USE_LOCAL_TF", "false") == "true"

    if use_local_tf:
        # TF_LOCAL_SOURCE_PATH must be set to the absolute path to the tensorflow source directory.
        TF_LOCAL_SOURCE_PATH_ENV = ctx.os.environ.get("TF_LOCAL_SOURCE_PATH", "")
        if not TF_LOCAL_SOURCE_PATH_ENV:
            fail("""ERROR: USE_LOCAL_TF is true, but TF_LOCAL_SOURCE_PATH environment variable
                 is not set with the absolute path to TensorFlow source.""")

        local_path_str = TF_LOCAL_SOURCE_PATH_ENV  # Get the path from the environment variable
        resolved_local_path = ctx.path(local_path_str)

        for f in resolved_local_path.readdir():
            ctx.symlink(f, f.basename)
        
        # Create WORKSPACE files for vendored subdirectories that tf_vendored will reference
        # tf_vendored creates repositories by symlinking subdirectories, but Bazel requires
        # WORKSPACE files at the root of repositories
        # Create WORKSPACE for local_xla
        xla_workspace = ctx.path("third_party/xla/WORKSPACE")
        if not xla_workspace.exists:
            # Copy from vendored copy if it exists
            vendored_xla_workspace = resolved_local_path.get_child("third_party").get_child("xla").get_child("WORKSPACE")
            if vendored_xla_workspace.exists:
                ctx.symlink(vendored_xla_workspace, xla_workspace)
        
        # Create WORKSPACE for local_tsl (it doesn't have one, so create a minimal stub)
        tsl_workspace = ctx.path("third_party/xla/third_party/tsl/WORKSPACE")
        if not tsl_workspace.exists:
            # Create minimal WORKSPACE file for tsl
            ctx.file(tsl_workspace, "workspace(name = \"tsl\")\n")
        
        # Patch workspace files in the local copy to use @org_tensorflow paths
        # The vendored copy uses relative paths that need to be fixed
        workspace2_path = ctx.path("tensorflow/workspace2.bzl")
        if workspace2_path.exists:
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//third_party/|load("@org_tensorflow//third_party/|g',
                str(workspace2_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(workspace2_path),
            ])
        
        workspace1_path = ctx.path("tensorflow/workspace1.bzl")
        if workspace1_path.exists:
            # Remove llvm load and call if present
            ctx.execute([
                "bash",
                "-c",
                "sed -i.bak '/llvm:setup.bzl/d; /llvm_setup(name = \"llvm-project\")/d' '{file}'".format(
                    file = str(workspace1_path),
                ),
            ], quiet = True)
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//third_party/|load("@org_tensorflow//third_party/|g',
                str(workspace1_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(workspace1_path),
            ])
        
        workspace0_path = ctx.path("tensorflow/workspace0.bzl")
        if workspace0_path.exists:
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//third_party/|load("@org_tensorflow//third_party/|g',
                str(workspace0_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(workspace0_path),
            ])
    else:
        ctx.download_and_extract(
            url = ctx.attr.urls[0],
            sha256 = ctx.attr.sha256,
            stripPrefix = ctx.attr.strip_prefix,
        )
        
        # Debug: Verify download worked
        test_file = ctx.path("tensorflow/workspace2.bzl")
        if not test_file.exists:
            fail("Downloaded archive does not contain expected tensorflow/workspace2.bzl file")
        
        # Create BUILD files FIRST, before patching workspace files
        # This ensures packages exist when workspace files try to load from them
        # (load() statements are evaluated during workspace loading, before repository rules complete)
        # Create BUILD files and directories for packages that need them
        packages_needing_build = [
            "absl", "benchmark", "llvm", "implib_so", "robin_map", "fmt", "nvshmem",
            "git", "clang_toolchain", "ducc", "eigen3", "farmhash", "flatbuffers",
            "FP16", "gemmlowp", "gpus", "hexagon", "highwayhash", "hwloc", "icu",
            "jpeg", "kissfft", "libprotobuf_mutator", "nanobind", "nasm",
            "opencl_headers", "pasta", "py", "py/ml_dtypes", "pybind11_abseil",
            "pybind11_bazel", "ruy", "shardy", "sobol_data", "stablehlo",
            "systemlibs", "tensorrt", "triton", "vulkan_headers",
        ]
        
        for package_name in packages_needing_build:
            pkg_dir_path = "tensorflow/third_party/" + package_name
            build_file_path = pkg_dir_path + "/BUILD"
            
            # Create directory
            ctx.execute([
                "bash",
                "-c",
                "mkdir -p '{pkg}'".format(pkg = pkg_dir_path),
            ], quiet = True)
            
            # Create BUILD file
            build_file = ctx.path(build_file_path)
            ctx.file(build_file, "# copybara:uncomment package(default_applicable_licenses = [\"//tensorflow:license\"])\n")
            
            # Create workspace.bzl stub if needed
            if package_name not in ["clang_toolchain", "git", "gpus", "llvm", "py", "systemlibs", "tensorrt"]:
                workspace_file = ctx.path(pkg_dir_path + "/workspace.bzl")
                workspace_content = '"""Stub workspace file for {package}"""\n\nload("@org_tensorflow//third_party:repo.bzl", "tf_http_archive", "tf_mirror_urls")\n\ndef repo():\n    """Stub repo function."""\n    pass\n'.format(package = package_name)
                ctx.file(workspace_file, workspace_content)
            
            # Special handling for llvm (needs setup.bzl)
            if package_name == "llvm":
                setup_file = ctx.path(pkg_dir_path + "/setup.bzl")
                ctx.file(setup_file, '"""Stub setup file for llvm"""\n\ndef llvm_setup(name):\n    """Stub llvm_setup function."""\n    pass\n')
        
        # Patch workspace files to fix path resolution issues
        # Replace relative paths (//third_party/...) with explicit @org_tensorflow paths
        # This prevents Bazel from incorrectly resolving to @local_xla
        # Use shell commands to patch files since Starlark string replacement might miss some patterns
        
        # Patch workspace2.bzl - this is the main file causing issues
        workspace2_path = ctx.path("tensorflow/workspace2.bzl")
        if workspace2_path.exists:
            # Use sed to replace all load("//third_party/ patterns
            # Also replace @local_xla references that might have been incorrectly added
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("@local_xla//third_party/|load("@org_tensorflow//third_party/|g',
                str(workspace2_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//third_party/|load("@org_tensorflow//third_party/|g',
                str(workspace2_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("@local_xla//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(workspace2_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(workspace2_path),
            ])
        
        # Patch workspace1.bzl
        workspace1_path = ctx.path("tensorflow/workspace1.bzl")
        if workspace1_path.exists:
            # Remove llvm-related code (load and call) - not needed in workspace1, only workspace2
            # The downloaded archive has these but the vendored copy doesn't
            # Remove the load statement
            ctx.execute([
                "bash",
                "-c",
                "sed -i.bak '/llvm:setup.bzl/d' '{file}'".format(
                    file = str(workspace1_path),
                ),
            ], quiet = True)
            # Remove the llvm_setup call
            ctx.execute([
                "bash",
                "-c",
                "sed -i.bak '/llvm_setup(name = \"llvm-project\")/d' '{file}'".format(
                    file = str(workspace1_path),
                ),
            ], quiet = True)
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("@local_xla//third_party/|load("@org_tensorflow//third_party/|g',
                str(workspace1_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//third_party/|load("@org_tensorflow//third_party/|g',
                str(workspace1_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("@local_xla//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(workspace1_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(workspace1_path),
            ])
        
        # Patch workspace0.bzl
        workspace0_path = ctx.path("tensorflow/workspace0.bzl")
        if workspace0_path.exists:
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("@local_xla//third_party/|load("@org_tensorflow//third_party/|g',
                str(workspace0_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//third_party/|load("@org_tensorflow//third_party/|g',
                str(workspace0_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("@local_xla//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(workspace0_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(workspace0_path),
            ])
        
        # Patch python_configure.bzl (known to cause issues)
        python_configure_path = ctx.path("tensorflow/third_party/py/python_configure.bzl")
        if python_configure_path.exists:
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("@local_xla//third_party/|load("@org_tensorflow//third_party/|g',
                str(python_configure_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//third_party/|load("@org_tensorflow//third_party/|g',
                str(python_configure_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("@local_xla//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(python_configure_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(python_configure_path),
            ])
        
        # Patch clang_toolchain files (known to cause issues)
        clang_configure_path = ctx.path("tensorflow/third_party/clang_toolchain/cc_configure_clang.bzl")
        if clang_configure_path.exists:
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("@local_xla//third_party/|load("@org_tensorflow//third_party/|g',
                str(clang_configure_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//third_party/|load("@org_tensorflow//third_party/|g',
                str(clang_configure_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("@local_xla//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(clang_configure_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(clang_configure_path),
            ])
        
        # Patch llvm setup.bzl (known to cause issues)
        llvm_setup_path = ctx.path("tensorflow/third_party/llvm/setup.bzl")
        if llvm_setup_path.exists:
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("@local_xla//third_party/|load("@org_tensorflow//third_party/|g',
                str(llvm_setup_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//third_party/|load("@org_tensorflow//third_party/|g',
                str(llvm_setup_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("@local_xla//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(llvm_setup_path),
            ])
            ctx.execute([
                "sed",
                "-i.bak",
                's|load("//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                str(llvm_setup_path),
            ])
        
        # Patch llvm workspace.bzl to add our tblgen dictionary support patch
        # This fixes the 'got string in sequence assignment' error in gentbl_cc_library
        llvm_workspace_path = ctx.path("tensorflow/third_party/llvm/workspace.bzl")
        if llvm_workspace_path.exists:
            # Copy or create the patch file in the llvm directory
            patch_file_path = ctx.path("tensorflow/third_party/llvm/tblgen_dict_support.patch")
            
            # Try to copy from vendored copy if using local TensorFlow
            if use_local_tf:
                vendored_patch = resolved_local_path.get_child("third_party").get_child("llvm").get_child("tblgen_dict_support.patch")
                if vendored_patch.exists:
                    ctx.symlink(vendored_patch, patch_file_path)
                else:
                    # Read patch from main workspace patches directory if available
                    # For now, create it directly
                    _create_tblgen_patch(ctx, patch_file_path)
            else:
                # Create the patch file
                _create_tblgen_patch(ctx, patch_file_path)
            
            # Add our patch to the patch_file list in workspace.bzl
            # Insert after zstd.patch
            ctx.execute([
                "bash",
                "-c",
                "sed -i.bak '/\"\\/\\/third_party\\/llvm:zstd.patch\",/a\\            \"\\/\\/third_party\\/llvm:tblgen_dict_support.patch\",' '{}'".format(str(llvm_workspace_path)),
            ], quiet = True)
        
        # Create BUILD files for directories that need to be Bazel packages
        # These directories are referenced in workspace files but may not have BUILD files
        # in the downloaded archive (they exist in the vendored copy)
        third_party_dir = ctx.path("tensorflow/third_party")
        if third_party_dir.exists:
            # List of directories that need BUILD files (based on workspace2.bzl loads)
            # These are packages referenced in workspace files but may not have BUILD files
            # in the downloaded archive (they exist in the vendored copy)
            packages_needing_build = [
                "absl",
                "benchmark",
                "clang_toolchain",
                "dlpack",
                "ducc",
                "eigen3",
                "farmhash",
                "flatbuffers",
                "FP16",
                "fmt",
                "gemmlowp",
                "git",
                "gpus",
                "hexagon",
                "highwayhash",
                "hwloc",
                "icu",
                "implib_so",
                "jpeg",
                "kissfft",
                "libprotobuf_mutator",
                "llvm",
                "nanobind",
                "nasm",
                "nvshmem",
                "opencl_headers",
                "pasta",
                "py",
                "py/ml_dtypes",
                "pybind11_abseil",
                "pybind11_bazel",
                "robin_map",
                "ruy",
                "shardy",
                "sobol_data",
                "stablehlo",
                "systemlibs",
                "tensorrt",
                "triton",
                "vulkan_headers",
            ]
            
            # Also handle subdirectories that might need BUILD files
            subdirs_needing_build = [
                "py/ml_dtypes",
            ]
            
            # Create BUILD files and directories for packages that need them
            # Create directories and files one by one to ensure they're all created
            for package_name in packages_needing_build:
                pkg_dir_path = "tensorflow/third_party/" + package_name
                build_file_path = pkg_dir_path + "/BUILD"
                
                # Create directory - use relative path from repository root
                # This ensures the directory is created in the correct location
                result = ctx.execute([
                    "bash",
                    "-c",
                    "mkdir -p '{pkg}'".format(pkg = pkg_dir_path),
                ], quiet = True)
                
                # Verify directory exists (or create it if mkdir failed)
                pkg_dir = ctx.path(pkg_dir_path)
                if not pkg_dir.exists:
                    # Fallback: try creating parent first
                    parent = ctx.path("tensorflow/third_party")
                    if parent.exists:
                        ctx.execute([
                            "bash",
                            "-c",
                            "cd tensorflow/third_party && mkdir -p '{pkg}'".format(pkg = package_name),
                        ], quiet = True)
                
                # Create BUILD file - this makes the directory a valid Bazel package
                # ctx.file() should create parent directories, but we've already created them
                build_file = ctx.path(build_file_path)
                ctx.file(build_file, "# copybara:uncomment package(default_applicable_licenses = [\"//tensorflow:license\"])\n")
                
                # Create workspace.bzl stub if needed
                if package_name not in ["clang_toolchain", "git", "gpus", "llvm", "py", "systemlibs", "tensorrt"]:
                    workspace_file = ctx.path(pkg_dir_path + "/workspace.bzl")
                    workspace_content = '"""Stub workspace file for {package}"""\n\nload("@org_tensorflow//third_party:repo.bzl", "tf_http_archive", "tf_mirror_urls")\n\ndef repo():\n    """Stub repo function."""\n    pass\n'.format(package = package_name)
                    ctx.file(workspace_file, workspace_content)
                
                # Special handling for llvm (needs setup.bzl) - create it explicitly
                if package_name == "llvm":
                    setup_file = ctx.path(pkg_dir_path + "/setup.bzl")
                    ctx.file(setup_file, '"""Stub setup file for llvm"""\n\ndef llvm_setup(name):\n    """Stub llvm_setup function."""\n    pass\n')
            
            # Handle subdirectories that need BUILD files
            for subdir_path in subdirs_needing_build:
                subdir = ctx.path("tensorflow/third_party/" + subdir_path)
                build_file = ctx.path("tensorflow/third_party/" + subdir_path + "/BUILD")
                
                # Create directory if it doesn't exist
                if not subdir.exists:
                    ctx.execute([
                        "mkdir",
                        "-p",
                        str(subdir),
                    ])
                
                # Create BUILD file if it doesn't exist
                if not build_file.exists:
                    ctx.file(build_file, "# copybara:uncomment package(default_applicable_licenses = [\"//tensorflow:license\"])\n")
        
        # Patch additional commonly loaded .bzl files in third_party subdirectories
        # Use find command to recursively patch all .bzl files
        third_party_dir = ctx.path("tensorflow/third_party")
        if third_party_dir.exists:
            # Use find + sed to patch all .bzl files recursively
            ctx.execute([
                "find",
                str(third_party_dir),
                "-name",
                "*.bzl",
                "-type",
                "f",
                "-exec",
                "sed",
                "-i.bak",
                's|load("@local_xla//third_party/|load("@org_tensorflow//third_party/|g',
                "{}",
                "+",
            ], quiet = True)
            ctx.execute([
                "find",
                str(third_party_dir),
                "-name",
                "*.bzl",
                "-type",
                "f",
                "-exec",
                "sed",
                "-i.bak",
                's|load("//third_party/|load("@org_tensorflow//third_party/|g',
                "{}",
                "+",
            ], quiet = True)
            ctx.execute([
                "find",
                str(third_party_dir),
                "-name",
                "*.bzl",
                "-type",
                "f",
                "-exec",
                "sed",
                "-i.bak",
                's|load("@local_xla//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                "{}",
                "+",
            ], quiet = True)
            ctx.execute([
                "find",
                str(third_party_dir),
                "-name",
                "*.bzl",
                "-type",
                "f",
                "-exec",
                "sed",
                "-i.bak",
                's|load("//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                "{}",
                "+",
            ], quiet = True)
        
        # Patch .bzl files in tensorflow/tools/
        tools_dir = ctx.path("tensorflow/tools")
        if tools_dir.exists:
            ctx.execute([
                "find",
                str(tools_dir),
                "-name",
                "*.bzl",
                "-type",
                "f",
                "-exec",
                "sed",
                "-i.bak",
                's|load("@local_xla//third_party/|load("@org_tensorflow//third_party/|g',
                "{}",
                "+",
            ], quiet = True)
            ctx.execute([
                "find",
                str(tools_dir),
                "-name",
                "*.bzl",
                "-type",
                "f",
                "-exec",
                "sed",
                "-i.bak",
                's|load("//third_party/|load("@org_tensorflow//third_party/|g',
                "{}",
                "+",
            ], quiet = True)
            ctx.execute([
                "find",
                str(tools_dir),
                "-name",
                "*.bzl",
                "-type",
                "f",
                "-exec",
                "sed",
                "-i.bak",
                's|load("@local_xla//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                "{}",
                "+",
            ], quiet = True)
            ctx.execute([
                "find",
                str(tools_dir),
                "-name",
                "*.bzl",
                "-type",
                "f",
                "-exec",
                "sed",
                "-i.bak",
                's|load("//tensorflow/|load("@org_tensorflow//tensorflow/|g',
                "{}",
                "+",
            ], quiet = True)

tensorflow_source_repo = repository_rule(
    implementation = _tensorflow_source_repo_impl,
    local = False,
    attrs = {
        "sha256": attr.string(mandatory = False),
        "strip_prefix": attr.string(mandatory = True),
        "urls": attr.string_list(mandatory = True),
    },
    doc = """
    A custom repository rule to select between a local TensorFlow source or a remote http_archive
    based on the'USE_LOCAL_TF' environment variable and TF_LOCAL_SOURCE_PATH flag.
    """,
)
