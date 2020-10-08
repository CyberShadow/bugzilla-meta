;;; Directory Local Variables
;;; For more information see (info "(emacs) Directory Variables")

((perl-mode . ((tab-width . 2)
	       (eval . (setq flycheck-perl-include-path
			     (list
			      (expand-file-name "src"
						(locate-dominating-file default-directory ".dir-locals.el"))
			      (expand-file-name "src/local/lib/perl5"
						(locate-dominating-file default-directory ".dir-locals.el")))))
	       (perl-indent-level . 2)))
 (web-mode . ((web-mode-markup-indent-offset . 2)
	      (indent-tabs-mode . nil)
	      (smart-tabs-mode . nil)
	      (bug-reference-url-format . "https://bugzilla.mozilla.org/show_bug.cgi?id=%s"))))
