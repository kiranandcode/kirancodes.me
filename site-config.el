(use-package dash :straight t)
(use-package modus-themes
  :straight (modus-themes :type git :host github :repo "protesilaos/modus-themes"))
(require 'ox-publish)
(require 'dash)
(require 'htmlize)
;; (load-theme 'lab-light)
(load-theme 'modus-operandi)


;;;; Better Useful ids

(defun org-export-get-reference (datum info)
  "Like `org-export-get-reference', except uses heading titles instead of random numbers."
  (let ((cache (plist-get info :internal-references)))
    (or (car (rassq datum cache))
        (let* ((crossrefs (plist-get info :crossrefs))
               (cells (org-export-search-cells datum))
               ;; Preserve any pre-existing association between
               ;; a search cell and a reference, i.e., when some
               ;; previously published document referenced a location
               ;; within current file (see
               ;; `org-publish-resolve-external-link').
               ;;
               ;; However, there is no guarantee that search cells are
               ;; unique, e.g., there might be duplicate custom ID or
               ;; two headings with the same title in the file.
               ;;
               ;; As a consequence, before re-using any reference to
               ;; an element or object, we check that it doesn't refer
               ;; to a previous element or object.
               (new (or (cl-some
                         (lambda (cell)
                           (let ((stored (cdr (assoc cell crossrefs))))
                             (when stored
                               (let ((old (if (numberp stored)
                                              (org-export-format-reference stored)
                                            stored)))
                                 (and (not (assoc old cache)) stored)))))
                         cells)
                        (when (org-element-property :raw-value datum)
                          ;; Heading with a title
                          (org-export-new-title-reference datum cache))
                        ;; NOTE: This probably breaks some Org Export
                        ;; feature, but if it does what I need, fine.
                        (org-export-format-reference
                         (org-export-new-reference cache))))
               (reference-string new))
          ;; Cache contains both data already associated to
          ;; a reference and in-use internal references, so as to make
          ;; unique references.
          (dolist (cell cells) (push (cons cell new) cache))
          ;; Retain a direct association between reference string and
          ;; DATUM since (1) not every object or element can be given
          ;; a search cell (2) it permits quick lookup.
          (push (cons reference-string datum) cache)
          (plist-put info :internal-references cache)
          reference-string))))

(defun org-export-new-title-reference (datum cache)
  "Return new reference for DATUM that is unique in CACHE."
  (cl-macrolet ((inc-suffixf (place)
                  `(progn
                     (string-match (rx bos
                                       (minimal-match (group (1+ anything)))
                                       (optional "--" (group (1+ digit)))
                                       eos)
                                   ,place)
                     ;; HACK: `s1' instead of a gensym.
                     (-let* (((s1 suffix) (list (match-string 1 ,place)
                                                (match-string 2 ,place)))
                             (suffix (if suffix
                                         (string-to-number suffix)
                                       0)))
                       (setf ,place (format "%s--%s" s1 (cl-incf suffix)))))))
    (let* ((title (org-element-property :raw-value datum))
           (ref (url-hexify-string (substring-no-properties title)))
           (parent (org-element-property :parent datum)))
      (while (--any (equal ref (car it))
                    cache)
        ;; Title not unique: make it so.
        (if parent
            ;; Append ancestor title.
            (setf title (concat (org-element-property :raw-value parent)
                                "--" title)
                  ref (url-hexify-string (substring-no-properties title))
                  parent (org-element-property :parent parent))
          ;; No more ancestors: add and increment a number.
          (inc-suffixf ref)))
      ref)))

;;;; Quick Build keybind

(defun build-project ()
  (interactive)
  (save-window-excursion
    (switch-to-buffer "init-orgpublish-latest.el")
    (eval-buffer)
    (org-publish "kirancodes.me" t))
)

(bind-key (kbd "C-c C-c") #'build-project)
(bind-key (kbd "C-c C-c") #'build-project 'org-mode-map)

;;;; Variables

(defun html-dir (&rest segments)
  (apply #'concat
         (file-name-as-directory org-directory)
         "html-new/"
         (mapcar #'file-name-as-directory segments)))

(defvar build-dir
  (expand-file-name "~/Documents/kirancodes.me/")
  ;; (concat (file-name-as-directory org-directory) "build/")
  )
(setq org-html-preamble-format
      `(("en"

         "<header>
      <div class=\"header-container border-trans-pink width-container\">
        <div class=\"header-logo-container\">
          <a href=\"/\">
            <img class=\"header-img\" src=\"/images/banner.svg\" height=\"40\" width=\"280\"/>
        </a>
        </div>
        <div class=\"header-motto-container\">
          <span>To Proof Maintenance & Beyond!</span>
        </div>
      </div>
    </header>")))
(setq org-html-postamble-format
      `(("en"
         "    <footer class=\"footer\">
      <div class=\"width-container\">
        <div class=\"footer-block\">
          <div class=\"footer-block-item footer-block-item-grow mx-2.5 mb-2.5\">
            <img src=\"/images/public-domain.svg\" height=\"30\" width=\"148\"/>
            <span>All content is available under the <a class=\"footer-link\" href=\"https://creativecommons.org/publicdomain/zero/1.0/\">Creative Commons Zero License v1.0</a>, except where otherwise stated</span>
          </div>
          <div class=\"footer-block-item\">
            <a class=\"footer-logo footer-link\">Abolish Copyright ©</a>
          </div>
        </div>
      </div>
</footer>")))
(setq org-html-footnotes-section "<div id=\"footnotes\" class=\"grid-row\">
<div class=\"grid-column-full\">
<h2 class=\"heading-m footnotes\">%s</h2>
<div id=\"text-footnotes\">
%s
</div>
</div>
</div>"
      )
(setq org-html-footnote-format "<sup>%s</sup>")


(setq org-html-htmlize-output-type 'inline-css)
(setq org-html-table-header-tags '("<th class=\"table-header\" scope=\"%s\"%s>" . "</th>"))
(setq org-html-table-data-tags '("<td class=\"table-cell\" scope=\"%s\">" . "</td>"))
(setq org-html-table-row-open-tag "<tr class=\"table-row\">")
(setq org-html-link-home "127.0.0.1:36573")

;;;; Helpers
;;;;; Quoted Snippet
(defun org-html-is-quoted-snippet (node)
  (--any? (equal (org-element-property :back-end it) "html") (org-element-contents node)))

;;;;; Level to Headings
(defun org-html-level-to-heading-class  (level)
  "Converts a heading level to a class"
  (message "org-html-level-to-heading-class %S" level)
  (format "heading-%s"
          (pcase level
            (1 "xl")
            (2 "l")
            (3 "m")
            (_ "s"))))

;;;;; Level to Caption's
(defun org-html-level-to-caption-class  (level)
  "Converts a heading level to a class"
  (message "org-html-level-to-caption-class %S" level)
  (format "caption-%s"
          (pcase level
            (1 "xl")
            (2 "l")
            (3 "m")
            (_ "s"))))

;;;;; Navigation bar
(defun org-html--build-navigation-bar (info)
  (message "org-html--build-nav-bar %S" (plist-get info  :nav-section))
  (cond
   ((and (plist-get info :nav-section)
         (plist-get info :nav-sections)
         (listp (plist-get info :nav-sections)))
    (let ((curr-section (plist-get info :nav-section))
          (sections (plist-get info :nav-sections)))
      (message "org-html--build-navigation-bar %S" curr-section)
      (apply #'concat
             (append
              '("<nav class=\"navigation\">
      <ul class=\"navigation-list width-container\">")
              (mapcar (lambda (section)
                        (concat
                         "<li class=\"navigation-list-item"
                         (if (equal (car (org-element-contents section)) curr-section)
                             " navigation-list-item--current"
                           "")
                         "\">"
                         (org-html-link section (car (org-element-contents section)) info)
                         "</li>")
                        ) sections)
              '("      </ul>
    </nav>")
              ))))
   
   (t "")))
(defun org-html--build-breadcrumbs (info)
  (cond
   ((plist-get info :nav-sections) "")
   (t 
      (let ((breadcrumbs (org-publish-generate-navigation-breadcrumbs info)))
        (apply
         #'concat
         (append
          '("<nav class=\"breadcrumbs\">
        <ol class=\"breadcrumbs-list\">")
          (mapcar (lambda (pair)
                    (format "
          <li class=\"breadcrumbs-list-item\">
            <a class=\"breadcrumbs-link\" href=\"%s\">
              %s
          </a>
          </li>" (cdr pair) (car pair))) breadcrumbs)
          '("
        </ol>
      </nav>")
          ))

        ))))

;;;;; Nav Breadcrumbs 
(defun org-publish-generate-navigation-breadcrumbs (info)
  "Generate a navigation breadcrumbs list based on INFO plist.

INFO should contain:
- :input-file - Full path of the current input Org file.
- :base-directory - The base directory of the Org files.

The function searches parent directories for .org files to build navigation links."
  (let* ((input-file (plist-get info :input-file))
         (base-directory (plist-get info :base-directory))
         (home-link '("Home" . "/index.html"))  ;; Always include Home
         (links (list home-link))              ;; Initialize with Home
         (current-dir (file-name-directory input-file)))
    ;; Traverse up the directory tree
    (while (and current-dir
                (not (string= (expand-file-name current-dir)
                              (expand-file-name base-directory))))
      (let* ((parent-file (concat (directory-file-name current-dir) ".org"))
             (file-title (when (file-exists-p parent-file)
                           (capitalize (file-name-base parent-file))
                           ;; (org-html-get-file-property parent-file :title)
                           )))
        (when file-title
          ;; Create the navigation link
          (let* ((relative-path (file-relative-name parent-file base-directory))
                 (html-path (concat "/" (file-name-sans-extension relative-path) ".html")))
            (push (cons file-title html-path) links))))
      ;; Move up one directory
      (setq current-dir (file-name-directory (directory-file-name current-dir))))
    (nreverse links)))

(defun org-html-get-file-property (file property)
  "Extract the title from the Org FILE. If no title is found, use the file name."
  (let* ((org-inhibit-startup t))
    (plist-get (org-with-file-buffer file
		 (if (not org-file-buffer-created)
                     (org-export-get-environment 'html)
		   ;; Protect local variables in open buffers.
		   (org-export-with-buffer-copy
		    (org-export-get-environment 'html))))
	       property)))  ;; Fallback to file name

;;;;; Custom sitemap 
(defun org-list-filter-empty-strings (ls)
  (cond
   ((null ls) ls)
   ((consp ls)
    (let ((head (org-list-filter-empty-strings (car ls)))
          (tail (org-list-filter-empty-strings (cdr ls))))
      (if head (cons head tail) tail)))
   ((stringp ls)
    (if (string-empty-p ls) nil ls))
   (t ls)))

(defun org-publish-sitemap-custom (title list)
  (concat
   "#+TITLE: " title "\n"
   "#+NAV_SECTIONS: [[file:index.org][About Me]] [[file:index.org::*Publications][Publications]]  [[file:art.org][Artwork]] [[file:posts.org][Posts]]\n"
   "#+NAV_SECTION: Posts\n\n"
   "* Kiran's Blog Posts\n"
   ":PROPERTIES:\n"
   ":subtitle: My Ramblings on Life, Software, Games and Everything\n"
   ":END:\n"
   (org-list-to-org (org-list-filter-empty-strings list))))

(defun org-publish-sitemap-custom-entry (entry style project)
  "Default format for site map ENTRY, as a string.
ENTRY is a file name.  STYLE is the style of the sitemap.
PROJECT is the current project."
  (cond ((not (directory-name-p entry))
         (if (equal (org-publish-find-property entry :hidden project 'html) "true") ""
           (format "[[file:%s][%s - %s]]"
		   entry
                   (format-time-string
                    "%d %b, %Y"
                    (org-publish-find-date entry project))
		   (org-publish-find-title entry project))))
	((eq style 'tree)
	 ;; Return only last subdir.
	 (file-name-nondirectory (directory-file-name entry)))
	(t entry)))

;;;;; Custom Headlines 

(defun org-html--custom-tags (tags info)
  "Format TAGS into HTML.
INFO is a plist containing export options."
  (when tags
    (mapconcat
     (lambda (tag)
       (format "<span class=\"tag\"><span class=\"%s\">%s</span></span>"
	       (concat (plist-get info :html-tag-class-prefix)
		       (org-html-fix-class-name tag))
	       tag))
     tags "&#xa0;")))

(defun org-html-format-headline-custom-function
    (todo _todo-type priority text tags info)
  "Default format function for a headline.
See `org-html-format-headline-function' for details and the
description of TODO, PRIORITY, TEXT, TAGS, and INFO arguments."
  (let ((todo (org-html--todo todo info))
	(priority (org-html--priority priority info))
	(tags (org-html--custom-tags tags info))
        (date (and
               (plist-get info :date)
               (car (plist-get info :date))
               (org-format-timestamp (car (plist-get info :date)) "%d %b, %Y")))
        (date-machine
         (and
          (plist-get info :date)
          (car (plist-get info :date))
          (org-format-timestamp (car (plist-get info :date)) "%Y-%m-%d"))))
    (concat todo (and todo " ")
	    priority (and priority " ")
	    text
            "<br/>"
            (if (and date tags)
                (format "<span class=\"date\"><time datetime=\"%s\">%s</time></span>" date-machine date)
              "")
	    (and tags "&#xa0;&#xa0;&#xa0;") tags)))
;;;;; Custom warnings
(defun org-html--build-warning (text)
  (format "<div class=\"grid-row\">
<div class=\"grid-full-column\">
 <div class=\"phase-banner inset-text\">
<div class=\"phase-banner-content\">
<span class=\"tag phase-banner-content-tag\">Warning</span>
<span class=\"phase-banner-text\">
%s
</span>
</div>
</div>
</div>
</div>" text))
;;;; Overrides 
;;;;; Backend 
(org-export-define-backend 'html
  '((bold . org-html-bold)
    (center-block . org-html-center-block)
    (clock . org-html-clock)
    (code . org-html-code)
    (drawer . org-html-drawer)
    (dynamic-block . org-html-dynamic-block)
    (entity . org-html-entity)
    (example-block . org-html-example-block)
    (export-block . org-html-export-block)
    (export-snippet . org-html-export-snippet)
    (fixed-width . org-html-fixed-width)
    (footnote-reference . org-html-footnote-reference)
    (headline . org-html-headline)
    (horizontal-rule . org-html-horizontal-rule)
    (inline-src-block . org-html-inline-src-block)
    (inlinetask . org-html-inlinetask)
    (inner-template . org-html-inner-template)
    (italic . org-html-italic)
    (item . org-html-item)
    (keyword . org-html-keyword)
    (latex-environment . org-html-latex-environment)
    (latex-fragment . org-html-latex-fragment)
    (line-break . org-html-line-break)
    (link . org-html-link)
    (node-property . org-html-node-property)
    (paragraph . org-html-paragraph)
    (plain-list . org-html-plain-list)
    (plain-text . org-html-plain-text)
    (planning . org-html-planning)
    (property-drawer . org-html-property-drawer)
    (quote-block . org-html-quote-block)
    (radio-target . org-html-radio-target)
    (section . org-html-section)
    (special-block . org-html-special-block)
    (src-block . org-html-src-block)
    (statistics-cookie . org-html-statistics-cookie)
    (strike-through . org-html-strike-through)
    (subscript . org-html-subscript)
    (superscript . org-html-superscript)
    (table . org-html-table)
    (table-cell . org-html-table-cell)
    (table-row . org-html-table-row)
    (target . org-html-target)
    (template . org-html-template)
    (timestamp . org-html-timestamp)
    (underline . org-html-underline)
    (verbatim . org-html-verbatim)
    (verse-block . org-html-verse-block))
  :filters-alist '((:filter-options . org-html-infojs-install-script)
		   (:filter-parse-tree . org-html-image-link-filter)
		   (:filter-final-output . org-html-final-function))
  :menu-entry
  '(?h "Export to HTML"
       ((?H "As HTML buffer" org-html-export-as-html)
	(?h "As HTML file" org-html-export-to-html)
	(?o "As HTML file and open"
	    (lambda (a s v b)
	      (if a (org-html-export-to-html t s v b)
		(org-open-file (org-html-export-to-html nil s v b)))))))
  :options-alist
  '((:html-doctype "HTML_DOCTYPE" nil org-html-doctype)
    (:html-container "HTML_CONTAINER" nil org-html-container-element)
    (:html-content-class "HTML_CONTENT_CLASS" nil org-html-content-class)
    (:description "DESCRIPTION" nil nil newline)
    (:keywords "KEYWORDS" nil nil space)
    (:html-html5-fancy nil "html5-fancy" org-html-html5-fancy)
    (:html-link-use-abs-url nil "html-link-use-abs-url" org-html-link-use-abs-url)
    (:html-link-home "HTML_LINK_HOME" nil org-html-link-home)
    (:html-link-up "HTML_LINK_UP" nil org-html-link-up)
    (:html-mathjax "HTML_MATHJAX" nil "" space)
    (:html-equation-reference-format "HTML_EQUATION_REFERENCE_FORMAT" nil org-html-equation-reference-format t)
    (:html-postamble nil "html-postamble" org-html-postamble)
    (:html-preamble nil "html-preamble" org-html-preamble)
    (:html-head "HTML_HEAD" nil org-html-head newline)
    (:html-head-extra "HTML_HEAD_EXTRA" nil org-html-head-extra newline)
    (:subtitle "SUBTITLE" nil nil parse)
    (:html-head-include-default-style
     nil "html-style" org-html-head-include-default-style)
    (:html-head-include-scripts nil "html-scripts" org-html-head-include-scripts)
    (:html-allow-name-attribute-in-anchors
     nil nil org-html-allow-name-attribute-in-anchors)
    (:html-divs nil nil org-html-divs)
    (:html-checkbox-type nil nil org-html-checkbox-type)
    (:html-extension nil nil org-html-extension)
    (:html-footnote-format nil nil org-html-footnote-format)
    (:html-footnote-separator nil nil org-html-footnote-separator)
    (:html-footnotes-section nil nil org-html-footnotes-section)
    (:html-format-drawer-function nil nil org-html-format-drawer-function)
    (:html-format-headline-function nil nil org-html-format-headline-function)
    (:html-format-inlinetask-function
     nil nil org-html-format-inlinetask-function)
    (:html-home/up-format nil nil org-html-home/up-format)
    (:html-indent nil nil org-html-indent)
    (:html-infojs-options nil nil org-html-infojs-options)
    (:html-infojs-template nil nil org-html-infojs-template)
    (:html-inline-image-rules nil nil org-html-inline-image-rules)
    (:html-link-org-files-as-html nil nil org-html-link-org-files-as-html)
    (:html-mathjax-options nil nil org-html-mathjax-options)
    (:html-mathjax-template nil nil org-html-mathjax-template)
    (:html-metadata-timestamp-format nil nil org-html-metadata-timestamp-format)
    (:html-postamble-format nil nil org-html-postamble-format)
    (:html-preamble-format nil nil org-html-preamble-format)
    (:html-prefer-user-labels nil nil org-html-prefer-user-labels)
    (:html-self-link-headlines nil nil org-html-self-link-headlines)
    (:html-table-align-individual-fields
     nil nil org-html-table-align-individual-fields)
    (:html-table-caption-above nil nil org-html-table-caption-above)
    (:html-table-data-tags nil nil org-html-table-data-tags)
    (:html-table-header-tags nil nil org-html-table-header-tags)
    (:html-table-use-header-tags-for-first-column
     nil nil org-html-table-use-header-tags-for-first-column)
    (:html-tag-class-prefix nil nil org-html-tag-class-prefix)
    (:html-text-markup-alist nil nil org-html-text-markup-alist)
    (:html-todo-kwd-class-prefix nil nil org-html-todo-kwd-class-prefix)
    (:html-toplevel-hlevel nil nil org-html-toplevel-hlevel)
    (:html-use-infojs nil nil org-html-use-infojs)
    (:html-validation-link nil nil org-html-validation-link)
    (:html-viewport nil nil org-html-viewport)
    (:html-inline-images nil nil org-html-inline-images)
    (:html-table-attributes nil nil org-html-table-default-attributes)
    (:html-table-row-open-tag nil nil org-html-table-row-open-tag)
    (:html-table-row-close-tag nil nil org-html-table-row-close-tag)
    (:html-xml-declaration nil nil org-html-xml-declaration)
    (:html-wrap-src-lines nil nil org-html-wrap-src-lines)
    (:html-klipsify-src nil nil org-html-klipsify-src)
    (:html-klipse-css nil nil org-html-klipse-css)
    (:html-klipse-js nil nil org-html-klipse-js)
    (:html-klipse-selection-script nil nil org-html-klipse-selection-script)
    (:infojs-opt "INFOJS_OPT" nil nil)
    ;; Redefine regular options.
    (:creator "CREATOR" nil org-html-creator-string)
    (:with-latex nil "tex" org-html-with-latex)
    ;; Retrieve LaTeX header for fragments.
    (:latex-header "LATEX_HEADER" nil nil newline)
    ;; Custom options for custom html
    (:nav-sections "NAV_SECTIONS" nil nil parse)
    (:nav-section "NAV_SECTION" nil nil newline)
    (:hidden "HIDDEN" nil nil newline)
    (:warning "WARNING" nil nil newline)
    ))
;;  I wish there was a better way
;;;;; Get Reference 
(defun org-export-format-reference (reference)
  "Format REFERENCE into a string.
REFERENCE is a number representing a reference, as returned by
`org-export-new-reference', which see."
  (if (numberp reference)
      (format "org%07x" reference)
    reference))
;;;;; Link 
(defun org-html-link (link desc info)
  "Transcode a LINK object from Org to HTML.
DESC is the description part of the link, or the empty string.
INFO is a plist holding contextual information.  See
`org-export-data'."
  (let* ((html-ext (plist-get info :html-extension))
	 (dot (when (> (length html-ext) 0) "."))
	 (link-org-files-as-html-maybe
	  (lambda (raw-path info)
	    ;; Treat links to `file.org' as links to `file.html', if
	    ;; needed.  See `org-html-link-org-files-as-html'.
            (save-match-data
	      (cond
	       ((and (plist-get info :html-link-org-files-as-html)
                     (let ((case-fold-search t))
                       (string-match "\\(.+\\)\\.org\\(?:\\.gpg\\)?$" raw-path)))
	        (concat (match-string 1 raw-path) dot html-ext))
	       (t raw-path)))))
	 (type (org-element-property :type link))
	 (raw-path (org-element-property :path link))
	 ;; Ensure DESC really exists, or set it to nil.
	 (desc (org-string-nw-p desc))
	 (path
	  (cond
	   ((string= "file" type)
	    ;; During publishing, turn absolute file names belonging
	    ;; to base directory into relative file names.  Otherwise,
	    ;; append "file" protocol to absolute file name.
	    (setq raw-path
		  (org-export-file-uri
		   (org-publish-file-relative-name raw-path info)))
	    ;; Possibly append `:html-link-home' to relative file
	    ;; name.
	    (let ((home (and (plist-get info :html-link-home)
			     (org-trim (plist-get info :html-link-home)))))
	      (when (and home
			 (plist-get info :html-link-use-abs-url)
			 (not (file-name-absolute-p raw-path)))
		(setq raw-path (concat (file-name-as-directory home) raw-path))))
	    ;; Maybe turn ".org" into ".html".
	    (setq raw-path (funcall link-org-files-as-html-maybe raw-path info))
	    ;; Add search option, if any.  A search option can be
	    ;; relative to a custom-id, a headline title, a name or
	    ;; a target.
	    (let ((option (org-element-property :search-option link)))
	      (if (not option) raw-path
		(let ((path (org-element-property :path link)))
		  (concat raw-path
			  "#"
			  (org-publish-resolve-external-link option path t))))))
	   (t (url-encode-url (concat type ":" raw-path)))))
	 (attributes-plist
	  (org-combine-plists
	   ;; Extract attributes from parent's paragraph.  HACK: Only
	   ;; do this for the first link in parent (inner image link
	   ;; for inline images).  This is needed as long as
	   ;; attributes cannot be set on a per link basis.
	   (let* ((parent (org-element-parent-element link))
		  (link (let ((container (org-element-parent link)))
			  (if (and (org-element-type-p container 'link)
				   (org-html-inline-image-p link info))
			      container
			    link))))
	     (and (eq link (org-element-map parent 'link #'identity info t))
		  (org-export-read-attribute :attr_html parent)))
	   ;; Also add attributes from link itself.  Currently, those
	   ;; need to be added programmatically before `org-html-link'
	   ;; is invoked, for example, by backends building upon HTML
	   ;; export.
	   (org-export-read-attribute :attr_html link)))
	 (attributes
	  (let ((attr (org-html--make-attribute-string attributes-plist)))
	    (if (org-string-nw-p attr) (concat " " attr) ""))))
    (cond
     ;; Link type is handled by a special function.
     ((org-export-custom-protocol-maybe link desc 'html info))
     ;; Image file.
     ((and (plist-get info :html-inline-images)
	   (org-export-inline-image-p
	    link (plist-get info :html-inline-image-rules)))
      (org-html--format-image path attributes-plist info))
     ;; Radio target: Transcode target's contents and use them as
     ;; link's description.
     ((string= type "radio")
      (let ((destination (org-export-resolve-radio-link link info)))
	(if (not destination) desc
	  (format "<a class=\"link\" href=\"#%s\"%s>%s</a>"
		  (org-export-get-reference destination info)
		  attributes
		  desc))))
     ;; Links pointing to a headline: Find destination and build
     ;; appropriate referencing command.
     ((member type '("custom-id" "fuzzy" "id"))
      (let ((destination (if (string= type "fuzzy")
			     (org-export-resolve-fuzzy-link link info)
			   (org-export-resolve-id-link link info))))
	(pcase (org-element-type destination)
	  ;; ID link points to an external file.
	  (`plain-text
	   (let ((fragment (concat org-html--id-attr-prefix raw-path))
		 ;; Treat links to ".org" files as ".html", if needed.
		 (path (funcall link-org-files-as-html-maybe
				destination info)))
	     (format "<a class=\"link\" href=\"%s#%s\"%s>%s</a>"
		     path fragment attributes (or desc destination))))
	  ;; Fuzzy link points nowhere.
	  (`nil
	   (format "<i>%s</i>"
		   (or desc
		       (org-export-data
			(org-element-property :raw-link link) info))))
	  ;; Link points to a headline.
	  (`headline
	   (let ((href (org-html--reference destination info))
		 ;; What description to use?
		 (desc
		  ;; Case 1: Headline is numbered and LINK has no
		  ;; description.  Display section number.
		  (if (and (org-export-numbered-headline-p destination info)
			   (not desc))
		      (mapconcat #'number-to-string
				 (org-export-get-headline-number
				  destination info) ".")
		    ;; Case 2: Either the headline is un-numbered or
		    ;; LINK has a custom description.  Display LINK's
		    ;; description or headline's title.
		    (or desc
			(org-export-data
			 (org-element-property :title destination) info)))))
	     (format "<a class=\"link\" href=\"#%s\"%s>%s</a>" href attributes desc)))
	  ;; Fuzzy link points to a target or an element.
	  (_
           (if (and destination
                    (memq (plist-get info :with-latex) '(mathjax t))
                    (org-element-type-p destination 'latex-environment)
                    (eq 'math (org-latex--environment-type destination)))
               ;; Caption and labels are introduced within LaTeX
	       ;; environment.  Use "ref" or "eqref" macro, depending on user
               ;; preference to refer to those in the document.
               (format (plist-get info :html-equation-reference-format)
                       (org-html--reference destination info))
             (let* ((ref (org-html--reference destination info))
                    (org-html-standalone-image-predicate
                     #'org-html--has-caption-p)
                    (counter-predicate
                     (if (org-element-type-p destination 'latex-environment)
                         #'org-html--math-environment-p
                       #'org-html--has-caption-p))
                    (number
		     (cond
		      (desc nil)
		      ((org-html-standalone-image-p destination info)
		       (org-export-get-ordinal
			(org-element-map destination 'link #'identity info t)
			info '(link) 'org-html-standalone-image-p))
		      (t (org-export-get-ordinal
			  destination info nil counter-predicate))))
                    (desc
		     (cond (desc)
			   ((not number) "No description for this link")
			   ((numberp number) (number-to-string number))
			   (t (mapconcat #'number-to-string number ".")))))
               (format "<a class=\"link\" href=\"#%s\"%s>%s</a>" ref attributes desc)))))))
     ;; Coderef: replace link with the reference name or the
     ;; equivalent line number.
     ((string= type "coderef")
      (let ((fragment (concat "coderef-" (org-html-encode-plain-text raw-path))))
	(format "<a class=\"link\" href=\"#%s\" %s%s>%s</a>"
		fragment
		(format "class=\"coderef\" onmouseover=\"CodeHighlightOn(this, \
'%s');\" onmouseout=\"CodeHighlightOff(this, '%s');\""
			fragment fragment)
		attributes
		(format (org-export-get-coderef-format raw-path desc)
			(org-export-resolve-coderef raw-path info)))))
     ;; External link with a description part.
     ((and path desc)
      (format "<a class=\"link\" href=\"%s\"%s>%s</a>"
	      (org-html-encode-plain-text path)
	      attributes
	      desc))
     ;; External link without a description part.
     (path
      (let ((path (org-html-encode-plain-text path)))
	(format "<a class=\"link\" href=\"%s\"%s>%s</a>" path attributes path)))
     ;; No path, only description.  Try to do something useful.
     (t
      (format "<i>%s</i>" desc)))))

;;;;; List 
(defun org-html-plain-list (plain-list contents _info)
  "Transcode a PLAIN-LIST element from Org to HTML.
CONTENTS is the contents of the list.  INFO is a plist holding
contextual information."
  (let* ((type (pcase (org-element-property :type plain-list)
		 (`ordered "ol")
		 (`unordered "ul")
		 (`descriptive "dl")
		 (other (error "Unknown HTML list type: %s" other))))
         (attributes (org-export-read-attribute :attr_html plain-list))
         (list-class
          (if (not (and (plist-get attributes :class)
                        (or
                         (s-contains? "list--number" (plist-get attributes :class))
                         (s-contains? "list--bullet" (plist-get attributes :class)))))
              (pcase (org-element-property :type plain-list)
	        (`ordered "list--number")
	        (`unordered "list--bullet")
	        (`descriptive "")
	        (other (error "Unknown HTML list type: %s" other)))
            ""))
	 (class (format "org-%s %s list--spaced" type list-class))
	 )
    (format "<%s %s>\n%s</%s>"
	    type
	    (org-html--make-attribute-string
	     (plist-put attributes :class
			(org-trim
			 (mapconcat #'identity
				    (list class (plist-get attributes :class))
				    " "))))
	    contents
	    type)))
;;;;; Quote 
(defun org-html-quote-block (quote-block contents info)
  "Transcode a QUOTE-BLOCK element from Org to HTML.
CONTENTS holds the contents of the block.  INFO is a plist
holding contextual information."
  (format "<blockquote class=\"inset-text\" %s>\n%s</blockquote>"
	  (let* ((reference (org-html--reference quote-block info t))
		 (attributes (org-export-read-attribute :attr_html quote-block))
		 (a (org-html--make-attribute-string
		     (if (or (not reference) (plist-member attributes :id))
			 attributes
		       (plist-put attributes :id reference)))))
	    (if (org-string-nw-p a) (concat " " a) ""))
	  contents))
;;;;; Table 
(defun org-html-table (table contents info)
  "Transcode a TABLE element from Org to HTML.
CONTENTS is the contents of the table.  INFO is a plist holding
contextual information."
  (if (eq (org-element-property :type table) 'table.el)
      ;; "table.el" table.  Convert it using appropriate tools.
      (org-html-table--table.el-table table info)
    ;; Standard table.
    (let* ((caption (org-export-get-caption table))
	   (number (org-export-get-ordinal
		    table info nil #'org-html--has-caption-p))
	   (attributes
	    (org-html--make-attribute-string
	     (org-combine-plists
	      (list :id (org-html--reference table info t))
	      (and (not (org-html-html5-p info))
		   (plist-get info :html-table-attributes))
	      (org-export-read-attribute :attr_html table))))
	   (alignspec
	    (if (bound-and-true-p org-html-format-table-no-css)
		"align=\"%s\""
	      "class=\"org-%s\""))
	   (table-column-specs
	    (lambda (table info)
	      (mapconcat
	       (lambda (table-cell)
		 (let ((alignment (org-export-table-cell-alignment
				   table-cell info)))
		   (concat
		    ;; Begin a colgroup?
		    (when (org-export-table-cell-starts-colgroup-p
			   table-cell info)
		      "\n<colgroup>")
		    ;; Add a column.  Also specify its alignment.
		    (format "\n%s"
			    (org-html-close-tag
			     "col" (concat " " (format alignspec alignment)) info))
		    ;; End a colgroup?
		    (when (org-export-table-cell-ends-colgroup-p
			   table-cell info)
		      "\n</colgroup>"))))
	       (org-html-table-first-row-data-cells table info) "\n"))))
      (format "<table class=\"table\" %s>\n%s\n%s\n%s</table>"
	      (if (equal attributes "") "" (concat " " attributes))
	      (if (not caption) ""
		(format (if (plist-get info :html-table-caption-above)
			    "<caption class=\"t-above\">%s</caption>"
			  "<caption class=\"t-bottom\">%s</caption>")
			(concat
			 "<span class=\"table-number\">"
			 (format (org-html--translate "Table %d:" info) number)
			 "</span> " (org-export-data caption info))))
	      (funcall table-column-specs table info)
	      contents))))
;;;;; Paragraph
(defun org-html-paragraph (paragraph contents info)
  "Transcode a PARAGRAPH element from Org to HTML.
CONTENTS is the contents of the paragraph, as a string.  INFO is
the plist used as a communication channel."
  (let* ((parent (org-export-get-parent paragraph))
	 (parent-type (org-element-type parent))
	 (style '((footnote-definition " class=\"footpara\"")
		  (org-data " class=\"footpara\"")))
	 (attributes (org-html--make-attribute-string
		      (org-export-read-attribute :attr_html paragraph)))
	 (extra (or (cadr (assq parent-type style)) "")))
    (cond
     ((string-empty-p (string-trim contents)) "")
     ((and (eq parent-type 'item)
	   (not (org-export-get-previous-element paragraph info))
	   (let ((followers (org-export-get-next-element paragraph info 2)))
	     (and (not (cdr followers))
		  (memq (org-element-type (car followers)) '(nil plain-list)))))
      ;; First paragraph in an item has no tag if it is alone or
      ;; followed, at most, by a sub-list.
      contents)
     ((org-html-standalone-image-p paragraph info)
      ;; Standalone image.
      (let ((caption
	     (let ((raw (org-export-data
			 (org-export-get-caption paragraph) info))
		   (org-html-standalone-image-predicate
		    #'org-html--has-caption-p))
	       (if (not (org-string-nw-p raw)) raw
		 (concat "<span class=\"figure-number\">"
			 (format (org-html--translate "Figure %d:" info)
				 (org-export-get-ordinal
				  (org-element-map paragraph 'link
				    #'identity info t)
				  info nil #'org-html-standalone-image-p))
			 " </span>"
			 raw))))
	    (label (org-html--reference paragraph info)))
	(org-html--wrap-image contents info caption label)))
     ;; if a quoted html snippet, don't wrap in p, might break structure
     ((org-html-is-quoted-snippet paragraph)
      contents)
     ;; Regular paragraph.
     (t
      (format "<p class=\"body\" %s%s>\n%s</p>"
	      (if (org-string-nw-p attributes)
		  (concat " " attributes) "")
	      extra contents)))))
;;;;; Code 
(defun org-html-src-block (src-block _contents info)
  "Transcode a SRC-BLOCK element from Org to HTML.
CONTENTS holds the contents of the item.  INFO is a plist holding
contextual information."
  (if (org-export-read-attribute :attr_html src-block :textarea)
      (org-html--textarea-block src-block)
    (let* ((lang (org-element-property :language src-block))
	   (code ;; (car (org-export-unravel-code src-block))
                 (org-html-format-code src-block info)
                  )
	   (label (let ((lbl (org-html--reference src-block info t)))
		    (if lbl (format " id=\"%s\"" lbl) ""))))
      (format "<div class=\"body org-src-container\">\n%s%s\n</div>"
	      ;; Build caption.
	      (let ((caption (org-export-get-caption src-block)))
		(if (not caption) ""
		  (let ((listing-number
			 (format
			  "<span class=\"listing-number\">%s </span>"
			  (format
			   (org-html--translate "Listing %d:" info)
			   (org-export-get-ordinal
			    src-block info nil #'org-html--has-caption-p)))))
		    (format "<label class=\"org-src-name\">%s%s</label>"
			    listing-number
			    (org-trim (org-export-data caption info))))))
	      ;; Contents.
	      (format "<pre class=\"src src-%s lang-%s\"%s><code>%s</code></pre>"
                      ;; Lang being nil is OK.
                      lang lang label code)))))
;;;;; Section
(defun org-html-section (section contents info)
  "Transcode a SECTION element from Org to HTML.
CONTENTS holds the contents of the section.  INFO is a plist
holding contextual information."
  (let ((parent (org-export-get-parent-headline section)))
    ;; Before first headline: no container, just return CONTENTS.
    (if (not parent) contents
      ;; Get div's class and id references.
      (let* ((class-num (+ (org-export-get-relative-level parent info)
			   (1- (plist-get info :html-toplevel-hlevel))))
	     (section-number
	      (and (org-export-numbered-headline-p parent info)
		   (mapconcat
		    #'number-to-string
		    (org-export-get-headline-number parent info) "-")))
             (manual-row (org-element-property :MANUAL-ROW parent))
             (row-reverse (org-element-property :ROW-REVERSE parent)))
        ;; Build return value.
	(format "<div class=\"grid-row %s outline-text-%d\" id=\"text-%s\">\n%s%s%s</div>\n"
                (if row-reverse "grid-row-reverse" "")
		class-num
		(or (org-element-property :CUSTOM_ID parent)
		    section-number
		    (org-export-get-reference parent info))
                (if manual-row "" "<div class=\"grid-column-full\">\n")
		(or contents "")
                (if manual-row "" "</div>\n"))))))
;;;;; Headline

(defun org-html-headline (headline contents info)
  "Transcode a HEADLINE element from Org to HTML.
CONTENTS holds the contents of the headline.  INFO is a plist
holding contextual information."
  (unless (org-element-property :footnote-section-p headline)
    (let* ((numberedp (org-export-numbered-headline-p headline info))
           (numbers (org-export-get-headline-number headline info))
           (level (+ (org-export-get-relative-level headline info)
                     (1- (plist-get info :html-toplevel-hlevel))))
           (todo (and (plist-get info :with-todo-keywords)
                      (let ((todo (org-element-property :todo-keyword headline)))
                        (and todo (org-export-data todo info)))))
           (todo-type (and todo (org-element-property :todo-type headline)))
           (priority (and (plist-get info :with-priority)
                          (org-element-property :priority headline)))
           (text (org-export-data (org-element-property :title headline) info))
           (tags (and (plist-get info :with-tags)
                      (org-export-get-tags headline info)))
           (full-text (funcall (plist-get info :html-format-headline-function)
                               todo todo-type priority text tags  info))
           (contents (or contents ""))
	   (id (org-html--reference headline info))
	   (formatted-text
	    (if (plist-get info :html-self-link-headlines)
		(format "<a href=\"#%s\">%s</a>" id full-text)
	      full-text)))

      (if (org-export-low-level-p headline info)
          ;; This is a deep sub-tree: export it as a list item.
          (let* ((html-type (if numberedp "ol" "ul")))
	    (concat
	     (and (org-export-first-sibling-p headline info)
		  (apply #'format "<%s class=\"org-%s\">\n"
			 (make-list 2 html-type)))
	     (org-html-format-list-item
	      contents (if numberedp 'ordered 'unordered)
	      nil info nil
	      (concat (org-html--anchor id nil nil info) formatted-text)) "\n"
	     (and (org-export-last-sibling-p headline info)
		  (format "</%s>\n" html-type))))
	;; Standard headline.  Export it as a section.
        (let ((extra-class
	       (org-element-property :HTML_CONTAINER_CLASS headline))
	      (headline-class
	       (org-element-property :HTML_HEADLINE_CLASS headline))
              (headline-subtitle
	       (org-element-property :SUBTITLE headline))
              (first-content (car (org-element-contents headline))))
          (format "<%s id=\"%s\" class=\"%s\">%s%s%s</%s>\n"
                  (org-html--container headline info)
                  (format "outline-container-%s" id)
                  (concat (format "outline-%d" level)
                          (and extra-class " ")
                          extra-class)
                  (if headline-subtitle
                      (format "<span class=\"%s\">%s</span>\n"
                              (org-html-level-to-caption-class (+ level 1))
                              headline-subtitle)
                    "")
                  (format "\n<h%d id=\"%s\"%s>%s</h%d>\n"
                          level
                          id
                          (format " class=\"%s %s\""
                                  (if (not headline-class) "" headline-class)
                                  (org-html-level-to-heading-class level))
			  
                          (concat
                           (and numberedp
                                (format
                                 "<span class=\"section-number-%d\">%s</span> "
                                 level
                                 (concat (mapconcat #'number-to-string numbers ".") ".")))
                           formatted-text)
                          level)
                  ;; When there is no section, pretend there is an
                  ;; empty one to get the correct <div
                  ;; class="outline-...> which is needed by
                  ;; `org-info.js'.
                  (if (org-element-type-p first-content 'section) contents
                    (concat (org-html-section first-content "" info) contents))
                  (org-html--container headline info)))))))

;;;;; HTML template 
(defun org-html-template (contents info)
  "Return complete document string after HTML conversion.
CONTENTS is the transcoded contents string.  INFO is a plist
holding export options."
  (concat
   (when (and (not (org-html-html5-p info)) (org-html-xhtml-p info))
     (let* ((xml-declaration (plist-get info :html-xml-declaration))
	    (decl (or (and (stringp xml-declaration) xml-declaration)
		      (cdr (assoc (plist-get info :html-extension)
				  xml-declaration))
		      (cdr (assoc "html" xml-declaration))
		      "")))
       (when (not (or (not decl) (string= "" decl)))
	 (format "%s\n"
		 (format decl
			 (or (and org-html-coding-system
				  (coding-system-get org-html-coding-system :mime-charset))
			     "iso-8859-1"))))))
   (org-html-doctype info)
   "\n"
   (concat "<html"
	   (cond ((org-html-xhtml-p info)
		  (format
		   " xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"%s\" xml:lang=\"%s\""
		   (plist-get info :language) (plist-get info :language)))
		 ((org-html-html5-p info)
		  (format " lang=\"%s\"" (plist-get info :language))))
	   ">\n")
   "<head>\n"
   (org-html--build-meta-info info)
   (org-html--build-head info)
   (org-html--build-mathjax-config info)
   "<link rel=\"stylesheet\" href=\"https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/default.min.css\">"
   "<link rel=\"icon\" type=\"image/x-icon\" href=\"/icon.ico\"/>"
   "</head>\n"
   "<body class=\"body\">\n"
   ;; Preamble.
   (org-html--build-pre/postamble 'preamble info)
   (org-html--build-navigation-bar info)
   "<div class=\"width-container\">\n"
   (org-html--build-breadcrumbs info)
   ;; Document contents.
   (let ((div (assq 'content (plist-get info :html-divs))))
     (format "<%s id=\"%s\" class=\"%s\">\n"
             (nth 1 div)
             (nth 2 div)
             (plist-get info :html-content-class)))
   ;; Document title.
   (when (plist-get info :with-title)
     (let ((title (and (plist-get info :with-title)
		       (plist-get info :title)))
	   (subtitle (plist-get info :subtitle))
	   (html5-fancy (org-html--html5-fancy-p info)))
       (when title
	 (format
          "%s<h1 class=\"heading-l\">%s</h1>\n</header>"
	  
	  (if subtitle
	      (format
               "<p class=\"caption-m\" role=\"doc-subtitle\">%s</p>\n"
	       (org-export-data subtitle info))
	    "")
          (org-export-data title info)))))
   (when (plist-get info :warning)
     (org-html--build-warning (plist-get info :warning)))
   contents
   (format "</%s>\n" (nth 1 (assq 'content (plist-get info :html-divs))))
   "</div>\n"
   ;; Postamble.
   (org-html--build-pre/postamble 'postamble info)
   ;; Possibly use the Klipse library live code blocks.
   (when (plist-get info :html-klipsify-src)
     (concat "<script>" (plist-get info :html-klipse-selection-script)
	     "</script><script src=\""
	     org-html-klipse-js
	     "\"></script><link rel=\"stylesheet\" type=\"text/css\" href=\""
	     org-html-klipse-css "\"/>"))
   ;; "<script src=\"https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js\"></script>"
   ;; "<script src=\"https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/ocaml.min.js\"></script>"
   ;; "<script>hljs.highlightAll();</script>"
   ;; Closing document.
   "</body>\n</html>"))


;;;; Project Alist 
(setq org-publish-project-alist
      `(("pages"
         :base-directory ,(html-dir)
         :base-extension "org"
         :recursive t
         :html-klipsify-src nil
         :publishing-directory ,build-dir
         :publishing-function org-html-publish-to-html
         :auto-sitemap t
         :sitemap-title "Kiran's Blog Posts"
         :sitemap-sort-files anti-chronologically
         :sitemap-filename "posts.org"
         :sitemap-function org-publish-sitemap-custom
         :sitemap-style list
         :sitemap-format-entry org-publish-sitemap-custom-entry
         :html-format-headline-function org-html-format-headline-custom-function
         :html-inline-images t
         :html-doctype "html5"
         :html-html5-fancy t
         :html-head-include-scripts nil
         :html-head-include-default-style nil
         :html-postamble t
         :html-content-class "body"
         :html-link-home ""
         :html-link-up ""
         :time-stamp-file nil
         :html-table-attributes (:border "2" :cellspacing "0" :cellpadding "6" :rules "groups" :frame "hsides" :class "table")
         :with-title nil
         :html-divs ((preamble "div" "preamble")
                     (content "main" "content")
                     (postamble "div" "postamble"))
         :html-head "<link rel=\"stylesheet\" type=\"text/css\" href=\"/style.css\"/>"
         :section-numbers nil
         :with-toc nil)

        ("static"
         :base-directory ,(html-dir)
         :base-extension "pdf\\|png\\|gif\\|jpg\\|svg\\|jpeg\\|js\\|cs\\|ttf\\|css\\|ico"
         :recursive t
         :publishing-directory ,build-dir
         :publishing-function org-publish-attachment)
        ("kirancodes.me" :components ("pages" "static"))))
