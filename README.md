# cluster-utils
Collection of utilities / helper scripts to make life easier on our HPC clusters.

## 1. List of tools.

#### cfinger

cfinger is finger on steroids: basic account details which you would also get from standard finger supplemented with public keys associated to accounts and group memberships.
Example output:

```
===========================================================
Basic account details for [account]:
-----------------------------------------------------------
User            : [account]
UID             : [0-9]+
Home            : /home/[account]
Shell           : /bin/bash
Mail            : Real Name <r.name@fully.qualified.domain>
-----------------------------------------------------------
User [account] is authorized for access to groups:
-----------------------------------------------------------
Primary group   : [account]  ([0-9]+)
Secondary group : [group]    ([0-9]+)
-----------------------------------------------------------
Public key(s) for authenticating user [account]:
-----------------------------------------------------------
ssh-rsa AAAAB3NzaC1yc....QR+zbmsAX0Mpw== [account]
===========================================================
```

#### colleagues

Lists all users of all groups a user is a member of. 
Optionally you can specify a group and list only members of that specific group.
User accounts are expanded to Real Names and email addresses. 
Example output:
```
===========================================================
Group [group] contains members:
-----------------------------------------------------------
[account]        Real Name <r.name@fully.qualified.domain>
===========================================================
```

#### ctop

Cluster-top or ctop for short provides an integrated real-time overview of resource availability and usage. 
The example output below is in black and white, but you'll get a colorful picture if your terminal supports ANSI colors.
Press the ? key to get online help, which will explain how to filter, sort and color results 
as well as how to search for specific users, jobs, nodes, quality of service (QoS) levels, etc.

