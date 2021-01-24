(setq blocksz #x800 disk-image "disk.img" root-addr #x88a2 root-size #x88aa)

(defun hexl-addr () (with-current-buffer disk-image (hexl-current-address)))

(defun concat-bytes (a b) (+ (lsh a 8) b))

(defun load-file (addr size)
  (insert-file-contents-literally disk-image nil addr (+ size addr) 1)
  (buffer-string))

(defun dumpbin (addr size file) (with-temp-file file (load-file addr size)))

(defun read-addr-string (addr size)
  (with-temp-buffer (string-make-unibyte (load-file addr size))))

(defun read-addr (addr size reader &optional mult)
  (* (or mult 1) (seq-reduce #'concat-bytes
                   (string-to-list (string-make-unibyte (apply reader `(,addr ,size)))) 0)))

(defun make-dir-entry (path)
  (defun read-entry-string (pos bytes)
    (let ((pos (if (>= pos 0) (1+ pos) 1))) ; (<= pos (buffer-size)) (bytes (if (> bytes (buffer-size)) 1 bytes)))
      (buffer-substring-no-properties pos (+ bytes pos))))

  (defun entry-next () (read-addr 0 1 'read-entry-string))

  (defun entry-addr () (read-addr 6 4 'read-entry-string blocksz))

  (defun entry-size () (read-addr 14 4 'read-entry-string))

  (defun entry-namesz () (read-addr 32 1 'read-entry-string))

  (defun entry-name ()
    (replace-regexp-in-string "\^@" ""
      (read-entry-string 33 (1+ (entry-namesz)))))

  (defun entry-dirp ()
    (/= 0 (logand #x80 (read-addr (+ (entry-next) -10) 1 'read-entry-string))))

  (if (< (buffer-size) #x30) nil
    (let ((entry `((addr ,(entry-addr)) (next ,(entry-next)) (size ,(entry-size))
                   (name ,(entry-name)) (dirp ,(entry-dirp)) (path ,path))))
      (delete-region 1 (1+ (get-entry entry 'next))) entry)))

(defun make-entry-temp (addr size name path)
  `((addr ,addr) (next #x30) (size ,size)
    (name ,name) (dirp t) (path ,path)))

(defun dir-list-p (d)
  (and (get-entry d 'dirp) (get-entry (car d) 'dirp)))

(defun get-entry (entry item &optional strict)
  (cadr (assq item (if (and (listp (car entry)) (listp (caar entry)) (not strict))
                       (car entry) entry))))

(defun valid-entry-target (dir-entry)
  (let ((max-addr (with-current-buffer disk-image hexl-max-address))
        (addr (get-entry dir-entry 'addr)))
    (and dir-entry (> addr 0) (< addr max-addr)
         (< (get-entry dir-entry 'size) max-addr))))

(defun dir-zeros-end-p (dir-tree)
  (if (zerop (or (get-entry (car dir-tree) 'next) 0))
      (if (> (buffer-size) blocksz)
          (delete-region 1 (1+ (mod (buffer-size) blocksz))) t)))

(defun recurse-dir (dir-tree)
  "if target is dir, cons this entry to list of entries"
  (if (get-entry (car dir-tree) 'dirp)
      (cons (cons (car dir-tree) (load-dir (car dir-tree))) (cdr dir-tree))
    dir-tree))

(defun filter-dir (dir-tree)
  (if (or (< (seq-reduce '+ (get-entry (car dir-tree) 'name) 0) 32)
          (zerop (or (get-entry (car dir-tree) 'next) 0)))
      (cdr dir-tree) dir-tree))

(defun traverse-dir (dir-tree)
  (while (not (dir-zeros-end-p dir-tree))
    (setq dir-tree (cons (make-dir-entry (get-entry (car dir-tree) 'path))
                         (recurse-dir (filter-dir dir-tree))))) (cdr dir-tree))

(defun start-traverse-dir (addr path)
  (let ((entry (make-dir-entry path)))
    (if (or (null entry) (/= addr (get-entry entry 'addr))) '()
      (traverse-dir (dir-replace (list (make-dir-entry path)))))))

(defun load-dir (entry)
  (let ((addr (get-entry entry 'addr)) (path (get-entry entry 'path)))
    (with-temp-buffer
      (load-file addr (get-entry entry 'size))
      (start-traverse-dir addr (concat path (get-entry entry 'name) "/")))))

(defun start-root-dir (root-addr root-size &optional subdir)
  (cdar (recurse-dir (list (make-entry-temp
             (read-addr root-addr 4 'read-addr-string blocksz)
             (read-addr root-size 4 'read-addr-string) (or subdir ".") "")))))

(defun dir-map (f d)
  (mapcar (lambda (e) (if (dir-list-p e) (dir-map f (cdr e))
                        (if (get-entry e 'next) (funcall f e)))) d))

(defun dir-extract (e)
  (make-directory (get-entry e 'path) t)
  (dumpbin (get-entry e 'addr) (get-entry e 'size)
           (concat (get-entry e 'path) (get-entry e 'name))) t)

(not (setq dtree (start-root-dir root-addr root-size)))

(dir-map 'dir-extract dtree)

(-sum (-flatten (dir-map (lambda (e) (get-entry e 'size)) dtree)))

(-flatten (dir-map (lambda (e) (get-entry e 'name)) dtree))
