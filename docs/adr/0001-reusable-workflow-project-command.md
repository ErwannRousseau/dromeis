# Reusable workflow with project-owned commands

Dromeis exposes one reusable GitHub Actions workflow, while each consuming React
Native repository keeps a minimal caller workflow and owns the command used for
validation or TestFlight publication. The workflow checks out the exact
pull-request head SHA, resolves toolchain versions using project files, workflow
inputs, then image defaults, and runs the command on a disposable macOS job VM;
an unavailable exact version fails before execution without downloading it. The
initial image defaults are Xcode 27, Node.js 22.20.0, Java 17, and Ruby 3.3.6;
Xcode inputs select `/Applications/Xcode_<version>.app`. Application signing
secrets remain scoped to the consuming repository or organization and are passed
explicitly, so Dromeis does not couple its infrastructure to Fastlane,
CocoaPods, or a particular application’s credentials.
