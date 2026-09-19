cask "cowpy" do
  version "0.1.0"
  sha256 "594742f1d342c764d8069935ace292ae957259601a6f150fe551ac22ee5bc3d1"

  url "https://github.com/alaminopu/cowpy/releases/download/v#{version}/Cowpy-#{version}.dmg"
  name "Cowpy"
  desc "Small native clipboard manager with history, snippets and search"
  homepage "https://github.com/alaminopu/cowpy"

  depends_on macos: :sonoma

  app "Cowpy.app"

  # Cowpy is not notarised (that needs a paid Apple Developer account), so
  # Gatekeeper would refuse to open the quarantined download. It is built from
  # the public source in this repository; removing the flag is the equivalent
  # of right-click > Open.
  postflight_steps do
    # Not an error if the flag is already absent (e.g. quarantine disabled).
    run "/usr/bin/xattr",
        args:         ["-dr", "com.apple.quarantine", "{{appdir}}/Cowpy.app"],
        must_succeed: false
  end

  uninstall quit: "com.alamin.Cowpy"

  zap trash: [
    "~/Library/Application Support/Cowpy",
    "~/Library/Preferences/com.alamin.Cowpy.plist",
  ]

  caveats <<~EOS
    Cowpy lives in the menu bar (look for the cow). Open it once from
    Applications or Spotlight to start it.

    To paste for you, Cowpy needs the Accessibility permission:
      System Settings > Privacy & Security > Accessibility

    Because Cowpy is not notarised, macOS ties that permission to the exact
    build. After `brew upgrade`, remove Cowpy from the Accessibility list and
    add it again.
  EOS
end
