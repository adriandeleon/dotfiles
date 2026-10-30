;;; init.el --- Emacs configuration (dotfiles)  -*- lexical-binding: t; -*-

;; Lives in ~/.dotfiles/emacs; install.sh links ~/.config/emacs here.
;;
;; Written for Emacs 31.1 (it uses options that don't exist in 30).  Works in
;; GUI frames, terminal frames and under the daemon (emacsclient), with the
;; standard Emacs keybindings.  Built-in features are used wherever they're
;; good enough; a small set of packages fills the gaps (completion UI, Magit,
;; Astro).  Options that are new in Emacs 31 are marked "(31)".
;;
;; Everything Emacs generates at runtime also lands in this directory, and
;; emacs/.gitignore keeps it out of git.

;; early-init.el silenced tree-sitter warnings while packages were activated.
(setq warning-suppress-log-types (delete '(treesit) warning-suppress-log-types))

;;; Packages

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; When a package is on several archives, prefer the GNU-maintained ones.
(setopt package-archive-priorities '(("gnu" . 3) ("nongnu" . 2) ("melpa" . 1)))

;; Keep Customize's writes out of this file.
(setopt custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror 'nomessage)

;;; Environment

;; A daemon started by systemd or the desktop doesn't read ~/.bashrc, so it
;; misses the PATH entries that nvm and SDKMAN add there.  Add them here so
;; Eglot can find the language servers, and jdtls can find a JDK.  Directories
;; already on the PATH (Emacs started from a shell) are left alone.
(defun my/add-to-path (dir)
  "Prepend DIR to `exec-path' and $PATH, if it exists and isn't there yet."
  (setq dir (directory-file-name (expand-file-name dir)))
  (when (and (file-directory-p dir) (not (member dir exec-path)))
    (push dir exec-path)
    (setenv "PATH" (concat dir path-separator (getenv "PATH")))))

(defun my/newest-nvm-node-bin ()
  "Return the bin directory of the newest Node.js version nvm installed."
  (car (sort (file-expand-wildcards "~/.nvm/versions/node/v*/bin")
             :key (lambda (dir)
                    (substring (file-name-nondirectory
                                (directory-file-name (file-name-parent-directory dir)))
                               1))
             :lessp #'version<
             :reverse t)))

(dolist (dir (append (file-expand-wildcards "~/.sdkman/candidates/*/current/bin")
                     (list (my/newest-nvm-node-bin) "~/.local/bin")))
  (when dir (my/add-to-path dir)))

(let ((java-home (expand-file-name "~/.sdkman/candidates/java/current")))
  (when (and (not (getenv "JAVA_HOME")) (file-directory-p java-home))
    (setenv "JAVA_HOME" java-home)))

;;; Appearance

(load-theme 'modus-vivendi t)

(defvar my/font-family "JetBrainsMono Nerd Font"
  "Font for GUI frames; installed by install.sh.")

(defun my/set-font (&optional _frame)
  "Use `my/font-family' if this is a GUI frame and the font is installed."
  (when (and (display-graphic-p) (find-font (font-spec :family my/font-family)))
    (set-face-attribute 'default nil :family my/font-family :height 120)))

;; The daemon starts without any GUI frame, so also set the font each time
;; emacsclient creates one.
(my/set-font)
(add-hook 'server-after-make-frame-hook #'my/set-font)

(setopt mode-line-collapse-minor-modes t    ; (31) one button for all minor modes
        column-number-mode t
        use-short-answers t
        ring-bell-function #'ignore)

(add-hook 'prog-mode-hook #'display-line-numbers-mode)

(when (fboundp 'pixel-scroll-precision-mode)
  (pixel-scroll-precision-mode))

;;; Editing

(setopt indent-tabs-mode nil
        require-final-newline t
        kill-region-dwim 'emacs-word          ; (31) C-w with no region kills a word
        delete-pair-push-mark t               ; (31) region left marked after delete-pair
        show-paren-not-in-comments-or-strings 'on-mismatch) ; (31)

(delete-selection-mode)
(repeat-mode)
(which-key-mode)
(add-hook 'prog-mode-hook #'electric-pair-local-mode)

;; Backup files go in one directory instead of next to every file.
(setopt backup-directory-alist `(("." . ,(locate-user-emacs-file "backups/"))))

;; Reload files that change on disk under git (branch switches, rebases...).
(vc-auto-revert-mode)                       ; (31)

(keymap-global-set "C-x C-b" #'ibuffer)

;;; History

(use-package savehist
  :config (savehist-mode))

(use-package recentf
  :demand t
  :config
  (setopt recentf-max-saved-items 200
          recentf-autosave-interval 300)    ; (31) save the list every 5 minutes
  (recentf-mode))

(use-package saveplace
  :demand t
  :config
  (setopt save-place-autosave-interval 300) ; (31)
  (save-place-mode))

;;; Minibuffer completion

;; Vertical candidate list in the minibuffer.
(use-package vertico
  :ensure t
  :init (vertico-mode))

;; Match space-separated terms in any order.
(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  ;; File names keep partial completion (/u/l/b -> /usr/local/bin); with the
  ;; leading wildcard (31) it also matches in the middle of a name.
  (completion-category-overrides '((file (styles partial-completion))))
  (completion-pcm-leading-wildcard t))

;; Annotations next to candidates (docstrings, file sizes, key bindings...).
(use-package marginalia
  :ensure t
  :init (marginalia-mode))

;; Search and navigation commands built on completing-read.
(use-package consult
  :ensure t
  :bind (("C-x b"   . consult-buffer)
         ("C-x 4 b" . consult-buffer-other-window)
         ("C-x p b" . consult-project-buffer)
         ("M-y"     . consult-yank-pop)
         ("M-g g"   . consult-goto-line)
         ("M-g M-g" . consult-goto-line)
         ("M-g i"   . consult-imenu)
         ("M-g f"   . consult-flymake)
         ("M-s l"   . consult-line)
         ("M-s r"   . consult-ripgrep))
  :custom
  (xref-show-xrefs-function #'consult-xref)
  (xref-show-definitions-function #'consult-xref))

;;; In-buffer completion

;; Completion popup at point.  In terminal frames it uses the TTY child
;; frames that are new in Emacs 31.
(use-package corfu
  :ensure t
  :init (global-corfu-mode)
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.2)
  (corfu-cycle t))

;; TAB indents, or completes if the line is already indented.
(setopt tab-always-indent 'complete)

;;; Tree-sitter

(require 'treesit)
(setopt treesit-enabled-modes t                ; (31) use every *-ts-mode available
        treesit-auto-install-grammar 'ask)     ; (31) offer to build missing grammars

;; Emacs 31 ships markdown-ts-mode, but neither autoloads it nor turns it on
;; for .md files; :mode does both.
(use-package markdown-ts-mode
  :mode "\\.md\\'")

;; astro-ts-mode refuses to start when a grammar is missing instead of
;; offering to install it like the built-in modes do, so .astro files go
;; through this command, which offers first.
(defun my/astro-ts-mode ()
  "Install the grammars `astro-ts-mode' needs if missing, then start it.
Missing grammars are handled per `treesit-auto-install-grammar'."
  (interactive)
  ;; Loading the package registers the astro grammar's source, and also warns
  ;; when the grammar is missing; it's about to be offered, so don't.
  (let ((warning-suppress-log-types (cons '(treesit) warning-suppress-log-types)))
    (require 'astro-ts-mode))
  (dolist (lang '(astro css typescript))
    (treesit-ensure-installed lang))            ; (31)
  (astro-ts-mode))

(use-package astro-ts-mode
  :ensure t
  :defer t
  :init (add-to-list 'auto-mode-alist '("\\.astro\\'" . my/astro-ts-mode)))

;;; Programming

;; Code folding, with clickable indicators in the fringe (31).
(use-package hideshow
  :hook (prog-mode . hs-minor-mode)
  :custom
  (hs-show-indicators t)                       ; (31)
  (hs-display-lines-hidden t))                 ; (31)

(use-package flymake
  :custom (flymake-show-diagnostics-at-end-of-line 'short))

(use-package elisp-mode
  :custom (elisp-fontify-semantically t))      ; (31)

(defun my/astro-ls-contact (&rest _)
  "Command line for astro-ls, which needs the path to TypeScript's lib/.
Uses the project's own TypeScript if it has one, else the global install."
  (let* ((project (project-current))
         (local (and project
                     (expand-file-name "node_modules/typescript/lib"
                                       (project-root project))))
         (bin (executable-find "astro-ls"))
         (global (and bin
                      (expand-file-name "../lib/node_modules/typescript/lib"
                                        (file-name-directory bin)))))
    `("astro-ls" "--stdio"
      :initializationOptions
      (:typescript (:tsdk ,(if (and local (file-directory-p local)) local global))))))

;; Start a language server automatically in these modes.  Java needs jdtls
;; on the PATH; the others use the npm-installed servers.
(use-package eglot
  :hook ((java-ts-mode typescript-ts-mode tsx-ts-mode js-ts-mode astro-ts-mode
          json-ts-mode yaml-ts-mode bash-ts-mode python-ts-mode dockerfile-ts-mode)
         . eglot-ensure)
  :custom
  (eglot-autoshutdown t)                       ; stop servers with their last buffer
  (eglot-events-buffer-config '(:size 0))      ; no protocol log (faster)
  :config
  (add-to-list 'eglot-server-programs '(astro-ts-mode . my/astro-ls-contact)))

;;; Git

(use-package magit
  :ensure t
  :bind ("C-x g" . magit-status))

;;; Files

(use-package dired
  :custom
  (dired-listing-switches "-alh")
  (dired-dwim-target t)                        ; copy/move to the other Dired window
  (dired-kill-when-opening-new-dired-buffer t))

;;; init.el ends here
