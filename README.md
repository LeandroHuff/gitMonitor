# gitMonitor - Git Repository Monitor

The gitRepositoryMonitor is a shell script program that monitor git changes to automate updates by interval times.

The purpose for this  is to automate the update procedures to let the local repositories up to date with remote github repositories.

To do it, this bash script read a repoitories list file, check one-by-one to find out of repository changes, if someone repository in file list is out of date and need to be syncronized to remote github, the script run all git commands to add all untracked, deleted or changed local files, commit with a formatted message (formatted message + date and time) and push all to online git repository respectively and automated.
