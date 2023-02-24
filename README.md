# viOS

https://user-images.githubusercontent.com/35064754/221260670-3c2df571-ca44-4985-b3cc-175a59e526aa.mp4

*And you thought vi couldn't be an operating system, Emacs user!*

viOS is an operating system that runs vi, in form of a BIOS bootloader.

Supported vi motions:

* <kbd>h</kbd>
* <kbd>l</kbd>
* <kbd>W</kbd>
* <kbd>0</kbd>, <kbd>$</kbd>
* <kbd>_</kbd>
* <kbd>x</kbd>, <kbd>X</kbd>
* <kbd>i</kbd>, <kbd>a</kbd>
* <kbd>I</kbd>, <kbd>A</kbd>

## Running

Requires NASM and QEMU.

```
./run.sh
```

## Known bugs and limitations

* Cursor corrupts when pressing <kbd>W</kbd> and no space follows.
* No multiline support; I quickly ran out of bytes and couldn't add any more features.
