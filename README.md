# Kirancodes.me

This repository contains the source code for my personal website
[kirancodes.me](https://kirancodes.me).

I've been building my website using Org-mode since 2019, although I
recently redesigned it from scratch and so decided to make the source
public (this required some effort as before the site build was quite
entangled with my .emacs.d which changes frequently).

This repository might be helpful as a resource if you want to build
your own website using org-mode, but the build by itself might not
produce the same as mine as it require packages and languages only
required in my own .emacs.d.

## Build Instructions
To build the site, you can just run `make` from the project root:

```
make
```

The exported html and site structure will be placed in the directory
`~/Documents/kirancodes.me`
## Development
The makefile is more intended for the final publishing of the
project. For editing the website, for example to add new posts
etc. the recommended workflow is to do this directly from Emacs.

1. Launch an `live-server` instance under `~/Documents/kirancodes.me`
  
  ```
  $ cd ~/Documents/kirancodes.me && live-server
  ```

  (if you don't have live-server you can install it with `npm install -g
  live-server`).
  
  The idea here is that when you publish a site, even from within
  emacs, the generated html will be placed under
  `~/Documents/kirancodes.me`, so we'll use the live-server
  application to live reload as soon as any of these html files change.
  
2. From an emacs instance, evaluate `site-config.el`

3. Add org files to this directory and run the command build-project,
   which is bound to `C-c C-c` in org-mode-map



