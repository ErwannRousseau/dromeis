# Reusable workflow with project-owned commands

Dromeis exposes one reusable GitHub Actions workflow, while each consuming React
Native repository keeps a minimal caller workflow and owns the command used for
validation or TestFlight publication. The workflow checks out the exact
pull-request head SHA, resolves toolchain versions using project files, workflow
inputs, then image defaults, and runs the command on a disposable macOS job VM;
an unavailable exact version fails before execution without downloading it. The
image defaults are Xcode 27, Node.js 24.20.0 (latest LTS at this decision), Java
17 (the React Native-compatible default), and Ruby 4.0.6 (latest stable; Ruby
has no LTS channel). Selected versions are pinned when an image is built, while
Xcode inputs select `/Applications/Xcode_<version>.app`. Application signing
secrets remain scoped to the consuming repository or organization and are passed
explicitly, so Dromeis does not couple its infrastructure to Fastlane,
CocoaPods, or a particular application’s credentials.
