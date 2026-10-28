// Turns off the input-source hotkeys ctrl+space (60) and ctrl+opt+space (61), which take tuios's prefix.
// macOS re-enables them after a restart even with enabled = 0 in com.apple.symbolichotkeys.plist,
// and `defaults write` does not reach a running session. This is the private call System Settings makes.
import Foundation

// Private SkyLight symbols are not in the SDK's .tbd files, so they are looked up at runtime.
guard let sky = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
      let isSym = dlsym(sky, "CGSIsSymbolicHotKeyEnabled"),
      let setSym = dlsym(sky, "CGSSetSymbolicHotKeyEnabled") else {
  print("\(Date()) SkyLight hotkey symbols not found")
  exit(1)
}
let isEnabled = unsafeBitCast(isSym, to: (@convention(c) (Int32) -> Bool).self)
let setEnabled = unsafeBitCast(setSym, to: (@convention(c) (Int32, Bool) -> Int32).self)

for key: Int32 in [60, 61] where isEnabled(key) {
  let err = setEnabled(key, false)
  print("\(Date()) hotkey \(key) was on, turned off (err=\(err), now enabled=\(isEnabled(key)))")
}