```
Usage Totals: 288/504 Cores | 7/11 Nodes | 69/7124 Jobs Running                                                             2016-12-01-T12:22:56
Node States: 3 IDLE | 1 IDLE+DRAIN | 7 MIXED

   cluster         node 1 2 3 4 5 6 7 8 9 0   1 2 3 4 5 6 7 8 9 0   1 2 3 4 5 6 7 8 9 0   1 2 3 4 5 6 7 8 9 0   1 2 3 4 5 6 7 8   load
                        -------------------------------------------------------------------------------------------------------
  calculon     calculon . . . . . . . . . .   . . @ @ @ @ @ @ @ @   @ @ @ @                                                       2.08 = Ok
                        -------------------------------------------------------------------------------------------------------
  calculon umcg-node011 E i T d Z O U d O w   w w w S S S S e e e   e . . . . . . . . .   . . . . . . . . . .   . . . . . . @ @  10.96 = too low!
                        -------------------------------------------------------------------------------------------------------
  calculon umcg-node012 0 0 0 0 0 0 0 0 0 0   0 0 0 0 0 0 0 0 0 0   0 0 0 0 0 0 0 0 0 0   0 0 0 0 0 0 0 0 0 0   0 0 0 0 0 0 0 0   0.57 = Ok
                        -------------------------------------------------------------------------------------------------------
  calculon umcg-node013 < N N N N C C C C =   = = = x x x x b b b   b D D D D A A A A I   I I I T T T T Y Y Y   Y . . . . . @ @  17.31 = too low!
                        -------------------------------------------------------------------------------------------------------
  calculon umcg-node014 B B B B B B B B B B   B B B B B B B B B B   B B B B B L c k k k   k - - - - E E E E S   S S S . . . @ @  30.40 = too low!
                        -------------------------------------------------------------------------------------------------------
  calculon umcg-node015 u I I I I I I I I I   I I I I I I I I I I   I I I I I I e v D o   B B B B N N N N i i   i i K K K K @ @  34.71 = too low!
                        -------------------------------------------------------------------------------------------------------
  calculon umcg-node016 H Z Y Y Y Y Y Y Y Y   Y Y Y Y Y Y Y Y Y Y   Y Y Y Y Y Y Y U + _   > > > > a a a a n n   n n k k k k @ @  34.39 = too low!
                        -------------------------------------------------------------------------------------------------------
  calculon umcg-node017 L L L L L L L L L L   L L L L L L L L L L   L L L L L p p p p H   H H H b b b b | | |   | / / / / . @ @  22.02 = too low!
                        -------------------------------------------------------------------------------------------------------
  calculon umcg-node018 s z ~ V y c c c c c   c c c c c c c c c c   c c c c c c c c c c   V q l a C C C C K K   K K A A A A @ @  38.03 = too low!
                        -------------------------------------------------------------------------------------------------------
  calculon umcg-node019 . . . . . . . . . .   . . . . . . . . . .   . . . . . . . . . .   . . . . . . . . . .   . . . . . . @ @   0.51 = Ok
                        -------------------------------------------------------------------------------------------------------
  calculon umcg-node020 . . . . . . . . . .   . . . . . . . . . .   . . . . . . . . . .   . . . . . . . . . .   . . . . . . @ @   0.59 = Ok
                        -------------------------------------------------------------------------------------------------------
                        legend: ? unknown | @ busy | X down | . idle | 0 offline | ! other

      JobID  Username     QoS             Jobname                                  S  CPU(%) CPU(%) Mem(GiB) Mem(GiB)   Walltime   Walltime
                                                                                       ~used   req.     used     req.       used  requested
  u = 562757 [account]    regular-long    VCF_filter_convert_concat_tt.sh          R      15    100     34.3    120.0 0-14:09:10 3-00:00:00
  E = 579935 [account]    regular-long    SRA_download_fastq_round2.sh             R       0    100      2.1    120.0 3-02:19:50 5-00:00:00
  s = 580724 [account]    regular-long    RELF10_%j                                R      99    100      1.2     20.0 0-21:13:23 2-00:00:00
  z = 580725 [account]    regular-long    RELF11_%j                                R      99    100      1.2     20.0 0-21:13:23 2-00:00:00
  ~ = 580726 [account]    regular-long    RELF12_%j                                R      99    100      1.2     20.0 0-21:13:23 2-00:00:00
  V = 580727 [account]    regular-long    RELF13_%j                                R      99    100      1.2     20.0 0-21:13:23 2-00:00:00
  y = 580728 [account]    regular-long    RELF14_%j                                R      99    100      1.2     20.0 0-21:13:23 2-00:00:00
  H = 580729 [account]    regular-long    RELF15_%j                                R      99    100      1.2     20.0 0-21:13:23 2-00:00:00
  Z = 580730 [account]    regular-long    RELF16_%j                                R      99    100      1.2     20.0 0-21:13:23 2-00:00:00
  i = 580731 [account]    regular-long    RELF17_%j                                R      99    100      1.2     20.0 0-17:30:31 2-00:00:00
  T = 580732 [account]    regular-long    RELF18_%j                                R      99    100      1.2     20.0 0-17:30:31 2-00:00:00
  d = 581023 [account]    regular-long    move_check_downloaded_files.sh           R       1    100      0.0     40.0 0-21:13:23 3-00:00:00
  c = 606872 [account]    regular-short   kallisto33                               R    2311   2500     22.3     40.0 0-01:19:23 0-05:59:00
  I = 606873 [account]    regular-short   kallisto34                               R    2291   2500     22.3     40.0 0-01:17:23 0-05:59:00
  Y = 606874 [account]    regular-short   kallisto35                               R    1719   2500     23.7     40.0 0-00:24:32 0-05:59:00
  B = 606876 [account]    regular-short   kallisto37                               R    1685   2500     22.3     40.0 0-00:23:01 0-05:59:00
  L = 606877 [account]    regular-short   kallisto38                               R    1165   2500     22.3     40.0 0-00:13:33 0-05:59:00
```

#### quota

Custom quota reporting tool for users. Lists quota for all groups a user is a member of. Example output:
```
====================================================================================================================================================
                             |                     Total size of files and folders |                   Total number of files and folders |
(T) Path/Filesystem          |       used       quota       limit            grace |       used       quota       limit            grace |    Status
----------------------------------------------------------------------------------------------------------------------------------------------------
(P) /home/[account]          |    748.5 M       1.0 G       2.0 G             none |     27.0 k       0.0         0.0               none |        Ok
----------------------------------------------------------------------------------------------------------------------------------------------------
(G) /apps                    |    738.3 G       1.0 T       2.0 T             none |  1,137.0 k       0.0         0.0               none |        Ok
(G) /.envsync/tmp04          |    691.8 G       5.0 T       8.0 T             none |    584.0 k       0.0         0.0               none |        Ok
----------------------------------------------------------------------------------------------------------------------------------------------------
(G) /groups/[group]/prm02    |     11.8 T      12.0 T      15.0 T             none |     26.0 k       0.0         0.0               none |        Ok
(G) /groups/[group]/tmp04    |     52.4 T      50.0 T      55.0 T      5d12h17m16s |  4,101.0 k       0.0         0.0               none | EXCEEDED!
(F) /groups/[group]/tmp02    |     25.0 T      40.0 T      40.0 T             none |    169.0 k       0.0         0.0               none |        Ok
====================================================================================================================================================
```
#### hpc-environment-quota-report-for-PFS.bash

