# cdextract
CD format implementation for damaged disk images in Elisp

Fully working partial implementation of ISO 9660 Joliet extension format disk images.

Implemented:
 -create directory tree(nonempty only)
 -filenames(unibyte forced) (no other file attributes yet)
 -extraction to files
 -full file system analysis (files+paths only) and actions with map.

Not implemented(could implement easily):
 -automatic root directory detection
 -bigendian addresses
 -place extracted files in new directory
 
To use:
0 requires hexl image in a current buffer to be loaded and set in disk-image
1 set root-addr and root-size to the root directory pointer (shortly after CD001 in Joliet section)
2 make the directory tree (example in el file)
3 extract to make files and folders (example in el file)

Careful:
 -do not run buffer writing functions unless with-current-buffer is used or it will overwite the buffer
 -it will overwrite files
