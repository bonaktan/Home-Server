# Capacity evidence

Status: **incomplete**. These are observations, not approved budgets or peak-load evidence. Do not use them to justify reducing audit retention or moving central services.

On 2026-11-02 the Atom reported 3,839 MiB RAM, 1,683 MiB available and 600 MiB of 3,048 MiB swap used. `/` and `/srv` share a 53 GiB filesystem with 20 GiB used and 31 GiB available; 345,676 of 3,522,560 inodes were used. Docker reported 7.943 GB of images and 1.668 GB of local volumes. Docker's reclaimable estimate is not permission to remove data and its accounting does not cover every bind mount or backup dataset.

On 2026-11-02 the second host reported 7,841 MiB RAM, 5,928 MiB available and 7 MiB of 6,302 MiB swap used. Its root filesystem was 110 GiB with 69 GiB used and 36 GiB available; 537,342 of 7,356,416 inodes were used. Docker reported 14.09 GB of images, 2.558 GB of local volumes and 2.708 GB of build cache. These figures also exclude unaccounted bind mounts and are not deletion guidance.

Measure both hosts at steady state and combined maintenance/restore peaks, including independent workloads, I/O, telemetry and 30-day audit growth, database and Pterodactyl capture size/churn, image retention, temporary staging and restore headroom. Establish destination-specific advisory byte budgets and reserves from those measurements. The approved policy warns at 80%, exceeds at 100%, clears below 75%, and reports stale/unknown measurements; it does not impose an upload or spending limit. No such budgets, peak measurements or R2 usage have been established yet.
