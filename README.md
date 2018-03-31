Bugzilla Harmony for D
======================

This repository contains related auxiliary files and tracks issues for the next proposed platform for [issues.dlang.org](https://issues.dlang.org/) (D's bugtracker).

The [platform software](https://github.com/CyberShadow/bmo) is based on [Bugzilla Harmony](https://github.com/bugzilla/harmony), a Mozilla project to adapt and mainline the improvements of [BMO](https://github.com/mozilla-bteam/bmo), the software powering [bugzilla.mozilla.org](http://bugzilla.mozilla.org/), which is itself a fork of [Bugzilla](https://www.bugzilla.org/).

Getting Started
---------------

On a GNU/Linux system, clone this repository and run the `init.sh` script. It will attempt to fully automatically set up and start a completely self-contained development environment, including a MySQL and web server, ready to hack on the Bugzilla code (which will be cloned to the `src/` subdirectory).

See `notes.org` and [the GitHub issue list](https://github.com/CyberShadow/bugzilla-meta/issues) for things to do.
