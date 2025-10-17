# gitRepositoryMonitor - Git Repository Monitor

The gitRepositoryMonitor is a shell script program that can run as a daemon service on Linux or a terminal application tô monitor git changes and automate updates by interval times.

The purpose for this  is to automate the update procedures to let the local repositories up to date with online github repositories.

To do it, this service read a file with a list of personal github repositories names, check each one to find out of date repository, if someone in file list is out of date and need to be syncronized to online github account, the script run all commands to add all untracked, deleted or changed local files, commit with a formatted message (formatted message + date and time) and push all to online git repository respectively and automated.

[daemons](https://github.com/LeandroHuff/daemons)
