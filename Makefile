.PHONY: all publish publish-all all clean

EMACS = emacs-29.4
all: publish-all

publish: site-config.el
	WEBSITE_MODE=t \
          $(EMACS) -nw \
            --load ./site-config.el \
            --funcall build-project \
            --funcall kill-emacs


publish-all: site-config.el
	rm -rf ~/.org-timestamps
	WEBSITE_MODE=t \
          $(EMACS) -nw \
            --load ./site-config.el \
            --funcall build-project-all \
            --funcall kill-emacs


