# nnn preview daemon

The daemon receives the selected path over a private Unix socket, keeps the
files from its directory in a sorted list, and sends the selected file to
GNOME Sushi. It also follows nnn's `NNN_FIFO`, so arrows stay in nnn while
Sushi is a non-focused overlay and the preview follows the hovered file.

The executable without arguments is the long-running service. Passing a path
is the client mode used by the nnn key binding.
