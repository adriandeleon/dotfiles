;;; early-init.el --- Runs before the package system and the first frame  -*- lexical-binding: t; -*-

;; Only things that must happen before the first frame is drawn belong here;
;; everything else is in init.el.

;; Collect garbage rarely while loading the config, then go back to a
;; reasonable threshold so pauses stay short during editing.
(setq gc-cons-threshold most-positive-fixnum)
(add-hook 'emacs-startup-hook
          (lambda () (setq gc-cons-threshold (* 32 1024 1024))))

;; Turn the tool bar, menu bar and scroll bars off up front, so they never
;; flash on screen while the frame is being created.  F10 still opens the
;; menus.  Setting the frame parameters (not the modes) also covers every
;; frame emacsclient creates later.
(push '(menu-bar-lines . 0) default-frame-alist)
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(push '(horizontal-scroll-bars) default-frame-alist)

;; Don't resize the frame when the font or UI elements change during startup.
(setq frame-inhibit-implied-resize t)

(setq inhibit-startup-screen t)

;; Some packages' autoload files call tree-sitter functions (astro-ts-mode's
;; calls `treesit-ready-p'), and those files are loaded when packages are
;; activated, after this file but before init.el.  That check warns on every
;; start until the grammar is installed, so silence tree-sitter warnings until
;; init.el turns them back on: missing grammars are offered for install when a
;; file first needs them.  (warnings.el isn't loaded yet; its defcustom keeps
;; this value.)
(require 'treesit)
(setq warning-suppress-log-types '((treesit)))

;;; early-init.el ends here
