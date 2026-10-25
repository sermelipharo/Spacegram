import AppKit
import TGUIKit

final class HeaderSlotFixture: View, ChatHeaderProtocol {
  var animatedLayouts: [Bool] = []
  func update(with: ChatHeaderState, animated: Bool) {}
  func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
    animatedLayouts.append(transition.isAnimated)
  }
  func remove(animated: Bool) {}
  func measure(_ width: CGFloat) {}
}

final class HeaderLayoutFixture {
  let currentView = View(frame: NSMakeRect(12, 62, 976, 40))
  var hasLayout = false
  __SLOT_FIELDS__

  func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
    __SLOT_LAYOUT__
    hasLayout = true
  }

  func placeRoot(_ headerFrame: NSRect, transition: ContainedViewLayoutTransition) {
    let header = self
    __ROOT_LAYOUT__
  }
}

func runHeaderLayoutChecks() {
  let animation = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeOut)
  let header = HeaderLayoutFixture()
  let first = HeaderSlotFixture(frame: NSMakeRect(0, 0, 976, 40))
  header.primaryView = first
  header.currentView.addSubview(first)
  let target = NSMakeRect(280, 12, 598, 40)
  header.placeRoot(target, transition: animation)
  check(header.currentView.frame == target, "Header did not start at its final inline position")
  check(
    header.currentView.layer?.animationKeys()?.isEmpty != false,
    "Header first placement animates from a lower full-width row")
  check(first.animatedLayouts.last == false, "Header first slot layout animates from full width")
  header.updateLayout(size: NSMakeSize(620, 40), transition: animation)
  check(first.animatedLayouts.last == true, "Header stopped animating existing slots on resize")
  first.removeFromSuperview()
  let replacement = HeaderSlotFixture(frame: NSMakeRect(0, 0, 976, 40))
  header.primaryView = replacement
  header.currentView.addSubview(replacement)
  header.updateLayout(size: target.size, transition: animation)
  check(
    replacement.animatedLayouts.last == false,
    "Header replacement slot animates from a stale full-width frame")
  check(
    replacement.layer?.animationKeys()?.isEmpty != false,
    "Header replacement slot has an unexpected frame animation")
}
