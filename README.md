# gitMonitor - Git Repository Monitor

The gitRepositoryMonitor is a shell script program that run in a terminal and monitor git changes to automate updates by  
interval times.  
The purpose for this bash script is to automate the update procedures to let the local repositories up to date with remote  
github repositories.  

To do it, this bash script read a repoitories list vector, check one-by-one to find out of local/remote repository  
changes,  
if someone repository in list is out of date or need to be syncronized to/from remote github, the script run all git  
commands to add all new, untracked, deleted, changed and modified local files, commit with a formatted message  
(formatted message + date and time) and push all information to online git repository.  

With some modifications, this bash script can run as a service and stay running in background.