Custom quota reporting tool for admins. Lists quota for all groups on a Physical File System (PFS). Output is similar to that from the quota tool listed above.

#### hpc-environment-slurm-report.bash

Custom SLURM cluster reporting tool. Lists available resources and resource usage over a specified period of time. Example output:

```
======================================================================
Cluster usage report from 2016-09-01T00:00:00 to 2016-10-01T00:00:00.
----------------------------------------------------------------------
Available resources for calculon cluster:
   Partition   CPUs (cores)   Memory (GB)
----------------------------------------------------------------------
   duo-pro              368          1840
   duo-dev               92           460
   duo-ds                12           128
   TOTAL                472          2428
----------------------------------------------------------------------
Cluster   Account        Login  CPU used  MEM used
----------------------------------------------------------------------
calculon    users    [account]    27.61%    25.90%
calculon    users    [account]    17.31%    11.27%
calculon    users    [account]     6.44%     3.54%
calculon    users    [account]     5.71%     5.60%
calculon    users    [account]     3.53%     1.06%
TOTAL         ANY          ALL    60.60%    47.40%
======================================================================
```

## 2. How to use this repo and contribute.

We use a standard GitHub workflow except that we use only one branch "*master*" as this is a relatively small repo and we don't need the additional overhead from branches.
```
   ⎛¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯⎞                                               ⎛¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯⎞
   ⎜ Shared repo a.k.a. "blessed"         ⎜ <<< 7: Merge <<< pull request <<< 6: Send <<< ⎜ Your personal online fork a.k.a. "origin"          ⎜
   ⎜ github.com/molgenis/cluster-utils.git⎜ >>> 1: Fork blessed repo >>>>>>>>>>>>>>>>>>>> ⎜ github.com/<your_github_account>/cluster-utils.git ⎜
   ⎝______________________________________⎠                                               ⎝____________________________________________________⎠
      v                                                                                                   v      ʌ
      v                                                                       2: Clone origin to local disk      5: Push commits to origin
      v                                                                                                   v      ʌ
      v                                                                                  ⎛¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯⎞
      `>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 3: pull from blessed >>> ⎜ Your personal local clone                          ⎜
                                                                                         ⎜ ~/git/cluster-utils                                ⎜
                                                                                         ⎝____________________________________________________⎠
                                                                                              v                                        ʌ
                                                                                              `>>> 4: Commit changes to local clone >>>´
```

 1. Fork this repo on GitHub (Once).
 2. Clone to your local computer and setup remotes (Once).
   ```
   #
   # Clone repo
   #
   git clone https://github.com/your_github_account/cluster-utils.git
   #
   # Add blessed remote (the source of the source) and prevent direct push.
   #
   cd cluster-utils
   git remote add            blessed https://github.com/molgenis/cluster-utils.git
   git remote set-url --push blessed push.disabled
   ```
   
 3. Pull from "*blessed*" (Regularly from 3 onwards).
   ```
   #
   # Pull from blessed master.
   #
   cd cluster-utils
   git pull blessed master
   ```
   Make changes: edit, add, delete...

 4. Commit changes to local clone.
   ```
   #
   # Commit changes.
   #
   git status
   git add some/changed/files
   git commit -m 'Describe your changes in a commit message.'
   ```
   
 5. Push commits to "*origin*".
   ```
   #
   # Push commits.
   #
   git push origin master
   ```

 6. Go to your fork on GitHub and create a pull request.
 
 7. Have one of the other team members review and eventually merge your pull request.
 
 3. Back to 3 to pull from "*blessed*" to get your local clone in sync.
   ```
   #
   # Pull from blessed master.
   #
   cd cluster-utils
   git pull blessed master
   ```
   etc.

