# macOS/AppleClang: atomics are lock-free natively, no -latomic needed.
# Overrides libjxl's FindAtomics whose try_compile fails on the Xcode 26 runner.
set(ATOMICS_FOUND TRUE)
set(Atomics_FOUND TRUE)
set(ATOMICS_LIBRARIES "")
set(ATOMICS_LOCK_FREE_INSTRUCTIONS TRUE CACHE BOOL "" FORCE)
