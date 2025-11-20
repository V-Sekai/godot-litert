load("//tensorflow:tensorflow.default.bzl", "filegroup")
load("//tensorflow/core/platform:rules_cc.bzl", "cc_library")

package(
    # copybara:uncomment default_applicable_licenses = ["//tensorflow:license"],
    default_visibility = [
        "//tensorflow/core:__subpackages__",
    ],
    licenses = ["notice"],
)

exports_files(
    srcs = [
        "session.h",
        "session_options.h",
        "version.h",
    ],
    visibility = ["//visibility:public"],
)

# Export source files needed for mobile builds, which do not use granular targets.
filegroup(
    name = "mobile_srcs_no_runtime",
    srcs = [
        "version.h",
    ],
    visibility = ["//tensorflow/core:__pkg__"],
)

filegroup(
    name = "mobile_srcs_only_runtime",
    srcs = [
        "session.h",
        "session_options.h",
    ],
    visibility = ["//tensorflow/core:__pkg__"],
)

cc_library(
    name = "version",
    hdrs = ["version.h"],
)

# Alias for release_version target expected by LiteRT
# This provides TensorFlow version information via version.h header
alias(
    name = "release_version",
    actual = ":version",
    visibility = ["//visibility:public"],
)
