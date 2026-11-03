// Prints the main display's blue gamma at full brightness (1.0 = normal colours), for the
// release smoke test's Evening Mode check.
import CoreGraphics
let display = CGMainDisplayID()
let capacity = Int(CGDisplayGammaTableCapacity(display))
guard capacity > 1 else { print("unsupported"); exit(0) }
var r = [CGGammaValue](repeating: 0, count: capacity), g = r, b = r
var count: UInt32 = 0
guard CGGetDisplayTransferByTable(display, UInt32(capacity), &r, &g, &b, &count) == .success, count > 1 else { print("unsupported"); exit(0) }
print(b[Int(count) - 1])
