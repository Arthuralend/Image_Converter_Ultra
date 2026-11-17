# macOS: pthread lives in libc, no extra flags/libs needed.
# Overrides CMake's FindThreads, whose try_compile checks fail on the Xcode 26 runner.
set(Threads_FOUND TRUE)
set(CMAKE_THREAD_LIBS_INIT "")
set(CMAKE_USE_PTHREADS_INIT 1)
set(CMAKE_HAVE_THREADS_LIBRARY 1)
if(NOT TARGET Threads::Threads)
  add_library(Threads::Threads INTERFACE IMPORTED)
endif()
