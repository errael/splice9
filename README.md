## Splice9

Splice9 is a post Vim9.1 plugin for resolving conflicts during three-way merges.

`Splice9` is a pure vim9script port of [Splice](https://github.com/sjl/splice.vim) which is a vimscript/python hybrid.
The original Splice installation documentation and instructions for hooking
up to your Version Control System are still applicable.

Visit [the original site](https://docs.stevelosh.com/splice.vim/) for
installation and other information. There's a video demo.

In vim do `:he Splice`. Splic9 requires `vim9.1`.

<!--
  See [HUD](https://github.com/errael/splice9/wiki/HUD) for a description of the new features.
-->
  See [Dynamic HUD](dynamic-hud) below for a description of the new features.

Some of the Splice9 UI enhancements:
- Additional status info (compact) in the HUD (Heads Up Display).<br>
- The action buttons in the HUD are clickable.
- Rollover highlight for active HUD buttons.
- Click for popup of shortcuts.
- Can specify each action's ":map"/shortcut individually.
- Can set "use meta" and the meta key is used instead of using g:mapleader.
- Version control system configuration the same as original Splice. 

## dynamic HUD

**Heads Up Display**

This page describes capability/status available in the `Splice9 HUD` that is not available in the original Splice. In `vim` do `:help splice` to learn about the `HUD`.

Here is the left part of the `HUD` which illustrates the additional status.

![The HUD](images/HUD-only-partial.png)

Much of the `Splice9 HUD` is active. The active items are in `bold`. When the cursor moves over an active command it is highlighted. `n: next conflict` in the image shows this highlighting. When an active command is highlighted, press the mouse button to execute the command. Note that there are keyboard shortcuts for all the commands.

#### Splice Modes:

This region shows the current mode; `*[p]ath` in this example is highlighted. The modes act as commands, click on a mode and that mode is entered. Each mode has it's own set of layouts available.

#### Layout:

This region shows the arrangement of the open windows and which file/buffer is loaded into the window. When `Splice9` is diffing files, the files participating in the diff are highlighted; they are `Original` and `One` in this example.

#### Splice Commands:

The label of this region, `Splice Commands:`, is active. Click on it to display a popup which has each command with its associated keyboard shortcut.

The command `D: diffs off` has embedded status information. When `Splice9` is diffing files there is a `*` displayed after the `D:`; this is shown in the image above. When the `*` is displayed, clicking on this command (or using the shortcut), turns off diffing.

The command `s: toggle scrollbind` also has a `*` indicator; it means that `scrollbind` is on. Note that `scrollbind` automatically goes on when diffing, the files that participate in the diff are in `scrollbind`. When not diffing, click on `scrollbind` so displayed files scroll together.


**Following is TODO**

## configuration

