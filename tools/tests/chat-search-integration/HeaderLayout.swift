import AppKit
import TGUIKit
import SwiftSignalKit

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
  struct SlotState { var canDisplayInline = true }
  var _headerState = SlotState()
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
#if INLINE_UTILITY_HEADERS
  let utility = HeaderSlotFixture(frame: NSMakeRect(0, 0, 900, 36))
  header.primaryView = utility
  header.currentView.addSubview(utility)
  header.updateLayout(size: NSMakeSize(600, 40), transition: .immediate)
  check(utility.frame.height == 40, "utility hit area does not fill the inline glass")
  header.updateLayout(size: NSMakeSize(320, 36), transition: .immediate)
  check(utility.frame.height == 36, "utility kept the inline height in its fallback row")
  header._headerState.canDisplayInline = false
  let secondary = HeaderSlotFixture(frame: NSMakeRect(0, 36, 600, 40))
  header.seconderyView = secondary
  header.updateLayout(size: NSMakeSize(600, 76), transition: .immediate)
  check(utility.frame.height == 36 && secondary.frame.height == 40, "stacked utility slots were stretched to the full header height")
#endif
}

final class HeaderRemovalFixture {
  var currentView: View? = View(frame: NSMakeRect(280, 12, 598, 40))
  var hasLayout = true
  var glassEffect: LiquidGlassView?
  var separatorViews: [View] = []
  let sharedGlassWrapper: GlassContainerView?

  init(_ wrapper: GlassContainerView) {
    sharedGlassWrapper = wrapper
    let ghost = LiquidGlassView(frame: currentView!.frame, cornerRadius: 20)
    glassEffect = ghost
    wrapper.addGhost(ghost)
    wrapper.addSubview(currentView!)
  }

  func remove(animated: Bool, mergeGlassOnRemoval: Bool) {
    __HEADER_REMOVAL__
  }
}

func runHeaderRemovalChecks() {
  let wrapper = GlassContainerView(frame: NSMakeRect(0, 0, 1000, 62), flipped: true, spacing: 5)
  root.addSubview(wrapper)
  let header = HeaderRemovalFixture(wrapper)
  let ghost = header.glassEffect!
  header.remove(animated: true, mergeGlassOnRemoval: true)
  check(header.currentView == nil && !header.hasLayout, "Header removal left stale layout state")
  check(wrapper.ghosts.contains { $0 === ghost }, "Header closing removed its glass before the title expanded")
  check(ghost.effectView.superview != nil, "Header closing detached the native glass surface immediately")
  check(ghost.layer?.animationKeys()?.isEmpty != false, "Header closing fades its glass before merging")
  drain(0.1)
  check(ghost.effectView.superview != nil, "Header closing left a gap during the title expansion")
  let replacement = HeaderRemovalFixture(wrapper)
  let replacementGhost = replacement.glassEffect!
  drain(0.2)
  check(!wrapper.ghosts.contains { $0 === ghost }, "Header closing leaked its old glass after merging")
  check(ghost.effectView.superview == nil, "Header closing left its old glass effect attached")
  check(wrapper.ghosts.contains { $0 === replacementGhost }, "Header reopening lost its replacement glass")
  replacement.remove(animated: false, mergeGlassOnRemoval: true)
  check(wrapper.ghosts.isEmpty, "Header immediate removal retained glass unnecessarily")
  let fallback = HeaderRemovalFixture(wrapper)
  let fallbackGhost = fallback.glassEffect!
  fallback.remove(animated: true, mergeGlassOnRemoval: false)
  check(fallbackGhost.effectView.superview == nil, "Header below the title kept an unwanted glass surface")
  drain(0.3)
  check(wrapper.ghosts.isEmpty, "Header fallback removal leaked its glass")
  wrapper.removeFromSuperview()
}

func runAnimatedGlassCornerChecks() {
  func radius(_ glass: LiquidGlassView) -> CGFloat {
    if #available(macOS 26.0, *), let effect = glass.effectView as? NSGlassEffectView {
      return effect.cornerRadius
    }
    return glass.effectView.layer?.cornerRadius ?? -1
  }
  let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeOut)
  let wrapper = GlassContainerView(frame: NSMakeRect(0, 0, 800, 100), flipped: true)
  root.addSubview(wrapper)
  let shared = LiquidGlassView(frame: NSMakeRect(0, 0, 600, 0), cornerRadius: 20)
  wrapper.addGhost(shared)
  shared.updateLayout(size: shared.bounds.size, transition: .immediate)
  check(radius(shared) == 0, "collapsed shared glass should start with zero radius")
  wrapper.setGhostFrame(shared, frame: NSMakeRect(10, 10, 600, 36), transition: transition)
  check(radius(shared) == 18, "animated shared search glass must restore rounded corners")
  wrapper.setGhostFrame(shared, frame: NSMakeRect(10, 10, 600, 0), transition: .immediate)
  wrapper.setGhostFrame(shared, frame: NSMakeRect(10, 10, 300, 40), transition: transition)
  check(radius(shared) == 20, "reopened shared glass must restore its radius after collapse")
  wrapper.setGhostFrame(shared, frame: NSMakeRect(10, 10, 300, 12), transition: transition)
  check(radius(shared) == 6, "animated shared glass must clamp its radius to the target height")
  let standalone = LiquidGlassView(frame: NSMakeRect(0, 0, 600, 0), cornerRadius: 20)
  root.addSubview(standalone)
  standalone.updateLayout(size: standalone.bounds.size, transition: .immediate)
  standalone.setAnimatorFrame(NSMakeRect(0, 0, 600, 36))
  check(radius(standalone) == 18, "animated standalone glass must restore rounded corners")
  standalone.setAnimatorFrame(NSMakeRect(0, 0, 600, 10))
  check(radius(standalone) == 5, "animated standalone glass must clamp the new radius")
  wrapper.removeFromSuperview()
  standalone.removeFromSuperview()
}
