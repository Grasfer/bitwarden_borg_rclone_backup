#!/bin/sh

# Setting borg password.
export BORG_PASSPHRASE='insert-borg-repo-password-here'

### Turning off bitwarden.
~/bitwarden/bitwarden.sh stop



# some helpers and error handling:
info() { printf "\n%s %s\n\n" "$( date )" "$*" >&2; }
trap 'echo $( date ) Backup interrupted >&2; exit 2' INT TERM


# Executing backup operation.
info "Starting backup"
borg create --verbose --stats --exclude '~/bitwarden/bwdata/logs' --compression zstd,22 ~/bwbackup::{now:%F_%T} ~/bitwarden/bwdata
backup_exit=$?


info "Pruning repository"
borg prune --verbose --stats --keep-daily 7 --keep-weekly 4 --keep-monthly 6 ~/bwbackup
prune_exit=$?


info "Compacting repository"
borg compact --verbose ~/bwbackup
compact_exit=$?


#rclone syncing with backblaze.
info "rclone sync to backblaze"
rclone sync bwbackup backblaze:<backblaze bucket>
rclone_exit=$?

# use highest exit code as global exit code
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))
global_exit=$(( compact_exit > global_exit ? compact_exit : global_exit ))

if [ ${global_exit} -eq 0 ]; then
    info "Backup, Prune, and Compact finished successfully"
elif [ ${global_exit} -eq 1 ]; then
    info "Backup, Prune, and/or Compact finished with warnings"
else
    info "Backup, Prune, and/or Compact finished with errors"
fi


### Startubg bitwarden.
~/bitwarden/bitwarden.sh start

info "Backup completed."
exit ${global_exit}
