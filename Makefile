.PHONY: all publish clean

EMACS = ~/.scripts/emacs-29.4/src/emacs
all: publish

publish: site-config.el
	$(EMACS)  --batch --load ~/.emacs.d/init.el  --load ./site-config.el --funcall build-project



