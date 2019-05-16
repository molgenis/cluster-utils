# cluster-utils
Collection of utilities / helper scripts to make life easier on our HPC clusters.

## 1. List of tools.

### AAI tools.
Tools to get reports on authentication & authorization settings and identities.
- [caccounts](#-caccounts): Lists details of Slurm cluster accounts.
- [cfinger](#-cfinger): Lists details of a specific user's system/login account.
- [colleagues](#-colleagues): Lists group owners, data managers and other regular group members.

### Tools for monitoring cluster/job status
- [ctop](#-ctop): Top-like overview of cluster status and resource usage.
- [sjeff](#-sjeff): Lists Slurm Job EFFiciency for jobs.
- [cnodes](#-cnodes): Lists state of compute nodes.
- [cqos](#-cqos): Lists details for all Quality of Service levels.
- [cqueue](#-cqueue): Lists running and queued jobs.
- [hpc-environment-slurm-report](#-hpc-environment-slurm-report): Creates reports on cluster usage as percentage of available resources for specified period (e.g. week, month, etc.).

### Tools for monitoring file system and quota status

- [quota](#-quota): Lists quota for all shared file systems.
- [hpc-environment-quota-report-for-PFS](#-hpc-environment-quota-report-for-pfs): Creates quota report for admins.

#### <a name="caccounts"/> caccounts

Wrapper for Slurm's sacctmgr command with custom output format to list which users are associated to which slurm accounts on which clusters.
Example output:
```
   Cluster              Account                           User     Share          Def QOS                                   QOS
---------- -------------------- ------------------------------ --------- ---------------- -------------------------------------
  calculon root                                                        1 priority         [list of QoS account had access to]
  calculon  root                root                                   1 priority         [list of QoS account had access to]
  calculon  users                                                      1 regular          [list of QoS account had access to]
  calculon   users              [1st_user]                             1 regular          [list of QoS account had access to]
  calculon   users              [2nd_user]                             1 regular          [list of QoS account had access to]
etc.
```

#### <a name="cfinger"/> cfinger

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

#### <a name="colleagues"/> colleagues

Lists all users of all groups a user is a member of. 
Optionally you can specify:
 * ```-g [group_name]``` to list only members of the specified group.
 * ```-g all``` to list members of all groups.
 * ```-e``` to sort group members by expiration date of their account.
User accounts are expanded to Real Names and email addresses.

Example output:
```
==============================================================================================================
Colleagues in the [group] group:                                                                       
==============================================================================================================
[group] owner(s):                                                                             
--------------------------------------------------------------------------------------------------------------
[account]       YYYY-MM-DD        Real Name <r.name@fully.qualified.domain>
==============================================================================================================
[group] datamanager(s):                                                                       
--------------------------------------------------------------------------------------------------------------
[account]       YYYY-MM-DD        Real Name <r.name@fully.qualified.domain>
==============================================================================================================
[group] member(s):                                                                            
--------------------------------------------------------------------------------------------------------------
[account]       YYYY-MM-DD        Real Name <r.name@fully.qualified.domain>
==============================================================================================================
```

#### <a name="ctop"/> ctop

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

#### <a name="sjeff"/> sjeff

Slurm Job EFFiciency or sjeff for short provides an overview of finished jobs, the resources they requested and how efficient these were used.
The job efficiency is a percentage and defined as: ``` used resources / requested resources * 100```.
Note that for CPU core usage the average is reported whereas for Memory usage the max peak usage is reported.
The example output below is in black and white, but you'll get a colorful picture if your terminal supports ANSI colors:

 * green: Ok.
 * yellow: you requested too much and wasted resources.
 * red: you requested too little and your jobs ran inefficiently or got killed or were close to getting killed.

```
===============================================================================================================================
JobName                                                      | Time                 | Cores (used=average) | Memory (used=peak)
                                                             |   Requested  Used(%) |   Requested  Used(%) | Requested  Used(%)
-------------------------------------------------------------------------------------------------------------------------------
validateConvading_s01_PrepareFastQ_0                         |    07:00:00     0.05 |           4     0.00 |       8Gn     0.01
validateConvading_s01_PrepareFastQ_1                         |    07:00:00     0.06 |           4     0.00 |       8Gn     0.01
validateConvading_s03_FastQC_0                               |    05:59:00     0.39 |           1    60.00 |       2Gn    11.81
validateConvading_s03_FastQC_1                               |    05:59:00     0.40 |           1    66.28 |       2Gn    11.31
validateConvading_s04_BwaAlignAndSortSam_0                   |    23:59:00     0.31 |           8    39.18 |      30Gn    29.96
validateConvading_s04_BwaAlignAndSortSam_1                   |    23:59:00     0.35 |           8    45.72 |      30Gn    30.17
validateConvading_s05_MergeBam_0                             |    05:59:00     0.03 |          10     0.00 |      10Gn     0.00
validateConvading_s05_MergeBam_1                             |    05:59:00     0.05 |          10     0.00 |      10Gn     0.00
validateConvading_s06_BaseRecalibrator_0                     |    23:59:00     0.65 |           8   179.61 |      10Gn    49.54
validateConvading_s06_BaseRecalibrator_1                     |    23:59:00     0.62 |           8   222.78 |      10Gn    53.23
validateConvading_s07_MarkDuplicates_0                       |    16:00:00     0.13 |           5   193.42 |      30Gn     2.81
validateConvading_s07_MarkDuplicates_1                       |    16:00:00     0.15 |           5   167.04 |      30Gn     2.72
validateConvading_s08_Flagstat_0                             |    03:00:00     0.07 |           5     0.00 |      30Gn     0.00
validateConvading_s08_Flagstat_1                             |    03:00:00     0.06 |           5     0.00 |      30Gn     0.00
validateConvading_s09a_Manta_0                               |    16:00:00     0.01 |          21     0.00 |      30Gn     0.00
validateConvading_s09a_Manta_1                               |    16:00:00     0.01 |          21     0.00 |      30Gn     0.00
validateConvading_s09b_Convading_0                           |    05:59:00     1.29 |           1     1.79 |       4Gn     0.67
validateConvading_s09b_Convading_1                           |    05:59:00     1.50 |           1     0.31 |       4Gn     0.70
===============================================================================================================================
```

#### <a name="cnodes"/> cnodes

Wrapper for Slurm's sinfo command with custom output format to list all compute nodes and their state.
Example output:
```
PARTITION    AVAIL  NODES  STATE  S:C:T   CPUS  MAX_CPUS_PER_NODE  MEMORY  TMP_DISK  FEATURES                      GROUPS  TIMELIMIT   JOB_SIZE  ALLOCNODES  NODELIST            REASON
duo-pro*     up     8      mixed  8:6:1   48    46                 258299  1063742   umcg,ll,tmp02,tmp04           all     7-00:01:00  1         all         umcg-node[011-018]  none
duo-dev      up     1      mixed  8:6:1   48    46                 258299  1063742   umcg,ll,tmp02,tmp04           all     7-00:01:00  1         all         umcg-node019        none
duo-dev      up     1      idle   8:6:1   48    46                 258299  1063742   umcg,ll,tmp02,tmp04           all     7-00:01:00  1         all         umcg-node020        none
duo-ds-umcg  up     1      idle   2:12:1  24    12                 387557  1063742   umcg,tmp02,tmp04,prm02,prm03  all     7-00:01:00  1         all         calculon            none
duo-ds-ll    up     1      idle   2:1:1   2     2                  7872    0         ll,tmp04,prm02,prm03          all     7-00:01:00  1         all         lifelines           none
```

#### <a name="cqos"/> cqos

Wrapper for Slurm's sacctmgr command with custom output format to list all Quality of Service (QoS) levels and their limits.
Example output:
```
           Name   Priority UsageFactor                        GrpTRES GrpSubmit GrpJobs                      MaxTRESPU MaxSubmitPU MaxJobsPU       MaxTRES     MaxWall 
--------------- ---------- ----------- ------------------------------ --------- ------- ------------------------------ ----------- --------- ------------- ----------- 
         normal          0    1.000000                                                                                                                                 
        regular         10    1.000000                    cpu=0,mem=0     30000                                               5000                                     
       leftover          0    0.000000                    cpu=0,mem=0     30000                                              10000                                     
       priority         20    2.000000                    cpu=0,mem=0      5000                                               1000                                     
 leftover-short          0    0.000000                                    30000                                              10000                            06:00:00 
leftover-medium          0    0.000000                                    30000                                              10000                          1-00:00:00 
  leftover-long          0    0.000000                                     3000                                               1000                          7-00:00:00 
  regular-short         10    1.000000                                    30000                                               5000                            06:00:00 
 regular-medium         10    1.000000                                    30000                     cpu=192,mem=942080        5000                          1-00:00:00 
   regular-long         10    1.000000              cpu=96,mem=471040      3000                      cpu=48,mem=235520        1000                          7-00:00:00 
 priority-short         20    2.000000              cpu=96,mem=471040      5000                                               1000                            06:00:00 
priority-medium         20    2.000000              cpu=96,mem=471040      2500                      cpu=48,mem=235520         500                          1-00:00:00 
  priority-long         20    2.000000              cpu=96,mem=471040       250                      cpu=48,mem=235520          50                          7-00:00:00 
            dev         10    1.000000                    cpu=0,mem=0      5000                                               1000                                     
      dev-short         10    1.000000                                     5000                      cpu=48,mem=235520        1000                            06:00:00 
     dev-medium         10    1.000000              cpu=96,mem=471040      2500                      cpu=48,mem=235520         500                          1-00:00:00 
       dev-long         10    1.000000              cpu=48,mem=235520       250                      cpu=48,mem=235520          50                          7-00:00:00 
             ds         10    1.000000                    cpu=0,mem=0      5000                                               1000                                     
       ds-short         10    1.000000                                     5000                         cpu=4,mem=4096        1000                            06:00:00 
      ds-medium         10    1.000000                 cpu=4,mem=4096      2500                         cpu=2,mem=2048         500                          1-00:00:00 
        ds-long         10    1.000000                 cpu=4,mem=4096       250                         cpu=1,mem=1024          50                          7-00:00:00 
```

#### <a name="cqueue"/> cqueue

Wrapper for Slurm's squeue command with custom output format to list running and scheduled jobs.
Example output:
```
JOBID    PARTITION  QOS             NAME                             USER           ST  TIME   NODELIST(REASON)  START_TIME           PRIORITY
4864542  duo-pro    regular-medium  run_GS1_FinalReport_small_chr3   [user]         PD  0:00   (Priority)        2018-06-30T02:16:05  0.00011811894367
4864541  duo-pro    regular-medium  run_GS1_FinalReport_small_chr2   [user]         PD  0:00   (Priority)        2018-06-30T01:47:42  0.00011811894367
4864540  duo-pro    regular-medium  run_GS1_FinalReport_small_chr22  [user]         PD  0:00   (Priority)        2018-06-30T01:34:43  0.00011811894367
4864539  duo-pro    regular-medium  run_GS1_FinalReport_small_chr21  [user]         PD  0:00   (Resources)       2018-06-29T21:55:46  0.00011811894367
4864537  duo-pro    regular-medium  run_GS1_FinalReport_small_chr1   [user]         R   10:09  umcg-node015      2018-06-29T16:03:44  0.00011821347292
4864526  duo-pro    regular-medium  run_GS1_FinalReport_small_chr0   [user]         R   10:13  umcg-node013      2018-06-29T16:03:40  0.00011821347292
4864527  duo-pro    regular-medium  run_GS1_FinalReport_small_chr10  [user]         R   10:13  umcg-node011      2018-06-29T16:03:40  0.00011821347292
4864528  duo-pro    regular-medium  run_GS1_FinalReport_small_chr11  [user]         R   10:13  umcg-node017      2018-06-29T16:03:40  0.00011821347292
```

#### <a name="hpc-environment-slurm-report"/> hpc-environment-slurm-report

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

#### <a name="quota"/> quota

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
#### <a name="hpc-environment-quota-report-for-pfs"/> hpc-environment-quota-report-for-PFS

Custom quota reporting tool for admins. Lists quota for all groups on a Physical File System (PFS). Output is similar to that from the quota tool listed above.

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

