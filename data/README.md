# Raw data

## PacBio CCS reads (HG002)

- Location: `Group4_2026:/Data/CCS_15kb_30x/` — 39 SMRT-cell FASTQs (`*.Q20.fastq`), ~166.2 GB total, ~30x coverage.
- Subset actually used: 20 of 39 cells (every second cell after sorting movie names) = 86.4 GB, 52.0% of bases, ≈15x coverage. Exact list: [`config/subset_cells_15x.txt`](../config/subset_cells_15x.txt).
- Source: not recorded in DNAnexus metadata. The files were uploaded manually via a JupyterLab session (job `JupyterLab_data_upload_test`, run by `user-yunjialiusv`) rather than an automated download, so there's no stored source URL to restore. The movie-ID filenames (e.g. `m54238_180901_011437.Q20.fastq`) follow the naming convention of the public GIAB HG002 PacBio CCS 15kb dataset, but that's an inference from naming, not a confirmed source — worth checking with whoever ran the upload if exact provenance is needed.

## Reference genome assemblies

Seven UCSC builds spanning ~20 years of assembly quality, downloaded from UCSC goldenPath and repackaged (with per-build aligner indices) at `Group4_2026:/reference-assets/releases/2026-08-25/`:

| build | assembly | source |
|---|---|---|
| hs1  | T2T-CHM13 v2.0 | https://hgdownload.soe.ucsc.edu/goldenPath/hs1/bigZips/hs1.fa.gz |
| hg38 | GRCh38 | https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz |
| hg19 | GRCh37 | https://hgdownload.soe.ucsc.edu/goldenPath/hg19/bigZips/hg19.fa.gz |
| hg18 | NCBI36 | https://hgdownload.soe.ucsc.edu/goldenPath/hg18/bigZips/hg18.fa.gz |
| hg17 | NCBI35 | https://hgdownload.soe.ucsc.edu/goldenPath/hg17/bigZips/hg17.fa.gz |
| hg16 | NCBI34 | https://hgdownload.soe.ucsc.edu/goldenPath/hg16/bigZips/hg16.fa.gz |
| hg15 | NCBI33 (April 2003) | https://hgdownload.soe.ucsc.edu/goldenPath/hg15/bigZips/chromFa.zip |

Source table: [`config/genomes.tsv`](../config/genomes.tsv) (pulled from the release's provenance archive, `Group4_2026:/reference-assets/releases/2026-08-25/provenance/build-workflow-scripts.tar.zst`). Re-download any build directly with [`scripts/download_reference.sh`](../scripts/download_reference.sh):

```bash
scripts/download_reference.sh hs1
```

This is a standalone version of the original `download_reference.sh` from that provenance archive, with the SLURM/array-job plumbing stripped out. Each reference tarball in DNAnexus also has a `.sha256` sidecar for integrity verification.

Note: minimap2-arm results exist for all seven builds; the winnowmap arm is currently missing an `hg15` result (has `hg16`–`hg19`, `hg38`, `hs1`, plus an `hs1_15x` variant) — worth confirming whether that run is still pending.
