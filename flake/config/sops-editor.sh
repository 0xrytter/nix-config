# The editor `sops edit` opens a decrypted secrets file in (SOPS_EDITOR). That
# file is plaintext, so nvim must leave no copy of it behind: no undo file
# (undofile is on globally, and its history held every sops edit until
# 2026-10-02), no swap file (-n), no shada with registers and history (-i NONE),
# no backup. Undo still works while the file is open; it just isn't saved.
exec nvim -n -i NONE -c 'set noundofile nobackup nowritebackup' "$@"
