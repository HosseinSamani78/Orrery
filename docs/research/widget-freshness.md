# Widget freshness & app/widget state sync

Context pointer for research ticket #5 (resolved). See issue comment: https://github.com/HosseinSamani78/Orrery/issues/5#issuecomment-6492826496

Key points: Text(targetEndDate, style: .timer) for live display; completion via timeline entry; ~40-70 reloads/day/widget budget; App Group + SwiftData shared store; Darwin notify for change signaling; App Intents for interactive controls.
